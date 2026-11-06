import 'package:flutter/material.dart';
import 'package:flywheel_carousel/flywheel_carousel.dart';

import 'demo_layout.dart';

/// `loop: false`: the wheel stops at the first and last item.
class NoLoopDemo extends StatefulWidget {
  const NoLoopDemo({super.key});

  @override
  State<NoLoopDemo> createState() => _NoLoopDemoState();
}

class _NoLoopDemoState extends State<NoLoopDemo> {
  static const _names = ['One', 'Two', 'Three', 'Four', 'Five'];

  int _selected = 2;

  @override
  Widget build(BuildContext context) {
    return DemoBody(
      children: [
        FlywheelCarousel<String>(
          items: _names,
          loop: false,
          initialIndex: _selected,
          onIndexChanged: (i) => setState(() => _selected = i),
          itemBuilder: (context, name, isSelected) => FlywheelItemCard(
            leading: CircleAvatar(radius: 26, child: Text(name[0])),
            title: name,
            selected: isSelected,
          ),
        ),
        const SizedBox(height: 24),
        Readout('Index: $_selected'),
      ],
    );
  }
}
