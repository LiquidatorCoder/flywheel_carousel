import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flywheel_carousel/flywheel_carousel.dart';
import 'package:flywheel_carousel_example/main.dart';

import 'e2e_helpers.dart';

/// On-simulator end-to-end suite. Run with:
///
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/flywheel_e2e_test.dart -d SIMULATOR_ID
///
/// Scenarios that pin defects confirmed on main are skipped with their ledger
/// id in the name; pass `--dart-define=E2E_RUN_KNOWN_BUGS=true` to run them.
void main() {
  initE2e();

  setUp(() {
    e2eBinding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  });

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('E1_launch', (tester) async {
    await measure('E1_launch', () async {
      final sw = Stopwatch()..start();
      await tester.pumpWidget(const FlywheelExampleApp());
      await tester.pump();
      record('E1_launch', 'time_to_first_frame_ms', sw.elapsedMilliseconds);
      await pumpFor(tester, const Duration(milliseconds: 500));
    });

    final c = controllerOf(tester);
    expect(isIntegerPage(c.page!), isTrue);
    expect(c.page!.round() % 5, 0, reason: 'initialIndex 0 is Coral');
    expect(find.text('Selected: Coral'), findsOneWidget);
    final viewWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(tester.getCenter(find.text('Coral')).dx, closeTo(viewWidth / 2, 2));

    // The carousel itself stays silent on first build.
    final probe = Probe();
    await pumpFixture(tester, probe);
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(probe.indexes, isEmpty);
    expect(probe.ticks, 0);
  });

  testWidgets('E2_short_drag_snaps_back', (tester) async {
    await tester.pumpWidget(const FlywheelExampleApp());
    await tester.pumpAndSettle();
    final c = controllerOf(tester);
    final start = c.page!;
    final pw = pageWidthOf(tester);

    await measure('E2_short_drag_snaps_back', () async {
      await dragStill(tester, gestureStart(tester), -0.35 * pw);
      final r = await awaitSettle(tester, c);
      record('E2_short_drag_snaps_back', 'settle_ms', r.ms);
    });

    expect(c.page, start);
    expect(find.text('Selected: Coral'), findsOneWidget);
  });

  testWidgets('E3_one_page_drag_selects_next', (tester) async {
    final probe = Probe();
    await pumpFixture(tester, probe);
    final c = controllerOf(tester);
    final start = c.page!;
    final pw = pageWidthOf(tester);

    await measure('E3_one_page_drag_selects_next', () async {
      await dragStill(tester, gestureStart(tester), -1.0 * pw);
      final r = await awaitSettle(tester, c);
      record('E3_one_page_drag_selects_next', 'settle_ms', r.ms);
    });

    expect(c.page, start + 1);
    expect(probe.indexes, [1]);
    expect(probe.ticks, 1);

    // Same flow on the real app: Coral -> Sage.
    await tester.pumpWidget(const FlywheelExampleApp());
    await tester.pumpAndSettle();
    await dragStill(tester, gestureStart(tester), -1.0 * pw);
    await awaitSettle(tester, controllerOf(tester));
    expect(find.text('Selected: Sage'), findsOneWidget);
  });

  testWidgets('E4_hard_fling', (tester) async {
    await tester.pumpWidget(const FlywheelExampleApp());
    await tester.pumpAndSettle();
    final c = controllerOf(tester);
    final trace = PageTrace(c);

    await measure('E4_hard_fling', () async {
      final sw = await flingRelease(tester, gestureStart(tester), -200, 3000);
      // B9: the friction tail is still scrolling after 6 s; see E4b.
      final r = await awaitSettle(tester, c, since: sw, timeout: const Duration(seconds: 12));
      record('E4_hard_fling', 'settle_ms', r.ms);
      record('E4_hard_fling', 'pages_travelled', trace.travelled);
    });
    trace.dispose();

    expect(isIntegerPage(c.page!), isTrue);
    expect(trace.travelled, greaterThan(1));
    final index = (c.page!.round() % 5);
    expect(
      find.text('Selected: ${const ['Coral', 'Sage', 'Cream', 'Ink', 'Sky'][index]}'),
      findsOneWidget,
    );
  });

  testWidgets(
    'E4b_hard_fling_idle_within_3500ms [B9]',
    (tester) async {
      await tester.pumpWidget(const FlywheelExampleApp());
      await tester.pumpAndSettle();
      final c = controllerOf(tester);

      await measure('E4b_hard_fling_idle_within_3500ms', () async {
        final sw = await flingRelease(tester, gestureStart(tester), -200, 3000);
        final r = await awaitSettle(tester, c, since: sw, timeout: const Duration(seconds: 12));
        record('E4b_hard_fling_idle_within_3500ms', 'settle_ms', r.ms);
        expect(r.ms, lessThanOrEqualTo(3500));
      });
    },
    // B9 — fixed in fix/freewheel-physics (friction tail outlasts 6 s).
    skip: knownBug('B9'),
  );

  testWidgets(
    'E5_gentle_nudge [B6]',
    (tester) async {
      // iOS BouncingScrollPhysics ignores releases under 100 px/s, so B6 needs
      // a release >= 100 px/s whose predicted landing rounds back.
      final failures = <String>[];
      for (final pages in const [0.03, 0.05, 0.07]) {
        for (final speed in const [104.0, 110.0, 118.0]) {
          final tag = 'p${pages}_v${speed.round()}';
          await pumpFixture(tester, Probe());
          final c = controllerOf(tester);
          final start = c.page!;
          try {
            final sw = await nudge(
              tester,
              gestureStart(tester),
              pages: pages,
              speed: speed,
              onRelease: () =>
                  record('E5_gentle_nudge', '${tag}_release_offset_pages', c.page! - start),
            );
            final r = await awaitSettle(tester, c, since: sw, timeout: const Duration(seconds: 1));
            record('E5_gentle_nudge', '${tag}_settle_ms', r.ms);
            if (!isIntegerPage(c.page!)) failures.add('$tag: page ${c.page}');
          } on TestFailure catch (e) {
            failures.add('$tag: ${e.message}');
          }
          final ex = tester.takeException();
          if (ex != null) failures.add('$tag: exception $ex');
        }
      }
      expect(failures, isEmpty);
    },
    // B6 — fixed in fix/freewheel-physics (FrictionSimulation.through assert).
    skip: knownBug('B6'),
  );

  testWidgets(
    'E5b_gentle_nudge_past_half [B4]',
    (tester) async {
      final probe = Probe();
      await pumpFixture(tester, probe);
      final c = controllerOf(tester);
      final start = c.page!;

      await measure('E5b_gentle_nudge_past_half', () async {
        final sw = await nudge(
          tester,
          gestureStart(tester),
          pages: 0.40,
          speed: 70,
          onRelease: () =>
              record('E5b_gentle_nudge_past_half', 'release_offset_pages', c.page! - start),
        );
        final r = await awaitSettle(tester, c, since: sw, timeout: const Duration(seconds: 3));
        record('E5b_gentle_nudge_past_half', 'settle_ms', r.ms);
        expect(r.ms, lessThanOrEqualTo(600));
      });

      expect(tester.takeException(), isNull);
    },
    // B4 — fixed in fix/freewheel-physics (landing just past 0.5 crawls via friction-through).
    skip: knownBug('B4'),
  );

  testWidgets(
    'E6_non_loop_fling_clamps [B5]',
    (tester) async {
      await tester.pumpWidget(const FlywheelExampleApp());
      await tester.pumpAndSettle();
      await openTab(tester, 'No loop');
      final c = controllerOf(tester);
      expect(c.page, 2);
      final trace = PageTrace(c);

      await measure('E6_non_loop_fling_clamps', () async {
        var sw = await flingRelease(tester, gestureStart(tester), -200, 3000);
        var r = await awaitSettle(tester, c, since: sw);
        record('E6_non_loop_fling_clamps', 'settle_ms', r.ms);
        expect(find.text('Index: 4'), findsOneWidget);
        expect(trace.max, lessThanOrEqualTo(4.6), reason: 'must not coast past the last item');

        sw = await flingRelease(tester, gestureStart(tester), 200, 3000);
        r = await awaitSettle(tester, c, since: sw);
        expect(find.text('Index: 0'), findsOneWidget);
        expect(trace.min, greaterThanOrEqualTo(-0.6), reason: 'must not coast past the first item');
        record('E6_non_loop_fling_clamps', 'max_page_overshoot', (trace.max - 4).clamp(0, 1000));
      });
      trace.dispose();
    },
    // B5 — fixed in fix/freewheel-physics (coasts to ~page 15 then springs back).
    skip: knownBug('B5'),
  );

  testWidgets('E6b_non_loop_slow_drags_reach_ends', (tester) async {
    await tester.pumpWidget(const FlywheelExampleApp());
    await tester.pumpAndSettle();
    await openTab(tester, 'No loop');
    final c = controllerOf(tester);
    final pw = pageWidthOf(tester);

    await measure('E6b_non_loop_slow_drags_reach_ends', () async {
      for (var i = 0; i < 2; i++) {
        await dragStill(tester, gestureStart(tester), -pw);
        await awaitSettle(tester, c);
      }
      expect(find.text('Index: 4'), findsOneWidget);
      // One more past the end: overscroll then spring back, selection stays.
      await dragStill(tester, gestureStart(tester), -pw);
      await awaitSettle(tester, c);
      expect(c.page, 4);
      expect(find.text('Index: 4'), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        await dragStill(tester, gestureStart(tester), pw);
        await awaitSettle(tester, c);
      }
      expect(c.page, 0);
      expect(find.text('Index: 0'), findsOneWidget);
    });
  });

  testWidgets('E7_loop_wrap', (tester) async {
    await tester.pumpWidget(const FlywheelExampleApp());
    await tester.pumpAndSettle();
    final c = controllerOf(tester);
    final pw = pageWidthOf(tester);

    await measure('E7_loop_wrap', () async {
      await dragStill(tester, gestureStart(tester), pw);
      final r = await awaitSettle(tester, c);
      record('E7_loop_wrap', 'settle_ms', r.ms);
      expect(find.text('Selected: Sky'), findsOneWidget);

      final trace = PageTrace(c);
      final sw = await flingRelease(tester, gestureStart(tester), -200, 3000);
      await awaitSettle(tester, c, since: sw, timeout: const Duration(seconds: 12));
      record('E7_loop_wrap', 'pages_travelled', trace.travelled);
      expect(trace.travelled, greaterThan(5), reason: 'fling should cross more than count pages');
      trace.dispose();
    });
    expect(isIntegerPage(c.page!), isTrue);
  });

  testWidgets('E8_tab_switching', (tester) async {
    await tester.pumpWidget(const FlywheelExampleApp());
    await tester.pumpAndSettle();
    final expected = {
      'Item card': 'Selected: Sage',
      'Custom builder': 'Index: 1',
      'No loop': 'Index: 3',
    };

    await measure('E8_tab_switching', () async {
      for (final tab in expected.keys) {
        await openTab(tester, tab);
        final c = controllerOf(tester);
        await dragStill(tester, gestureStart(tester), -pageWidthOf(tester));
        await awaitSettle(tester, c);
        expect(find.text(expected[tab]!), findsOneWidget, reason: tab);
      }
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('E9_catch_mid_coast', (tester) async {
    final probe = Probe();
    await pumpFixture(tester, probe);
    final c = controllerOf(tester);

    await measure('E9_catch_mid_coast', () async {
      final at = gestureStart(tester);
      await flingRelease(tester, at, -200, 3000);
      await pumpFor(tester, const Duration(milliseconds: 150));
      final g = await tester.startGesture(at);
      await pumpFor(tester, const Duration(milliseconds: 100));
      final sw = Stopwatch()..start();
      await g.up();
      final r = await awaitSettle(tester, c, since: sw, timeout: const Duration(seconds: 3));
      record('E9_catch_mid_coast', 'settle_ms', r.ms);
      expect(r.ms, lessThanOrEqualTo(1500));
    });
  });

  testWidgets(
    'E9b_catch_settles_within_500ms [B8]',
    (tester) async {
      final probe = Probe();
      await pumpFixture(tester, probe);
      final c = controllerOf(tester);

      await measure('E9b_catch_settles_within_500ms', () async {
        final at = gestureStart(tester);
        await flingRelease(tester, at, -200, 3000);
        await pumpFor(tester, const Duration(milliseconds: 150));
        final g = await tester.startGesture(at);
        await pumpFor(tester, const Duration(milliseconds: 100));
        final sw = Stopwatch()..start();
        await g.up();
        final r = await awaitSettle(tester, c, since: sw, timeout: const Duration(seconds: 3));
        record('E9b_catch_settles_within_500ms', 'settle_ms', r.ms);
        expect(r.ms, lessThanOrEqualTo(500));
      });
    },
    // B8 — fixed in fix/freewheel-physics (catch-mid-coast settle ~900 ms).
    skip: knownBug('B8'),
  );

  testWidgets(
    'E10_jump_counts_ticks [S9]',
    (tester) async {
      final probe = Probe();
      await pumpFixture(tester, probe);
      final c = controllerOf(tester);
      c.jumpTo(c.position.pixels + 3 * pageWidthOf(tester));
      await tester.pump(frame);
      expect(probe.ticks, 3);
    },
    // S9 — fixed in fix/wheel-correctness (one tick per notification, not per page).
    skip: knownBug('S9'),
  );

  testWidgets('E10b_slow_drag_two_pages_two_ticks', (tester) async {
    final probe = Probe();
    await pumpFixture(tester, probe);
    final c = controllerOf(tester);
    final pw = pageWidthOf(tester);

    await measure('E10b_slow_drag_two_pages_two_ticks', () async {
      await dragStill(tester, gestureStart(tester), -2 * pw);
      await awaitSettle(tester, c);
    });
    expect(probe.ticks, 2);
    expect(probe.indexes, [1, 2]);
  });

  testWidgets(
    'E11_visible_slots_distinct_centers [S1]',
    (tester) async {
      final probe = Probe();
      await pumpFixture(tester, probe, count: 12, initialIndex: 5, visibleSlots: 4);
      Offset center(int i) => tester.getCenter(find.byKey(ValueKey('card-$i')));
      expect((center(9) - center(8)).distance, greaterThan(1), reason: 'offsets +4 and +3 stacked');
      expect((center(1) - center(2)).distance, greaterThan(1), reason: 'offsets -4 and -3 stacked');
    },
    // S1 — fixed in fix/wheel-correctness (t clamped to +-2.5).
    skip: knownBug('S1'),
  );

  testWidgets(
    'E12_stateful_items_keep_identity [S2]',
    (tester) async {
      final probe = Probe();
      await pumpFixture(tester, probe, kind: CardKind.stateful);
      final c = controllerOf(tester);
      final mismatches = <String>[];
      void check() {
        for (final s in tester.stateList<StatefulCardState>(find.byType(StatefulCard))) {
          if (s.initialLabel != s.widget.label) {
            mismatches.add('state ${s.initialLabel} shows item ${s.widget.label}');
          }
        }
      }

      await dragStill(
        tester,
        gestureStart(tester),
        -6 * 0.3 * pageWidthOf(tester),
        steps: 6,
        onStep: check,
      );
      await awaitSettle(tester, c);
      check();
      expect(mismatches, isEmpty);
    },
    // S2 — fixed in fix/wheel-correctness (cards keyed by item).
    skip: knownBug('S2'),
  );

  testWidgets(
    'E13_narrow_parent_card_width [S3]',
    (tester) async {
      final probe = Probe();
      await pumpFixture(tester, probe, width: 300);
      expect(tester.getSize(find.byKey(const ValueKey('card-0'))).width, closeTo(300 * 0.65, 0.5));
    },
    // S3 — fixed in fix/wheel-correctness (card width from parent constraints).
    skip: knownBug('S3'),
  );

  void rotateToLandscape(WidgetTester tester) {
    final size = tester.view.physicalSize;
    tester.view.physicalSize = Size(size.height, size.width);
    addTearDown(tester.view.reset);
  }

  testWidgets(
    'E14_landscape [L5]',
    (tester) async {
      rotateToLandscape(tester);
      await measure('E14_landscape', () async {
        await tester.pumpWidget(const FlywheelExampleApp());
        await tester.pumpAndSettle();
        final c = controllerOf(tester);
        await dragStill(tester, gestureStart(tester), -pageWidthOf(tester));
        await awaitSettle(tester, c);
      });
      expect(tester.takeException(), isNull, reason: 'no overflow / layout errors');
    },
    // L5 — fixed in the example polish PR (tab Column overflows 4 px in landscape).
    skip: knownBug('L5'),
  );

  testWidgets(
    'E14b_item_card_large_text [L4]',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 3.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpFixture(tester, Probe(), kind: CardKind.itemCard);
      await pumpFor(tester, const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: 'item card must not overflow');
    },
    // L4 — fixed in the item card PR (Column overflows its 200 px card at 3.0x text).
    skip: knownBug('L4'),
  );

  testWidgets('E14c_custom_builder_landscape', (tester) async {
    rotateToLandscape(tester);
    final probe = Probe();
    final labels = ['0', '1', '2', '3', '4'];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FlywheelCarousel<String>(
              items: labels,
              onTick: () => probe.ticks++,
              itemBuilder: (context, label, selected) => Container(
                color: selected ? Colors.orange : Colors.blueGrey,
                alignment: Alignment.center,
                child: Text(label),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final c = controllerOf(tester);
    await dragStill(tester, gestureStart(tester), -pageWidthOf(tester));
    await awaitSettle(tester, c);
    expect(tester.takeException(), isNull, reason: 'no overflow / layout errors');
  });

  testWidgets('E15_perf_soak', (tester) async {
    final probe = Probe();
    await pumpFixture(tester, probe, kind: CardKind.itemCard);
    final c = controllerOf(tester);
    final settles = <int>[];

    await measure('E15_perf_soak', () async {
      for (var i = 0; i < 6; i++) {
        final dir = i.isEven ? -1.0 : 1.0;
        final sw = await flingRelease(tester, gestureStart(tester), dir * 200, 3000);
        // B9: friction tail can outlast 6 s; only require an integer landing.
        final r = await awaitSettle(tester, c, since: sw, timeout: const Duration(seconds: 12));
        settles.add(r.ms);
      }
    });
    record('E15_perf_soak', 'settle_ms', settles.reduce((a, b) => a + b) / settles.length);
    record('E15_perf_soak', 'settle_max_ms', settles.reduce((a, b) => a > b ? a : b));
    expect(isIntegerPage(c.page!), isTrue);
  });

  testWidgets(
    'E16_builder_calls_per_frame [S5]',
    (tester) async {
      final probe = Probe();
      await pumpFixture(tester, probe);
      final c = controllerOf(tester);

      final m = await measure('E16_builder_calls_per_frame', () async {
        final sw = await flingRelease(tester, gestureStart(tester), -200, 3000);
        await awaitSettle(tester, c, since: sw, timeout: const Duration(seconds: 12));
      });
      expect(m['builder_calls_per_frame'] ?? 0, lessThanOrEqualTo(0.5));
    },
    // S5 — fixed in the perf PR (itemBuilder runs for every visible card every frame).
    skip: knownBug('S5'),
  );
}
