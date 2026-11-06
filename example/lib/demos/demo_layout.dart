import 'package:flutter/material.dart';

/// Keeps its [child] (and so its state) alive while its tab is off-screen.
class KeepAliveTab extends StatefulWidget {
  const KeepAliveTab({super.key, required this.child});

  final Widget child;

  @override
  State<KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<KeepAliveTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// A vertically centred column that scrolls instead of overflowing, so a demo
/// stays usable in landscape and at large text sizes.
class DemoBody extends StatelessWidget {
  const DemoBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: children),
        ),
      ),
    );
  }
}

/// A line of text that fades and slides in when [text] changes.
class Readout extends StatelessWidget {
  const Readout(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      // The outgoing text leaves at once, so only one copy is ever settled.
      reverseDuration: Duration.zero,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: Text(text, key: ValueKey(text), style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
