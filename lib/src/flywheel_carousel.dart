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

  late final PageController _controller;
  late int _selectedIndex;
  late int _lastTickPage;

  int get _count => widget.items.length;

  int _initialPage() => widget.loop
      ? _loopMultiplier * _count + widget.initialIndex.clamp(0, _count - 1)
      : widget.initialIndex.clamp(0, _count - 1);

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, _count - 1);
    _lastTickPage = _initialPage();
    _controller = PageController(
      viewportFraction: widget.viewportFraction,
      initialPage: _lastTickPage,
    );
    _controller.addListener(_onWheelTick);
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
    _lastTickPage = rounded;

    final index = ((rounded % _count) + _count) % _count;
    if (index != _selectedIndex) {
      setState(() => _selectedIndex = index);
      widget.onIndexChanged?.call(index);
    }

    widget.onTick?.call();
  }

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = viewportWidth * widget.viewportFraction;
    final virtualItemCount = widget.loop ? _count * _loopMultiplier * 2 : _count;

    return SizedBox(
      height: widget.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Gesture/scroll layer — invisible items, drives the controller.
          PageView.builder(
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
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final page = _controller.hasClients
                      ? (_controller.page ?? _initialPage().toDouble())
                      : _initialPage().toDouble();
                  return FlywheelWheel<T>(
                    page: page,
                    items: widget.items,
                    selectedIndex: _selectedIndex,
                    itemBuilder: widget.itemBuilder,
                    cardWidth: cardWidth,
                    cardHeight: widget.cardHeight,
                    angularStep: widget.angularStep,
                    radius: widget.wheelRadius,
                    visibleSlots: widget.visibleSlots,
                    loop: widget.loop,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
