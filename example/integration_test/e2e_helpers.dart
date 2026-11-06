import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flywheel_carousel/flywheel_carousel.dart';
import 'package:integration_test/integration_test.dart';

/// Set `--dart-define=E2E_RUN_KNOWN_BUGS=true` to un-skip scenarios that pin
/// defects confirmed on main (used to prove they really fail).
const bool runKnownBugs = bool.fromEnvironment('E2E_RUN_KNOWN_BUGS');

/// `testWidgets(skip:)` is a bool, so the ledger id lives in the test name and
/// in the call site. Returns true (= skip) unless known bugs are enabled.
bool knownBug(String ledgerId) => !runKnownBugs;

const jankThresholdMs = 16.7;
const frame = Duration(milliseconds: 16);

late IntegrationTestWidgetsFlutterBinding e2eBinding;

/// Per-scenario builder call counter, reset by [measure].
int builderCalls = 0;

void initE2e() {
  e2eBinding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  e2eBinding.reportData ??= <String, dynamic>{};
}

/// Adds a single value to a scenario's reported metrics.
void record(String scenario, String key, num value) {
  final data = e2eBinding.reportData!;
  final entry = (data[scenario] ??= <String, dynamic>{}) as Map<String, dynamic>;
  entry[key] = value is double ? double.parse(value.toStringAsFixed(3)) : value;
}

double _pct(List<double> sorted, double p) {
  if (sorted.isEmpty) return 0;
  final i = ((sorted.length - 1) * p).ceil();
  return sorted[i];
}

double _avg(List<double> v) => v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

/// Collects [FrameTiming]s while [body] runs and stores the summary under
/// `reportData[name]`. Also reports itemBuilder calls per frame when the
/// fixture bumped [builderCalls].
Future<Map<String, num>> measure(String name, Future<void> Function() body) async {
  final timings = <FrameTiming>[];
  void cb(List<FrameTiming> t) => timings.addAll(t);
  builderCalls = 0;
  SchedulerBinding.instance.addTimingsCallback(cb);
  final wall = Stopwatch()..start();
  try {
    await body();
  } finally {
    wall.stop();
    // The engine reports timings in batches; give the last batch time to land.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    SchedulerBinding.instance.removeTimingsCallback(cb);
  }
  final build = timings.map((t) => t.buildDuration.inMicroseconds / 1000).toList()..sort();
  final raster = timings.map((t) => t.rasterDuration.inMicroseconds / 1000).toList()..sort();
  final jank = timings
      .where(
        (t) =>
            t.buildDuration.inMicroseconds / 1000 > jankThresholdMs ||
            t.rasterDuration.inMicroseconds / 1000 > jankThresholdMs,
      )
      .length;
  final out = <String, num>{
    'frames': timings.length,
    'build_avg_ms': _avg(build),
    'build_p90_ms': _pct(build, 0.90),
    'build_p99_ms': _pct(build, 0.99),
    'build_max_ms': build.isEmpty ? 0 : build.last,
    'raster_avg_ms': _avg(raster),
    'raster_p90_ms': _pct(raster, 0.90),
    'raster_p99_ms': _pct(raster, 0.99),
    'raster_max_ms': raster.isEmpty ? 0 : raster.last,
    'jank_frames': jank,
    'wall_ms': wall.elapsedMilliseconds,
  };
  if (builderCalls > 0) {
    out['builder_calls'] = builderCalls;
    out['builder_calls_per_frame'] = timings.isEmpty ? 0 : builderCalls / timings.length;
  }
  out.forEach((k, v) => record(name, k, v));
  return out;
}

// ---------------------------------------------------------------------------
// Carousel access

/// The on-screen carousel (any type argument). Tabs are kept alive, so
/// off-screen carousels stay in the tree; only the visible one is hit-testable.
Finder carouselFinder() => find.byWidgetPredicate((w) => w is FlywheelCarousel).hitTestable().first;

