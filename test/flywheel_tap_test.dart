import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flywheel_carousel/flywheel_carousel.dart';

import 'flywheel_test_support.dart';

void main() {
  testWidgets('tapping the right neighbour selects it and calls onItemTap', (tester) async {
    usePhoneSurface(tester);
    final taps = <int>[];
    final changes = <int>[];
    await tester.pumpWidget(carouselApp(onItemTap: taps.add, onIndexChanged: changes.add));
    final pages = pageControllerOf(tester);
    final start = pages.page!;

    await tester.tapAt(rightNeighbourPoint(tester));
    await tester.pumpAndSettle();

    expect(taps, [1]);
    expect(pages.page, start + 1);
    expect(changes.last, 1);
    expect(find.byType(FlywheelCarousel<String>), findsOneWidget);
  });

  testWidgets('tapping the left neighbour wraps back through the loop', (tester) async {
    usePhoneSurface(tester);
    final taps = <int>[];
    await tester.pumpWidget(carouselApp(onItemTap: taps.add));
    final pages = pageControllerOf(tester);
    final start = pages.page!;

    final size = tester.getSize(find.byType(FlywheelCarousel<String>));
    final right = rightNeighbourPoint(tester);
    // Mirror the right-hand point across the carousel's vertical centre line.
    await tester.tapAt(Offset(size.width - right.dx, right.dy));
    await tester.pumpAndSettle();

    expect(taps, [4], reason: 'item before 0 in a loop is the last');
    expect(pages.page, start - 1);
  });

  testWidgets('tapping the centre card calls onItemTap without moving', (tester) async {
    usePhoneSurface(tester);
    final taps = <int>[];
    await tester.pumpWidget(carouselApp(onItemTap: taps.add));
    final pages = pageControllerOf(tester);
    final start = pages.page!;

    await tester.tapAt(tester.getCenter(find.text('A')));
    await tester.pumpAndSettle();

    expect(taps, [0]);
    expect(pages.page, start);
  });

  testWidgets('hit-testing is front-to-back: where cards overlap the centre wins', (tester) async {
    usePhoneSurface(tester);
    final taps = <int>[];
    await tester.pumpWidget(carouselApp(onItemTap: taps.add));
    final size = tester.getSize(find.byType(FlywheelCarousel<String>));
    final origin = carouselTopLeft(tester);

    // Inside both the centre card and its right neighbour's body.
    await tester.tapAt(origin + Offset(size.width / 2 + 100, 60));
    await tester.pumpAndSettle();
    expect(taps, [0]);
  });

  testWidgets('selectOnTap: false reports the tap but leaves the wheel alone', (tester) async {
    usePhoneSurface(tester);
    final taps = <int>[];
    await tester.pumpWidget(carouselApp(onItemTap: taps.add, selectOnTap: false));
    final pages = pageControllerOf(tester);
    final start = pages.page!;

    await tester.tapAt(rightNeighbourPoint(tester));
    await tester.pumpAndSettle();

    expect(taps, [1]);
    expect(pages.page, start);
  });

  testWidgets('a tap in empty space does nothing', (tester) async {
    usePhoneSurface(tester);
    final taps = <int>[];
    await tester.pumpWidget(carouselApp(onItemTap: taps.add));
    // Far left, above the arc: no card covers it.
    await tester.tapAt(carouselTopLeft(tester) + const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(taps, isEmpty);
  });

  testWidgets('a drag that starts on a card still drags', (tester) async {
    usePhoneSurface(tester);
    final taps = <int>[];
    await tester.pumpWidget(carouselApp(onItemTap: taps.add));
    final pages = pageControllerOf(tester);
    final start = pages.page!;

    await tester.dragFrom(rightNeighbourPoint(tester), const Offset(-200, 0));
    await tester.pumpAndSettle();

    expect(taps, isEmpty);
    expect(pages.page, greaterThan(start));
  });

  testWidgets('a tap on a spinning wheel only catches it', (tester) async {
    usePhoneSurface(tester);
    final taps = <int>[];
    await tester.pumpWidget(carouselApp(onItemTap: taps.add));
    final pages = pageControllerOf(tester);

    await tester.fling(find.byType(PageView), const Offset(-200, 0), 1500);
    await tester.pump(const Duration(milliseconds: 100));
    final mid = pages.page!;
    expect((mid - mid.round()).abs(), greaterThan(0.02), reason: 'wheel is mid-coast');

    final gesture = await tester.startGesture(rightNeighbourPoint(tester));
    await tester.pump(const Duration(milliseconds: 20));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(taps, isEmpty);
    // Caught, then settled on the nearest card rather than jumping to the tapped one.
    expect((pages.page! - mid).abs(), lessThan(1));
    expect(pages.page! - pages.page!.round(), 0);
  });

  testWidgets('non-loop: no phantom card past the end is tappable', (tester) async {
    usePhoneSurface(tester);
    final taps = <int>[];
    await tester.pumpWidget(carouselApp(onItemTap: taps.add, loop: false));

    final size = tester.getSize(find.byType(FlywheelCarousel<String>));
    final right = rightNeighbourPoint(tester);
    await tester.tapAt(Offset(size.width - right.dx, right.dy)); // left of item 0
    await tester.pumpAndSettle();

    expect(taps, isEmpty);
  });

  testWidgets('tap is not recognised when the pointer leaves it as a drag gesture', (tester) async {
    usePhoneSurface(tester);
    final taps = <int>[];
    await tester.pumpWidget(carouselApp(onItemTap: taps.add));
    final gesture = await tester.startGesture(
      rightNeighbourPoint(tester),
      kind: PointerDeviceKind.touch,
    );
    await gesture.moveBy(const Offset(-60, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, isEmpty);
  });
}
