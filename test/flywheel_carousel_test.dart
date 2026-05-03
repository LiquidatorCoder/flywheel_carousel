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
              itemBuilder: (context, item, isSelected) => Text(
                '$item:${isSelected ? '1' : '0'}',
                textDirection: TextDirection.ltr,
              ),
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
              itemBuilder: (context, item, isSelected) => Text(
                item,
                textDirection: TextDirection.ltr,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
  });
}
