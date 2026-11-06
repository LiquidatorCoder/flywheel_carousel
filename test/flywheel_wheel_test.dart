import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flywheel_carousel/src/flywheel_wheel.dart';

class _StatefulItem extends StatefulWidget {
  const _StatefulItem({required this.item});
  final int item;

  @override
  State<_StatefulItem> createState() => _StatefulItemState();
}

class _StatefulItemState extends State<_StatefulItem> {
  late final int born = widget.item;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

Widget _wheel({
  required double page,
  int count = 12,
  int visibleSlots = 2,
  bool loop = true,
  FlywheelItemBuilder<int>? builder,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: 400,
        height: 230,
        child: FlywheelWheel<int>(
          page: page,
          items: List<int>.generate(count, (i) => i),
          selectedIndex: page.round() % count,
          itemBuilder:
              builder ??
              (_, item, _) => SizedBox(key: ValueKey('card-$item'), width: 100, height: 100),
          cardWidth: 100,
          cardHeight: 100,
          angularStep: 0.42,
          radius: 320,
          visibleSlots: visibleSlots,
          loop: loop,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('S1: visibleSlots 4 places every card at a distinct position', (tester) async {
    await tester.pumpWidget(_wheel(page: 5, visibleSlots: 4));
    Offset center(int i) => tester.getCenter(find.byKey(ValueKey('card-$i')));
    for (var i = 1; i < 9; i++) {
      expect((center(i + 1) - center(i)).distance, greaterThan(1), reason: 'cards $i and ${i + 1}');
    }
  });

  testWidgets('L1: opacity is full at centre and fades toward the window edge', (tester) async {
    await tester.pumpWidget(_wheel(page: 5.25, visibleSlots: 2));
    double opacityOf(int i) => tester
        .widget<Opacity>(
          find.ancestor(of: find.byKey(ValueKey('card-$i')), matching: find.byType(Opacity)),
        )
        .opacity;
    expect(opacityOf(5), greaterThan(0.9));
    // card 3 is at t = -2.25: inside the window but nearly faded out.
    expect(opacityOf(3), lessThan(0.15));
    expect(opacityOf(3), greaterThanOrEqualTo(0.0));
    expect(opacityOf(5), greaterThan(opacityOf(4)));
    expect(opacityOf(4), greaterThan(opacityOf(3)));
  });

  testWidgets('S2: item state stays with its item while the wheel turns', (tester) async {
    await tester.pumpWidget(_wheel(page: 5, builder: (_, item, _) => _StatefulItem(item: item)));
    for (var step = 0; step <= 6; step++) {
      await tester.pumpWidget(
        _wheel(
          page: 5 + step * 0.3,
          builder: (_, item, _) => _StatefulItem(item: item),
        ),
      );
      for (final e in tester.stateList<_StatefulItemState>(find.byType(_StatefulItem))) {
        expect(e.born, e.widget.item, reason: 'state migrated at step $step');
      }
    }
  });
}