PageController controllerOf(WidgetTester tester, [Finder? carousel]) {
  final pageView = find.descendant(
    of: carousel ?? carouselFinder(),
    matching: find.byType(PageView),
  );
  return tester.widget<PageView>(pageView).controller!;
}

/// Width of one page in logical pixels (viewport * viewportFraction).
double pageWidthOf(WidgetTester tester, [Finder? carousel, double viewportFraction = 0.65]) {
  final pageView = find.descendant(
    of: carousel ?? carouselFinder(),
    matching: find.byType(PageView),
  );
  return tester.getSize(pageView).width * viewportFraction;
}

Offset gestureStart(WidgetTester tester, [Finder? carousel]) => tester.getCenter(
  find.descendant(of: carousel ?? carouselFinder(), matching: find.byType(PageView)),
);

bool isIntegerPage(double page, [double tol = 0.001]) => (page - page.roundToDouble()).abs() < tol;

/// Records the min/max page seen on every controller notification.
class PageTrace {
  PageTrace(this.controller) {
    start = controller.page!;
    min = max = start;
    controller.addListener(_on);
  }
  final PageController controller;
  late final double start;
  late double min;
  late double max;

  void _on() {
    final p = controller.page;
    if (p == null) return;
    min = math.min(min, p);
    max = math.max(max, p);
  }

  double get travelled => (controller.page! - start).abs();
  void dispose() => controller.removeListener(_on);
}

class SettleResult {
  SettleResult(this.ms, this.page);
  final int ms;
  final double page;
}

/// Polls per frame until the scroll is idle AND the page is within 0.001 of an
/// integer. Fails the test after [timeout].
Future<SettleResult> awaitSettle(
  WidgetTester tester,
  PageController controller, {
  Stopwatch? since,
  Duration timeout = const Duration(seconds: 6),
}) async {
  final sw = since ?? (Stopwatch()..start());
  while (sw.elapsed < timeout) {
    await tester.pump(frame);
    final page = controller.page!;
    if (!controller.position.isScrollingNotifier.value && isIntegerPage(page)) {
      return SettleResult(sw.elapsedMilliseconds, page);
    }
  }
  fail(
    'carousel did not settle within ${timeout.inMilliseconds} ms '
    '(page=${controller.page}, scrolling=${controller.position.isScrollingNotifier.value})',
  );
}

// ---------------------------------------------------------------------------
// Gestures (explicit timestamps so velocities are deterministic)

/// Drags [dx] logical px in [steps] frames, holds still for [hold] of REAL time
/// with no further pointer events, then releases: a "slow drag" that releases
/// with ~zero velocity. On iOS the velocity tracker reports zero only when no
/// sample was added in the last 40 ms of real time, so no event (not even a
/// zero-delta move) may be sent during the hold.
Future<void> dragStill(
  WidgetTester tester,
  Offset from,
  double dx, {
  int steps = 20,
  Duration hold = const Duration(milliseconds: 120),
  FutureOr<void> Function()? onStep,
}) async {
  final g = await tester.startGesture(from);
  var ts = Duration.zero;
  for (var i = 0; i < steps; i++) {
    ts += frame;
    await g.moveBy(Offset(dx / steps, 0), timeStamp: ts);
    await tester.pump(frame);
    await onStep?.call();
  }
  await pumpFor(tester, hold);
  ts += hold;
  await g.up(timeStamp: ts);
}

/// Starts a drag of [dx] px at [speed] px/s and releases with that velocity.
/// Returns a stopwatch started at release.
Future<Stopwatch> flingRelease(WidgetTester tester, Offset from, double dx, double speed) async {
  const n = 30;
  final g = await tester.startGesture(from);
  final stepUs = (dx.abs() / speed * 1e6 / n).round();
  var ts = Duration.zero;
  for (var i = 0; i < n; i++) {
    ts += Duration(microseconds: stepUs);
    await g.moveBy(Offset(dx / n, 0), timeStamp: ts);
  }
  final sw = Stopwatch()..start();
  await g.up(timeStamp: ts);
  return sw;
}

