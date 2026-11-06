import 'package:flutter/widgets.dart';

import 'flywheel_physics.dart';
import 'flywheel_wheel.dart';

/// A free-spinning, arc-shaped carousel. Items ride the rim of a large
/// invisible wheel. Flicks coast under friction and snap to the nearest item.
///
/// The carousel is dumb about content — supply [items] and an [itemBuilder].
/// Selection settles via [onIndexChanged]; per-tick events (one per integer
/// page crossing) fire on [onTick] so callers can wire haptics.
class FlywheelCarousel<T> extends StatefulWidget {
  const FlywheelCarousel({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.initialIndex = 0,
    this.onIndexChanged,
    this.onTick,
    this.height = 230,
    this.cardHeight = 200,
    this.viewportFraction = 0.65,
    this.angularStep = 0.42,
    this.wheelRadius = 320,
    this.visibleSlots = 2,
    this.dragCoefficient = 0.35,
    this.loop = true,
  }) : assert(items.length > 0, 'FlywheelCarousel requires at least one item'),
       assert(initialIndex >= 0, 'initialIndex must be non-negative'),
       assert(visibleSlots >= 0, 'visibleSlots must be non-negative');

  final List<T> items;
  final FlywheelItemBuilder<T> itemBuilder;
  final int initialIndex;
  final ValueChanged<int>? onIndexChanged;
  final VoidCallback? onTick;
  final double height;
  final double cardHeight;
  final double viewportFraction;
  final double angularStep;
  final double wheelRadius;
  final int visibleSlots;
  final double dragCoefficient;
  final bool loop;

  @override
  State<FlywheelCarousel<T>> createState() => _FlywheelCarouselState<T>();
}

class _FlywheelCarouselState<T> extends State<FlywheelCarousel<T>> {
  static const _loopMultiplier = 5000;

  late PageController _controller;
  late int _selectedIndex;
  late int _lastTickPage;

  int get _count => widget.items.length;

  int _pageFor(int index) => widget.loop ? _loopMultiplier * _count + index : index;

  int _initialPage() => _pageFor(widget.initialIndex.clamp(0, _count - 1));

  PageController _createController(int page) {
    return PageController(viewportFraction: widget.viewportFraction, initialPage: page)
      ..addListener(_onWheelTick);
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, _count - 1);
    _lastTickPage = _initialPage();
    _controller = _createController(_lastTickPage);
  }

  @override
  void didUpdateWidget(FlywheelCarousel<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewportFraction == widget.viewportFraction &&
        oldWidget.loop == widget.loop &&
        oldWidget.items.length == widget.items.length) {
      return;
    }

    // The page <-> item mapping or the page extent changed: restart the
    // controller on the equivalent page of the (clamped) current item.
    final previousIndex = _selectedIndex;
    _selectedIndex = _selectedIndex.clamp(0, _count - 1);
    _lastTickPage = _pageFor(_selectedIndex);

    final old = _controller;
    old.removeListener(_onWheelTick);
    _controller = _createController(_lastTickPage);
    // The old controller is still attached until this frame's build swaps it.
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());

    if (_selectedIndex != previousIndex) {
      final index = _selectedIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onIndexChanged?.call(index);
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onWheelTick);
    _controller.dispose();
    super.dispose();
  }

  void _onWheelTick() {
    if (!mounted) return;
    if (!_controller.hasClients) return;
    final page = _controller.page;
    if (page == null) return;
    final rounded = page.round();
    if (rounded == _lastTickPage) return;
    final crossed = (rounded - _lastTickPage).abs();
    _lastTickPage = rounded;

    // The card window is built around the center page, so rebuild on every
    // crossing (and never between crossings: the wheel repaints on its own).
    final index = ((rounded % _count) + _count) % _count;
    final indexChanged = index != _selectedIndex;
    setState(() => _selectedIndex = index);
    if (indexChanged) widget.onIndexChanged?.call(index);

    // One tick per crossed page, so a multi-page jump still ticks each page.
    for (var i = 0; i < crossed; i++) {
      widget.onTick?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Unbounded in loop mode: a finite huge count trips the sliver's
    // itemExtent-multiple precision assert at many widths.
    final int? virtualItemCount = widget.loop ? null : _count;

    return SizedBox(
      height: widget.height,
      // Pages are sized from the carousel's own width, so cards must be too.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final cardWidth = width * widget.viewportFraction;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Gesture/scroll layer — invisible items, drives the controller.
              PageView.builder(
                // A new controller needs a fresh scroll position: without the
                // key the old pixel offset would carry over to the new page map.
                key: ObjectKey(_controller),
                controller: _controller,
                pageSnapping: false,
                physics: FreewheelPhysics(
                  viewportFraction: widget.viewportFraction,
                  dragCoefficient: widget.dragCoefficient,
                ),
                itemCount: virtualItemCount,
                itemBuilder: (_, _) => const SizedBox.shrink(),
              ),
              // Visual layer — renders cards on the wheel's arc with z-order
              // so the center card always sits on top of its neighbours.
              Positioned.fill(
                child: IgnorePointer(
                  child: FlywheelWheel<T>(
                    controller: _controller,
                    fallbackPage: _pageFor(_selectedIndex).toDouble(),
                    centerPage: _lastTickPage,
                    items: widget.items,
                    selectedIndex: _selectedIndex,
                    itemBuilder: widget.itemBuilder,
                    cardWidth: cardWidth,
                    cardHeight: widget.cardHeight,
                    angularStep: widget.angularStep,
                    radius: widget.wheelRadius,
                    visibleSlots: widget.visibleSlots,
                    loop: widget.loop,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
