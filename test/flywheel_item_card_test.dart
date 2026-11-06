import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flywheel_carousel/flywheel_carousel.dart';

Widget _card({double textScale = 1.0, String title = 'Item 0'}) => MaterialApp(
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Center(
        child: SizedBox(
          width: 253,
          height: 200,
          child: FlywheelItemCard(
            leading: const CircleAvatar(radius: 26, child: Text('0')),
            title: title,
            subtitle: '#0',
            selected: true,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('fits its card at text scale 3.0 without overflowing', (tester) async {
    await tester.pumpWidget(_card(textScale: 3.0));
    expect(tester.takeException(), isNull);
    final card = tester.getRect(find.byType(FlywheelItemCard));
    expect(card.height, 200);
    for (final label in ['Item 0', '#0']) {
      final rect = tester.getRect(find.text(label));
      expect(rect.top, greaterThanOrEqualTo(card.top - 0.5), reason: label);
      expect(rect.bottom, lessThanOrEqualTo(card.bottom + 0.5), reason: label);
    }
  });

  testWidgets('is not scaled at text scale 1.0', (tester) async {
    await tester.pumpWidget(_card());
    expect(tester.takeException(), isNull);
    // titleMedium is 16 px with a 1.5 line height: 24 px, unscaled.
    expect(tester.getSize(find.text('Item 0')).height, closeTo(24, 0.01));
  });

  testWidgets('a long title still ellipsizes at scale 1.0', (tester) async {
    await tester.pumpWidget(_card(title: 'A very long title that cannot fit on one line at all'));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.textContaining('A very long')).width, lessThanOrEqualTo(253));
  });
}
