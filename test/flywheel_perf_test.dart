import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flywheel_carousel/flywheel_carousel.dart';

const _items = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];
const _visibleSlots = 2;
const _viewportFraction = 0.65;
const _angularStep = 0.42;
const _radius = 320.0;
const _cardHeight = 200.0;

Future<PageController> _pump(
  WidgetTester tester, {
  required FlywheelItemBuilder<String> builder,
  int initialIndex = 0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: FlywheelCarousel<String>(
            items: _items,
            initialIndex: initialIndex,
            itemBuilder: builder,
          ),
        ),
      ),
    ),
  );
  return tester.widget<PageView>(find.byType(PageView)).controller!;
}

double _pageExtent(WidgetTester tester) =>
    tester.getSize(find.byType(FlywheelCarousel<String>)).width * _viewportFraction;

/// The pre-refactor opacity function (flywheel_wheel.dart, `_ArcCard.build`).
double _oldOpacity(double tc) {
  const edge = _visibleSlots + 0.5;
  final abs = tc.abs();
  final fadeStart = max(0.0, min(1.5, _visibleSlots - 0.5));
  final base = 1.0 - Curves.easeIn.transform((min(abs, fadeStart) / 1.5).clamp(0.0, 1.0)) * 0.85;
  final fade = abs <= fadeStart ? 1.0 : ((edge - abs) / (edge - fadeStart)).clamp(0.0, 1.0);
  return base * fade;
}

void main() {
  testWidgets('itemBuilder runs per page crossing, not per frame', (tester) async {
    var calls = 0;
    final controller = await _pump(
      tester,
      builder: (context, item, selected) {
        calls++;
        return Text(item, textDirection: TextDirection.ltr);
      },
    );
    final extent = _pageExtent(tester);
    final start = controller.offset;
    const steps = 60;
    const pages = 3;
    calls = 0;
    for (var i = 1; i <= steps; i++) {
      controller.jumpTo(start + extent * pages * i / steps);
      await tester.pump(const Duration(milliseconds: 16));
    }
    const window = 2 * _visibleSlots + 1;
    // ignore: avoid_print
    print(
      'PERF itemBuilder calls over $steps frames / $pages crossings: $calls '
      '(per-frame rebuild would be ${steps * window})',
    );
    expect(calls, lessThanOrEqualTo((pages + 1) * window));
    expect(calls, lessThan(steps * window ~/ 4));
  });

  testWidgets('card transforms and opacity match the original arc formula', (tester) async {
    final controller = await _pump(
      tester,
      builder: (c, i, s) => SizedBox.expand(key: Key('card-$i')),
    );
    final extent = _pageExtent(tester);
    final boxSize = tester.getSize(find.byType(FlywheelCarousel<String>));
    final cardWidth = boxSize.width * _viewportFraction;
    final origin = tester.getTopLeft(find.byType(FlywheelCarousel<String>));
    const base = 25000.0;
    var checked = 0;
    for (final frac in [0.4, 0.5, 0.3, 0.0, 0.7, 0.1, -0.2, 0.45]) {
      final page = base + frac;
      controller.jumpTo(page * extent);
      await tester.pump();
      final centre = page.round();
      for (var o = -_visibleSlots; o <= _visibleSlots; o++) {
        final raw = centre + o;
        final t = raw - page;
        final tc = t.clamp(-(_visibleSlots + 0.5), _visibleSlots + 0.5);
        if (_oldOpacity(tc) <= 0) continue;
        final finder = find.byKey(Key('card-${_items[raw % _items.length]}'));
        expect(finder, findsOneWidget);
        final theta = tc * _angularStep;
        final m = tester.renderObject<RenderBox>(finder).getTransformTo(null);
        final c = MatrixUtils.transformPoint(m, Offset(cardWidth / 2, _cardHeight / 2));
        final expected =
            origin +
            Offset(
              boxSize.width / 2 + _radius * sin(theta),
              _cardHeight / 2 + _radius * (1 - cos(theta)),
            );
        expect((c - expected).distance, lessThan(0.01), reason: 't=$t');
        final rot = atan2(m.storage[1], m.storage[0]);
        expect((rot - theta).abs(), lessThan(1e-6), reason: 't=$t');
        checked++;
      }
    }
    expect(checked, greaterThan(30));
  });

  testWidgets('centre card is painted last (on top)', (tester) async {
    final controller = await _pump(
      tester,
      builder: (c, i, s) => Text(i, textDirection: TextDirection.ltr),
    );
    final extent = _pageExtent(tester);
    const base = 25000.0;
    for (final frac in [0.0, 0.3, 0.45, -0.3]) {
      final page = base + frac;
      controller.jumpTo(page * extent);
      await tester.pump();
      final centre = page.round();
      final layers = <int, Layer>{};
      for (var o = -_visibleSlots; o <= _visibleSlots; o++) {
        final layer = tester.renderObject(find.byKey(ValueKey<int>(centre + o))).debugLayer;
        if (layer != null) layers[centre + o] = layer;
      }
      expect(layers.length, greaterThanOrEqualTo(3));
      // Paint order = depth-first order of the layer tree.
      final order = <Layer>[];
      Layer root = layers.values.first;
      while (root.parent != null) {
        root = root.parent!;
      }
      void walk(Layer l) {
        order.add(l);
        if (l is ContainerLayer) {
          for (var c = l.firstChild; c != null; c = c.nextSibling) {
            walk(c);
          }
        }
      }

      walk(root);
      final pos = {for (final e in layers.entries) e.key: order.indexOf(e.value)};
      final centreIdx = pos[centre]!;
      for (final e in pos.entries) {
        if (e.key != centre) expect(e.value, lessThan(centreIdx), reason: 'raw ${e.key}');
      }
      // Farther cards are painted before nearer ones.
      final byDistance = pos.keys.toList()
        ..sort((a, b) => (b - page).abs().compareTo((a - page).abs()));
      for (var i = 1; i < byDistance.length; i++) {
        expect(pos[byDistance[i]]!, greaterThan(pos[byDistance[i - 1]]!));
      }
    }
  });
}
