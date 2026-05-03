import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flywheel_carousel/flywheel_carousel.dart';

void main() => runApp(const FlywheelExampleApp());

class FlywheelExampleApp extends StatelessWidget {
  const FlywheelExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flywheel_carousel',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD97757)), useMaterial3: true),
      home: const _Home(),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Flywheel'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Item card'),
              Tab(text: 'Custom builder'),
              Tab(text: 'No loop'),
            ],
          ),
        ),
        body: const TabBarView(children: [_ColorCardDemo(), _IconBuilderDemo(), _NoLoopDemo()]),
      ),
    );
  }
}

class _ColorCardDemo extends StatefulWidget {
  const _ColorCardDemo();

  @override
  State<_ColorCardDemo> createState() => _ColorCardDemoState();
}

class _ColorCardDemoState extends State<_ColorCardDemo> {
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
    final swatch = _swatches[_selected];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FlywheelCarousel<_Swatch>(
          items: _swatches,
          initialIndex: 0,
          onIndexChanged: (i) => setState(() => _selected = i),
          onTick: HapticFeedback.selectionClick,
          itemBuilder: (context, item, isSelected) => FlywheelItemCard(
            leading: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: item.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black12),
              ),
            ),
            title: item.name,
            subtitle: '#${item.color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
            selected: isSelected,
          ),
        ),
        const SizedBox(height: 24),
        Text('Selected: ${swatch.name}', style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _IconBuilderDemo extends StatefulWidget {
  const _IconBuilderDemo();

  @override
  State<_IconBuilderDemo> createState() => _IconBuilderDemoState();
}

class _IconBuilderDemoState extends State<_IconBuilderDemo> {
  static const _icons = <IconData>[Icons.bolt, Icons.coffee, Icons.spa, Icons.travel_explore, Icons.rocket_launch];

  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
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
                color: Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Icon(icon, size: 24),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Index: $_selected', style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _NoLoopDemo extends StatefulWidget {
  const _NoLoopDemo();

  @override
  State<_NoLoopDemo> createState() => _NoLoopDemoState();
}

class _NoLoopDemoState extends State<_NoLoopDemo> {
  static const _names = ['One', 'Two', 'Three', 'Four', 'Five'];

  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FlywheelCarousel<String>(
          items: _names,
          loop: false,
          initialIndex: 2,
          onIndexChanged: (i) => setState(() => _selected = i),
          itemBuilder: (context, name, isSelected) => FlywheelItemCard(
            leading: CircleAvatar(radius: 26, child: Text(name[0])),
            title: name,
            selected: isSelected,
          ),
        ),
        const SizedBox(height: 24),
        Text('Index: $_selected', style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _Swatch {
  const _Swatch(this.name, this.color);
  final String name;
  final Color color;
}
