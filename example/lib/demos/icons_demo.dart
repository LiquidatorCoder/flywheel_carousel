import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flywheel_carousel/flywheel_carousel.dart';

import 'demo_layout.dart';

/// A fully custom `itemBuilder` (no `FlywheelItemCard`) and a tighter wheel.
class IconsDemo extends StatefulWidget {
  const IconsDemo({super.key});

  @override
  State<IconsDemo> createState() => _IconsDemoState();
}

class _IconsDemoState extends State<IconsDemo> {
  static const _icons = <IconData>[
    Icons.bolt,
    Icons.coffee,
    Icons.spa,
    Icons.travel_explore,
    Icons.rocket_launch,
  ];

  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DemoBody(
      children: [
        FlywheelCarousel<IconData>(
          items: _icons,
          wheelRadius: 240,
          onIndexChanged: (i) => setState(() => _selected = i),
          onTick: HapticFeedback.selectionClick,
          itemBuilder: (context, icon, isSelected) => Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? scheme.primary : scheme.outlineVariant,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Icon(icon, size: 24),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Readout('Index: $_selected'),
      ],
    );
  }
}
