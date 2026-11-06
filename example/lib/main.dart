import 'package:flutter/material.dart';

import 'demos/cards_demo.dart';
import 'demos/controls_demo.dart';
import 'demos/demo_layout.dart';
import 'demos/icons_demo.dart';
import 'demos/no_loop_demo.dart';

void main() => runApp(const FlywheelExampleApp());

const _seed = Color(0xFFD97757);

ThemeData _theme(Brightness brightness) => ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: brightness),
  useMaterial3: true,
);

class FlywheelExampleApp extends StatelessWidget {
  const FlywheelExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flywheel_carousel',
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const _Home(),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Flywheel'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            tabs: [
              Tab(text: 'Cards'),
              Tab(text: 'Icons'),
              Tab(text: 'No loop'),
              Tab(text: 'Controls'),
            ],
          ),
        ),
        // Each demo is wrapped so its state (selection, wheel position)
        // survives switching tabs.
        body: const TabBarView(
          children: [
            KeepAliveTab(child: CardsDemo()),
            KeepAliveTab(child: IconsDemo()),
            KeepAliveTab(child: NoLoopDemo()),
            KeepAliveTab(child: ControlsDemo()),
          ],
        ),
      ),
    );
  }
}
