import 'package:flutter/widgets.dart';

/// The carousel-side half of a [FlywheelCarouselController]. Internal: the
/// barrel does not export it.
abstract class FlywheelControllerBinding {
  /// Whether the carousel has laid out and can be moved.
  bool get isReady;

  /// The selected item index.
  int get selectedIndex;

  Future<void> animateToItem(int index, Duration? duration, Curve curve);
  void jumpToItem(int index);
  Future<void> next();
  Future<void> previous();
}

/// Moves a [FlywheelCarousel] from outside: next/previous buttons, restoring a
/// selection, or following other UI.
///
/// Pass it as `FlywheelCarousel.controller`. It is a [ChangeNotifier] that
/// notifies whenever the selected [index] changes, however the change came
/// about (drag, tap or a call on this controller). Dispose it yourself.
///
/// A controller drives one carousel at a time and can only be used while that
/// carousel is mounted and laid out; before that, calls throw a [StateError].
class FlywheelCarouselController extends ChangeNotifier {
  FlywheelControllerBinding? _binding;

  /// Whether a mounted, laid-out carousel is using this controller.
  bool get isAttached => _binding?.isReady ?? false;

  /// The selected item index. Only valid while [isAttached].
  int get index => _requireBinding().selectedIndex;

  /// Animates to item [index].
  ///
  /// In a looping carousel the wheel turns along the shortest path (the
  /// nearest copy of the item); otherwise [index] is clamped to the item range.
  /// [duration] defaults to 280 ms plus 70 ms per page travelled, capped at
  /// 600 ms. When the platform asks for reduced motion
  /// (`MediaQuery.disableAnimationsOf`) the wheel jumps instead.
  ///
  /// The future completes when the wheel settles, or earlier if the user
  /// grabs it.
  Future<void> animateToItem(int index, {Duration? duration, Curve curve = Curves.easeOutCubic}) =>
      _requireBinding().animateToItem(index, duration, curve);

  /// Moves to item [index] immediately, along the same path [animateToItem]
  /// would take.
  void jumpToItem(int index) => _requireBinding().jumpToItem(index);

  /// Animates one item forward. At the last item of a non-looping carousel
  /// this does nothing.
  Future<void> next() => _requireBinding().next();

  /// Animates one item back. At the first item of a non-looping carousel this
  /// does nothing.
  Future<void> previous() => _requireBinding().previous();

  FlywheelControllerBinding _requireBinding() {
    final binding = _binding;
    if (binding == null || !binding.isReady) {
      throw StateError(
        'FlywheelCarouselController is not attached to a laid-out '
        'FlywheelCarousel. Pass it as FlywheelCarousel.controller and wait '
        'for the first frame before calling it.',
      );
    }
    return binding;
  }

  void _notify() => notifyListeners();
}

/// Internal: used by the carousel's state to (un)bind a controller.
void attachFlywheelController(
  FlywheelCarouselController controller,
  FlywheelControllerBinding binding,
) {
  assert(
    controller._binding == null || controller._binding == binding,
    'A FlywheelCarouselController can drive only one FlywheelCarousel at a time.',
  );
  controller._binding = binding;
}

/// Internal: no-op unless [binding] is the one currently attached.
void detachFlywheelController(
  FlywheelCarouselController controller,
  FlywheelControllerBinding binding,
) {
  if (controller._binding == binding) controller._binding = null;
}

/// Internal: tells listeners the selected index changed.
void notifyFlywheelController(FlywheelCarouselController controller) => controller._notify();
