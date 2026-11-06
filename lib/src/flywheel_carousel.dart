import 'dart:async';

import 'package:flutter/widgets.dart';

import 'flywheel_controller.dart';
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
    this.controller,
    this.onItemTap,
    this.selectOnTap = true,
    this.semanticLabel,
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

  /// Moves the wheel from outside (next/previous, restore a selection) and
  /// reports the selected index. The carousel never disposes it.
  final FlywheelCarouselController? controller;

  /// Called with the item index when a card is tapped, including the centre
  /// card. A tap that only catches a spinning wheel does not call it.
  final ValueChanged<int>? onItemTap;

  /// Whether tapping a side card turns the wheel to it. Defaults to true.
  final bool selectOnTap;

  /// Accessibility label for the carousel as a whole. Screen readers announce
  /// it with the position ("2 of 5"); the position can be adjusted by swiping
  /// up or down.
  final String? semanticLabel;

  @override
  State<FlywheelCarousel<T>> createState() => _FlywheelCarouselState<T>();
}

class _FlywheelCarouselState<T> extends State<FlywheelCarousel<T>>
    implements FlywheelControllerBinding {
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
    if (widget.controller case final c?) attachFlywheelController(c, this);
  }

  @override
  void didUpdateWidget(FlywheelCarousel<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller case final c?) detachFlywheelController(c, this);
      if (widget.controller case final c?) attachFlywheelController(c, this);
    }
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
        if (!mounted) return;
        widget.onIndexChanged?.call(index);
        _notifyController();
      });
    }
  }

  @override
  void dispose() {
    if (widget.controller case final c?) detachFlywheelController(c, this);
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
    if (indexChanged) {
      widget.onIndexChanged?.call(index);
      _notifyController();
    }

    // One tick per crossed page, so a multi-page jump still ticks each page.
    for (var i = 0; i < crossed; i++) {
      widget.onTick?.call();
    }
  }

  void _notifyController() {
    if (widget.controller case final c?) notifyFlywheelController(c);
  }

  // --- FlywheelControllerBinding -------------------------------------------

  @override
  bool get isReady => mounted && _controller.hasClients;

  @override
  int get selectedIndex => _selectedIndex;

  /// The page the wheel is on (or heading to rest at).
  int get _currentPage =>
      _controller.hasClients ? (_controller.page ?? _lastTickPage).round() : _lastTickPage;

  /// The virtual page to travel to for [index]: the nearest copy in loop mode,
  /// the clamped item otherwise.
  int _targetPage(int index) {
    if (!widget.loop) return index.clamp(0, _count - 1);
    final current = _currentPage;
    var diff = (index - current) % _count; // Dart's % is non-negative here.
    if (diff * 2 > _count) diff -= _count;
    return current + diff;
  }

  Future<void> _animateToPage(int page, {Duration? duration, Curve curve = Curves.easeOutCubic}) {
    final distance = (page - (_controller.page ?? page)).abs();
    if (distance < 1e-6) return Future<void>.value();
    if (duration == Duration.zero || (MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      _controller.jumpToPage(page);
      return Future<void>.value();
    }
    final ms = (280 + 70 * distance.ceil()).clamp(280, 600);
    return _controller.animateToPage(
      page,
      duration: duration ?? Duration(milliseconds: ms),
      curve: curve,
    );
  }

  @override
  Future<void> animateToItem(int index, Duration? duration, Curve curve) =>
      _animateToPage(_targetPage(index), duration: duration, curve: curve);

  @override
  void jumpToItem(int index) => _controller.jumpToPage(_targetPage(index));

  Future<void> _step(int delta) {
    final page = _currentPage + delta;
    if (!widget.loop && (page < 0 || page >= _count)) return Future<void>.value();
    return _animateToPage(page);
  }

  @override
  Future<void> next() => _step(1);

  @override
  Future<void> previous() => _step(-1);

  // --- Tap -----------------------------------------------------------------

  bool _tapCaughtSpinningWheel = false;
  double _wheelWidth = 0;

  void _handleTapDown(TapDownDetails details) {
    // By the time a tap is recognised the PageView has already held the wheel,
    // so "was it moving" is read off the position: a held wheel that is not
    // resting on a whole page was mid-coast.
    final page = _controller.hasClients ? _controller.page : null;
    _tapCaughtSpinningWheel = page != null && (page - page.round()).abs() > 0.02;
  }

  void _handleTapUp(TapUpDetails details) {
    if (_tapCaughtSpinningWheel || !_controller.hasClients) return;
    final page = _controller.page;
    if (page == null) return;
    final center = _lastTickPage;
    final rawPages = [
      for (var o = -widget.visibleSlots; o <= widget.visibleSlots; o++)
        if (widget.loop || (center + o >= 0 && center + o < _count)) center + o,
    ];
    final geometry = WheelGeometry(
      width: _wheelWidth,
      cardWidth: _wheelWidth * widget.viewportFraction,
      cardHeight: widget.cardHeight,
      angularStep: widget.angularStep,
      radius: widget.wheelRadius,
      visibleSlots: widget.visibleSlots,
    );
    final hit = geometry.hitTest(details.localPosition, page, rawPages);
    if (hit == null) return;
    widget.onItemTap?.call(((hit % _count) + _count) % _count);
    if (widget.selectOnTap && hit != _currentPage) unawaited(_animateToPage(hit));
  }

  @override
  Widget build(BuildContext context) {
    final loop = widget.loop;
    final canIncrease = loop || _selectedIndex < _count - 1;
    final canDecrease = loop || _selectedIndex > 0;
    String position(int index) => '${index + 1} of $_count';

    return Semantics(
      container: true,
      label: widget.semanticLabel,
      value: position(_selectedIndex),
      increasedValue: canIncrease ? position((_selectedIndex + 1) % _count) : null,
      decreasedValue: canDecrease ? position((_selectedIndex - 1 + _count) % _count) : null,
      onIncrease: canIncrease ? () => unawaited(next()) : null,
      onDecrease: canDecrease ? () => unawaited(previous()) : null,
      child: _buildWheel(context),
    );
  }

  Widget _buildWheel(BuildContext context) {
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
          _wheelWidth = width;
          final cardWidth = width * widget.viewportFraction;
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            // Selection is exposed through the adjustable container instead.
            excludeFromSemantics: true,
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Gesture/scroll layer — invisible items, drives the controller.
                ExcludeSemantics(
                  child: PageView.builder(
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
            ),
          );
        },
      ),
    );
  }
}