/// Deterministic gentle release: gets past touch slop with one 24 px move,
/// then 12 moves totalling `pages * pageWidth` px at exactly [speed] px/s, then
/// releases at the last timestamp (no hold, no zero-delta move). [onRelease]
/// runs just before the pointer-up. Returns a stopwatch started at release.
Future<Stopwatch> nudge(
  WidgetTester tester,
  Offset from, {
  required double pages,
  required double speed,
  void Function()? onRelease,
}) async {
  const n = 12;
  final total = pages * pageWidthOf(tester);
  final g = await tester.startGesture(from);
  var ts = const Duration(milliseconds: 16);
  await g.moveBy(const Offset(-24, 0), timeStamp: ts);
  final dx = total / n;
  final stepUs = (dx / speed * 1e6).round();
  for (var i = 0; i < n; i++) {
    ts += Duration(microseconds: stepUs);
    await g.moveBy(Offset(-dx, 0), timeStamp: ts);
  }
  onRelease?.call();
  final sw = Stopwatch()..start();
  await g.up(timeStamp: ts);
  return sw;
}

/// Real-time pump for [d] (frames at ~16 ms).
Future<void> pumpFor(WidgetTester tester, Duration d) async {
  final sw = Stopwatch()..start();
  while (sw.elapsed < d) {
    await tester.pump(frame);
  }
}

/// Scenario-local recording of what a fixture carousel reported.
class Probe {
  int ticks = 0;
  final List<int> indexes = [];
}

// ---------------------------------------------------------------------------
// Fixtures

/// Item with state that records the label it was created with.
class StatefulCard extends StatefulWidget {
  const StatefulCard({super.key, required this.label});
  final String label;
  @override
  State<StatefulCard> createState() => StatefulCardState();
}

class StatefulCardState extends State<StatefulCard> {
  late final String initialLabel;

  @override
  void initState() {
    super.initState();
    initialLabel = widget.label;
  }

  @override
  Widget build(BuildContext context) =>
      Container(color: Colors.teal, alignment: Alignment.center, child: Text(initialLabel));
}

enum CardKind { plain, itemCard, stateful }

/// Pumps a MaterialApp hosting a single carousel of [count] items labelled
/// "0".."n-1". Cards (kind plain) are keyed `card-<i>` at their root so tests
/// can read their on-screen size/centre.
Future<void> pumpFixture(
  WidgetTester tester,
  Probe probe, {
  int count = 5,
  bool loop = true,
  int visibleSlots = 2,
  int initialIndex = 0,
  double? width,
  CardKind kind = CardKind.plain,
}) async {
  final labels = [for (var i = 0; i < count; i++) '$i'];
  Widget carousel = FlywheelCarousel<String>(
    items: labels,
    loop: loop,
    visibleSlots: visibleSlots,
    initialIndex: initialIndex,
    onTick: () => probe.ticks++,
    onIndexChanged: probe.indexes.add,
    itemBuilder: (context, label, selected) {
      builderCalls++;
      switch (kind) {
        case CardKind.plain:
          return Container(
            key: ValueKey('card-$label'),
            color: selected ? Colors.orange : Colors.blueGrey,
            alignment: Alignment.center,
            child: Text(label),
          );
        case CardKind.itemCard:
          return FlywheelItemCard(
            leading: CircleAvatar(radius: 26, child: Text(label)),
            title: 'Item $label',
            subtitle: '#$label',
            selected: selected,
          );
        case CardKind.stateful:
          return StatefulCard(label: label);
      }
    },
  );
  if (width != null) carousel = SizedBox(width: width, child: carousel);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Column(mainAxisAlignment: MainAxisAlignment.center, children: [carousel]),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}
