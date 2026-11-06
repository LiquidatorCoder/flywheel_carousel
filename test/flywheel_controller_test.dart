import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flywheel_carousel/flywheel_carousel.dart';

import 'flywheel_test_support.dart';

void main() {
  late FlywheelCarouselController controller;

  setUp(() => controller = FlywheelCarouselController());
  tearDown(() => controller.dispose());

  testWidgets('animateToItem takes the shortest path in loop mode', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(carouselApp(controller: controller));
    final pages = pageControllerOf(tester);
    final start = pages.page!;

    unawaited(controller.animateToItem(4));
    await tester.pumpAndSettle();

    // 0 -> 4 of 5: one page back, not four forward.
    expect(pages.page, start - 1);
    expect(controller.index, 4);

    unawaited(controller.animateToItem(1));
    await tester.pumpAndSettle();
    expect(pages.page, start + 1, reason: '4 -> 1 of 5 is two pages forward');
    expect(controller.index, 1);
  });

  testWidgets('non-loop animateToItem clamps and goes straight there', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(carouselApp(controller: controller, loop: false));
    final pages = pageControllerOf(tester);

    unawaited(controller.animateToItem(4));
    await tester.pumpAndSettle();
    expect(pages.page, 4);

    unawaited(controller.animateToItem(99));
    await tester.pumpAndSettle();
    expect(pages.page, 4, reason: 'out of range clamps to the last item');
    expect(controller.index, 4);
  });

  testWidgets('next and previous step one item', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(carouselApp(controller: controller));

    unawaited(controller.next());
    await tester.pumpAndSettle();
    unawaited(controller.next());
    await tester.pumpAndSettle();
    unawaited(controller.previous());
    await tester.pumpAndSettle();
    expect(controller.index, 1);
  });

  testWidgets('non-loop next/previous do nothing at the ends', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(carouselApp(controller: controller, loop: false));
    unawaited(controller.previous());
    await tester.pumpAndSettle();
    expect(controller.index, 0);
    controller.jumpToItem(4);
    await tester.pump();
    unawaited(controller.next());
    await tester.pumpAndSettle();
    expect(controller.index, 4);
  });

  testWidgets('jumpToItem moves immediately', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(carouselApp(controller: controller));
    controller.jumpToItem(2);
    await tester.pump();
    expect(controller.index, 2);
    expect(find.text('C'), findsOneWidget);
  });

  testWidgets('notifies once per selected-index change', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(carouselApp(controller: controller));
    final seen = <int>[];
    controller.addListener(() => seen.add(controller.index));

    unawaited(controller.animateToItem(2));
    await tester.pumpAndSettle();
    expect(seen, [1, 2]); // one per page crossed, none repeated

    unawaited(controller.animateToItem(2));
    await tester.pumpAndSettle();
    expect(seen, [1, 2], reason: 'no change, no notification');
  });

  testWidgets('a detached controller throws a StateError', (tester) async {
    expect(controller.isAttached, isFalse);
    expect(() => controller.index, throwsStateError);
    expect(() => controller.next(), throwsStateError);
    expect(() => controller.jumpToItem(1), throwsStateError);

    usePhoneSurface(tester);
    await tester.pumpWidget(carouselApp(controller: controller));
    expect(controller.isAttached, isTrue);

    await tester.pumpWidget(const SizedBox());
    expect(controller.isAttached, isFalse);
    expect(() => controller.animateToItem(1), throwsStateError);
  });

  testWidgets('swapping controllers moves the binding', (tester) async {
    usePhoneSurface(tester);
    final other = FlywheelCarouselController();
    addTearDown(other.dispose);

    await tester.pumpWidget(carouselApp(controller: controller));
    await tester.pumpWidget(carouselApp(controller: other));
    expect(controller.isAttached, isFalse);
    expect(other.isAttached, isTrue);

    unawaited(other.next());
    await tester.pumpAndSettle();
    expect(other.index, 1);

    await tester.pumpWidget(carouselApp());
    expect(other.isAttached, isFalse);
  });

  testWidgets('reduced motion jumps: one frame, no animation', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(carouselApp(controller: controller, disableAnimations: true));
    final pages = pageControllerOf(tester);
    final start = pages.page!;

    unawaited(controller.animateToItem(2));
    await tester.pump();
    expect(pages.page, start + 2);
    expect(tester.hasRunningAnimations, isFalse);
    expect(controller.index, 2);
  });

  testWidgets('default duration scales with distance and is capped', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(
      carouselApp(controller: controller, items: List.generate(40, (i) => '$i')),
    );
    final pages = pageControllerOf(tester);
    final start = pages.page!;

    unawaited(controller.animateToItem(20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 599));
    expect(pages.page, lessThan(start + 20));
    await tester.pump(const Duration(milliseconds: 2));
    expect(pages.page, start + 20);

    unawaited(controller.animateToItem(21));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(pages.page, lessThan(start + 21), reason: 'one page takes 350 ms, not less');
    await tester.pump(const Duration(milliseconds: 100));
    expect(pages.page, closeTo(start + 21, 0.01), reason: 'one page = 350 ms');
  });
}
