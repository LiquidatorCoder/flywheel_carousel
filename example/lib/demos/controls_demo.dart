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
  static const _planets = ['Mercury', 'Venus', 'Earth', 'Mars', 'Jupiter'];

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
        FlywheelCarousel<String>(
          items: _planets,
          controller: _controller,
          semanticLabel: 'Planets',
          onTick: HapticFeedback.selectionClick,
          onItemTap: (i) => setState(() => _lastTapped = _planets[i]),
          itemBuilder: (context, name, isSelected) => FlywheelItemCard(
            leading: const Icon(Icons.public, size: 40),
            title: name,
            subtitle: 'Planet ${_planets.indexOf(name) + 1} from the Sun',
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
        Readout('Selected: ${_planets[_selected]}'),
        const SizedBox(height: 8),
        Text(
          'Last tapped: ${_lastTapped ?? 'none'}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
