import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'flywheel_test_support.dart';

final _carousel = find.semantics.byLabel(RegExp('^Colours'));

SemanticsNode _node(WidgetTester tester) => _carousel.evaluate().single;

SemanticsData _data(WidgetTester tester) => _node(tester).getSemanticsData();

Future<SemanticsHandle> _pump(WidgetTester tester, {bool loop = true, int initialIndex = 0}) async {
  final handle = tester.ensureSemantics();
  usePhoneSurface(tester);
  await tester.pumpWidget(
    carouselApp(semanticLabel: 'Colours', loop: loop, initialIndex: initialIndex),
  );
  return handle;
}

void main() {
  testWidgets('announces "1 of 5" with the label as an adjustable control', (tester) async {
    final handle = await _pump(tester);
    final data = _data(tester);
    expect(data.value, '1 of 5');
    expect(data.increasedValue, '2 of 5');
    expect(data.decreasedValue, '5 of 5', reason: 'loop wraps');
    expect(data.hasAction(SemanticsAction.increase), isTrue);
    expect(data.hasAction(SemanticsAction.decrease), isTrue);
    handle.dispose();
  });

  testWidgets('the increase and decrease actions move the wheel', (tester) async {
    final handle = await _pump(tester);

    tester.semantics.performAction(_carousel, SemanticsAction.increase);
    await tester.pumpAndSettle();
    expect(_data(tester).value, '2 of 5');

    tester.semantics.performAction(_carousel, SemanticsAction.decrease);
    await tester.pumpAndSettle();
    expect(_data(tester).value, '1 of 5');
    handle.dispose();
  });

  testWidgets('only the centre card is in the semantics tree', (tester) async {
    final handle = await _pump(tester);

    // The centre card's text merges into the carousel's own node.
    expect(_data(tester).label, 'Colours\nA');
    for (final other in ['B', 'C', 'D', 'E']) {
      expect(find.bySemanticsLabel(other), findsNothing, reason: 'card $other is decoration');
    }

    tester.semantics.performAction(_carousel, SemanticsAction.increase);
    await tester.pumpAndSettle();
    expect(_data(tester).label, 'Colours\nB');
    expect(find.bySemanticsLabel('A'), findsNothing);
    handle.dispose();
  });

  testWidgets('the gesture PageView exposes no scrolling or tap actions', (tester) async {
    final handle = await _pump(tester);
    final data = _data(tester);
    expect(data.hasAction(SemanticsAction.scrollLeft), isFalse);
    expect(data.hasAction(SemanticsAction.scrollRight), isFalse);
    expect(data.hasAction(SemanticsAction.tap), isFalse);
    handle.dispose();
  });

  testWidgets('non-loop ends omit the impossible action', (tester) async {
    var handle = await _pump(tester, loop: false);
    var data = _data(tester);
    expect(data.value, '1 of 5');
    expect(data.hasAction(SemanticsAction.decrease), isFalse);
    expect(data.decreasedValue, isEmpty);
    expect(data.hasAction(SemanticsAction.increase), isTrue);
    handle.dispose();

    await tester.pumpWidget(const SizedBox());
    handle = await _pump(tester, loop: false, initialIndex: 4);
    data = _data(tester);
    expect(data.value, '5 of 5');
    expect(data.hasAction(SemanticsAction.increase), isFalse);
    expect(data.increasedValue, isEmpty);
    expect(data.hasAction(SemanticsAction.decrease), isTrue);
    handle.dispose();
  });
}
