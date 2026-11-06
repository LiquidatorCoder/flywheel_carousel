import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flywheel_carousel/flywheel_carousel.dart';

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  int initialIndex = 0,
  ValueChanged<int>? onIndexChanged,
}) async {
  tester.view.physicalSize = Size(width * 3, 800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: FlywheelCarousel<int>(
            items: const [0, 1, 2, 3, 4],
            initialIndex: initialIndex,
            onIndexChanged: onIndexChanged,
            itemBuilder: (context, item, isSelected) => Text('$item'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final width in <double>[320, 375, 390, 393, 402, 430, 874, 932]) {
    testWidgets('looping carousel lays out and scrolls without errors at ${width}pt', (
      tester,
    ) async {
      await _pump(tester, width: width);
      expect(tester.takeException(), isNull);

      for (var i = 0; i < 3; i++) {
        await tester.drag(find.byType(FlywheelCarousel<int>), const Offset(-150, 0));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('loop mode wraps backwards from the first item', (tester) async {
    final changes = <int>[];
    await _pump(tester, width: 402, onIndexChanged: changes.add);

    await tester.timedDrag(
      find.byType(FlywheelCarousel<int>),
      const Offset(200, 0),
      const Duration(seconds: 2),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(changes, isNotEmpty);
    expect(changes.first, 4);
  });

  testWidgets('loop mode wraps forwards from the last item', (tester) async {
    final changes = <int>[];
    await _pump(tester, width: 402, initialIndex: 4, onIndexChanged: changes.add);

    await tester.timedDrag(
      find.byType(FlywheelCarousel<int>),
      const Offset(-200, 0),
      const Duration(seconds: 2),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(changes, isNotEmpty);
    expect(changes.first, 0);
  });
}
