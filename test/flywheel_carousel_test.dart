import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flywheel_carousel/flywheel_carousel.dart';

void main() {
  testWidgets('renders the initial item as selected and neighbours as not', (tester) async {
    int? lastIndex;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: FlywheelCarousel<String>(
              items: const ['A', 'B', 'C', 'D', 'E'],
              initialIndex: 2,
              onIndexChanged: (i) => lastIndex = i,
              itemBuilder: (context, item, isSelected) =>
                  Text('$item:${isSelected ? '1' : '0'}', textDirection: TextDirection.ltr),
            ),
          ),
        ),
      ),
    );

    expect(find.text('C:1'), findsOneWidget);
    expect(find.text('B:0'), findsOneWidget);
    expect(find.text('D:0'), findsOneWidget);
    expect(find.text('A:0'), findsOneWidget);
    expect(find.text('E:0'), findsOneWidget);
    expect(lastIndex, isNull);
  });

  testWidgets('non-loop mode does not render off-end slots', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: FlywheelCarousel<String>(
              items: const ['A', 'B', 'C'],
              initialIndex: 0,
              loop: false,
              itemBuilder: (context, item, isSelected) =>
                  Text(item, textDirection: TextDirection.ltr),
            ),
          ),
        ),
      ),
    );

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
  });

  Widget host({
    required List<String> items,
    int initialIndex = 0,
    bool loop = true,
    double viewportFraction = 0.65,
    double? width,
    ValueChanged<int>? onIndexChanged,
    VoidCallback? onTick,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: FlywheelCarousel<String>(
              items: items,
              initialIndex: initialIndex,
              loop: loop,
              viewportFraction: viewportFraction,
              onIndexChanged: onIndexChanged,
              onTick: onTick,
              itemBuilder: (context, item, isSelected) => SizedBox(
                key: ValueKey('card-$item'),
                child: Text('$item:${isSelected ? '1' : '0'}', textDirection: TextDirection.ltr),
              ),
            ),
          ),
        ),
      ),
    );
  }

  PageController controllerOf(WidgetTester tester) =>
      tester.widget<PageView>(find.byType(PageView)).controller!;

  testWidgets('S3: card width follows the parent width, not the screen', (tester) async {
    await tester.pumpWidget(host(items: const ['A', 'B', 'C'], width: 300));
    expect(tester.getSize(find.byKey(const ValueKey('card-A'))).width, closeTo(300 * 0.65, 0.5));
  });

  testWidgets('S9: crossing several pages in one jump fires one tick per page', (tester) async {
    var ticks = 0;
    await tester.pumpWidget(host(items: const ['A', 'B', 'C', 'D', 'E'], onTick: () => ticks++));
    final c = controllerOf(tester);
    final pageWidth = tester.getSize(find.byType(PageView)).width * 0.65;
    c.jumpTo(c.position.pixels + 3 * pageWidth);
    await tester.pump();
    expect(ticks, 3);
  });

  testWidgets('S4: shrinking items below the selected index keeps selection valid', (tester) async {
    final changes = <int>[];
    await tester.pumpWidget(
      host(
        items: const ['A', 'B', 'C', 'D', 'E'],
        initialIndex: 4,
        loop: false,
        onIndexChanged: changes.add,
      ),
    );
    expect(find.text('E:1'), findsOneWidget);
    await tester.pumpWidget(
      host(items: const ['A', 'B'], initialIndex: 4, loop: false, onIndexChanged: changes.add),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('B:1'), findsOneWidget);
    expect(find.text('A:0'), findsOneWidget);
    expect(changes, [1]);
  });

  testWidgets('S4: toggling loop keeps the current item', (tester) async {
    await tester.pumpWidget(host(items: const ['A', 'B', 'C', 'D', 'E'], initialIndex: 3));
    expect(find.text('D:1'), findsOneWidget);
    await tester.pumpWidget(
      host(items: const ['A', 'B', 'C', 'D', 'E'], initialIndex: 3, loop: false),
    );
    await tester.pump();
    expect(find.text('D:1'), findsOneWidget);
    expect(controllerOf(tester).page, 3);
    await tester.pumpWidget(host(items: const ['A', 'B', 'C', 'D', 'E'], initialIndex: 3));
    await tester.pump();
    expect(find.text('D:1'), findsOneWidget);
    expect(controllerOf(tester).page! % 5, 3);
  });

  testWidgets('S4: changing viewportFraction keeps the item and updates card width', (
    tester,
  ) async {
    final changes = <int>[];
    await tester.pumpWidget(
      host(
        items: const ['A', 'B', 'C', 'D', 'E'],
        initialIndex: 2,
        width: 400,
        onIndexChanged: changes.add,
      ),
    );
    expect(tester.getSize(find.byKey(const ValueKey('card-C'))).width, closeTo(260, 0.5));
    await tester.pumpWidget(
      host(
        items: const ['A', 'B', 'C', 'D', 'E'],
        initialIndex: 2,
        width: 400,
        viewportFraction: 0.8,
        onIndexChanged: changes.add,
      ),
    );
    await tester.pump();
    expect(find.text('C:1'), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('card-C'))).width, closeTo(320, 0.5));
    expect(controllerOf(tester).viewportFraction, 0.8);
    expect(controllerOf(tester).page! % 5, 2);
    expect(changes, isEmpty);
  });
}
