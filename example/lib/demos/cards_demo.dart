import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flywheel_carousel/flywheel_carousel.dart';

import 'demo_layout.dart';

/// `FlywheelItemCard` inside a looping carousel.
class CardsDemo extends StatefulWidget {
  const CardsDemo({super.key});

  @override
  State<CardsDemo> createState() => _CardsDemoState();
}

class _CardsDemoState extends State<CardsDemo> {
  static const _swatches = <_Swatch>[
    _Swatch('Coral', Color(0xFFD97757)),
    _Swatch('Sage', Color(0xFF8AAE92)),
    _Swatch('Cream', Color(0xFFFAF9F5)),
    _Swatch('Ink', Color(0xFF111111)),
    _Swatch('Sky', Color(0xFF7BAEDC)),
  ];

  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outlineVariant;
    return DemoBody(
      children: [
        FlywheelCarousel<_Swatch>(
          items: _swatches,
          onIndexChanged: (i) => setState(() => _selected = i),
          onTick: HapticFeedback.selectionClick,
          semanticLabel: 'Colours',
          itemBuilder: (context, item, isSelected) => FlywheelItemCard(
            leading: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: item.color,
                shape: BoxShape.circle,
                // Visible on both light and dark cards (the Ink swatch).
                border: Border.all(color: outline),
              ),
            ),
            title: item.name,
            subtitle: item.hex,
            selected: isSelected,
          ),
        ),
        const SizedBox(height: 24),
        Readout('Selected: ${_swatches[_selected].name}'),
      ],
    );
  }
}

class _Swatch {
  const _Swatch(this.name, this.color);

  final String name;
  final Color color;

  String get hex =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
}
