import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flywheel_carousel/flywheel_carousel.dart';

import 'demo_layout.dart';

/// Driving the wheel from code with a `FlywheelCarouselController`, plus
/// `onItemTap` and `semanticLabel`.
class ControlsDemo extends StatefulWidget {
  const ControlsDemo({super.key});

  @override
  State<ControlsDemo> createState() => _ControlsDemoState();
}

class _ControlsDemoState extends State<ControlsDemo> {
  static const _planets = [
    _Planet('Mercury', Color(0xFF9E9E9E), 0.0),
    _Planet('Venus', Color(0xFFE8C07D), 0.5),
    _Planet('Earth', Color(0xFF4F86C6), 0.55),
    _Planet('Mars', Color(0xFFC1440E), 0.25),
    _Planet('Jupiter', Color(0xFFD8A47F), 1.0),
  ];
  static const _ordinals = ['1st', '2nd', '3rd', '4th', '5th'];

  final _controller = FlywheelCarouselController();
  int _selected = 0;
  String? _lastTapped;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    super.dispose();
  }

  void _onControllerChanged() => setState(() => _selected = _controller.index);

  @override
  Widget build(BuildContext context) {
    return DemoBody(
      children: [
        FlywheelCarousel<_Planet>(
          items: _planets,
          controller: _controller,
          semanticLabel: 'Planets',
          onTick: HapticFeedback.selectionClick,
          onItemTap: (i) => setState(() => _lastTapped = _planets[i].name),
          itemBuilder: (context, planet, isSelected) => FlywheelItemCard(
            leading: _PlanetDisc(planet: planet),
            title: planet.name,
            subtitle: '${_ordinals[_planets.indexOf(planet)]} from the Sun',
            selected: isSelected,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              tooltip: 'Previous',
              icon: const Icon(Icons.chevron_left),
              onPressed: _controller.previous,
            ),
            const SizedBox(width: 16),
            IconButton.filledTonal(
              tooltip: 'Next',
              icon: const Icon(Icons.chevron_right),
              onPressed: _controller.next,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var i = 0; i < _planets.length; i++)
                ChoiceChip(
                  label: Text('${i + 1}'),
                  selected: _selected == i,
                  onSelected: (_) => _controller.animateToItem(i),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Readout('Selected: ${_planets[_selected].name}'),
        const SizedBox(height: 8),
        Text(
          'Last tapped: ${_lastTapped ?? 'none'}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

/// A planet: [size] is relative, 0 (smallest) to 1 (largest).
class _Planet {
  const _Planet(this.name, this.color, this.size);

  final String name;
  final Color color;
  final double size;
}

class _PlanetDisc extends StatelessWidget {
  const _PlanetDisc({required this.planet});

  final _Planet planet;

  @override
  Widget build(BuildContext context) {
    final diameter = 36 + 16 * planet.size;
    final hsl = HSLColor.fromColor(planet.color);
    final light = hsl.withLightness((hsl.lightness + 0.2).clamp(0.0, 1.0)).toColor();
    final dark = hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
    return SizedBox(
      width: 56,
      height: 56,
      child: Center(
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.4, -0.4),
              radius: 1.0,
              colors: [light, planet.color, dark],
              stops: const [0.0, 0.55, 1.0],
            ),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
        ),
      ),
    );
  }
}
