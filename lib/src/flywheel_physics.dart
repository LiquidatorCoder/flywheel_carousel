import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Free-spinning physics for the wheel. A flick decelerates under friction
/// and lands on whichever card the momentum carries it to — the harder the
/// flick, the further it spins. Higher [dragCoefficient] = longer spin.
class FreewheelPhysics extends ScrollPhysics {
  const FreewheelPhysics({
    required this.viewportFraction,
    this.dragCoefficient = 0.35,
    super.parent,
  }) : assert(viewportFraction > 0),
       assert(dragCoefficient > 0 && dragCoefficient < 1);

  final double viewportFraction;

  /// Higher = longer spin: 0 stops at once, values near 1 coast almost
  /// forever (a flick travels `velocity / -ln(dragCoefficient)`). iOS scroll
  /// views use 0.135; the default here is higher to let the wheel coast
  /// through several cards on a flick.
  final double dragCoefficient;

  @override
  FreewheelPhysics applyTo(ScrollPhysics? ancestor) {
    return FreewheelPhysics(
      viewportFraction: viewportFraction,
      dragCoefficient: dragCoefficient,
      parent: buildParent(ancestor),
    );
  }

  /// Speed (in pages per second) under which a coast stops decaying
  /// exponentially and decelerates at a constant rate instead, so the wheel
  /// never crawls through its last half page.
  static const double _switchPagesPerSecond = 3;

  /// Largest pull-in (in pages) done by a settle instead of a coast.
  static const double _maxPullPages = 1.0;

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    if (position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }

    final tolerance = toleranceFor(position);
    final pageWidth = position.viewportDimension * viewportFraction;
    // PageView offsets pages by this much when viewportFraction > 1.
    final offset = math.max(0.0, position.viewportDimension * (viewportFraction - 1) / 2);
    final pixels = position.pixels;
    double pageOf(double px) => (px - offset) / pageWidth;

    final slow = velocity.abs() < tolerance.velocity;
    final natural = slow ? pixels : pixels + velocity / -math.log(dragCoefficient);

    // Natural landing past either end: let the parent bounce or clamp (the end
    // card in non-loop mode), and only coast to it ourselves with no parent.
    if (natural < position.minScrollExtent || natural > position.maxScrollExtent) {
      final parentSimulation = super.createBallisticSimulation(position, velocity);
      if (parentSimulation != null) return parentSimulation;
    }

    final currentPage = pageOf(pixels).round();
    final targetPage = pageOf(natural).round();
    final target = (targetPage * pageWidth + offset).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    final distance = target - pixels;

    if (distance.abs() < tolerance.distance && slow) return null;

    Simulation snap() => _SettleSimulation(
      start: pixels,
      target: target,
      velocity: velocity,
      pageWidth: pageWidth,
      tolerance: tolerance,
    );

    if (slow || targetPage == currentPage || distance.sign != velocity.sign) {
      return snap();
    }
    // Target lies beyond where friction would stop: a short, bounded pull
    // beats a slow crawl.
    final needsPull = distance.abs() > (natural - pixels).abs();
    if (needsPull && distance.abs() <= _maxPullPages * pageWidth + tolerance.distance) {
      return snap();
    }
    final k = velocity.abs() / distance.abs();
    if (k < 0.5 * -math.log(dragCoefficient)) return snap();

    return _FlywheelCoastSimulation(
      start: pixels,
      target: target,
      velocity: velocity,
      switchSpeed: _switchPagesPerSecond * pageWidth,
      tolerance: tolerance,
    );
  }
}

/// Coast that ends exactly on [target]: exponential decay aimed at the target
/// while fast (the same shape as friction), then constant deceleration once
/// slower than [switchSpeed]. Position and velocity are continuous at the
/// hand-off and the speed never increases.
class _FlywheelCoastSimulation extends Simulation {
  _FlywheelCoastSimulation({
    required double start,
    required this.target,
    required double velocity,
    required double switchSpeed,
    super.tolerance,
  }) : _sign = velocity.sign,
       _speed = velocity.abs() {
    final k = _speed / (target - start).abs();
    _k = k;
    if (_speed > switchSpeed) {
      _t1 = math.log(_speed / switchSpeed) / k;
      _s1 = switchSpeed;
      _x1 = target - _sign * switchSpeed / k;
    } else {
      _t1 = 0;
      _s1 = _speed;
      _x1 = start;
    }
    final remaining = (target - _x1).abs();
    _decel = _s1 * _s1 / (2 * remaining);
    _t2 = 2 * remaining / _s1;
  }

  final double target;
  final double _sign;
  final double _speed;
  late final double _k;
  late final double _t1; // end of the exponential phase
  late final double _t2; // duration of the constant-deceleration phase
  late final double _s1; // speed at the hand-off
  late final double _x1; // position at the hand-off
  late final double _decel;

  @override
  double x(double time) {
    if (time >= _t1 + _t2) return target;
    if (time < _t1) return target - _sign * (_speed / _k) * math.exp(-_k * time);
    final tau = time - _t1;
    return _x1 + _sign * (_s1 * tau - _decel * tau * tau / 2);
  }

  @override
  double dx(double time) {
    if (time >= _t1 + _t2) return 0;
    if (time < _t1) return _sign * _speed * math.exp(-_k * time);
    return _sign * (_s1 - _decel * (time - _t1));
  }

  @override
  bool isDone(double time) => time >= _t1 + _t2;
}

/// Short eased move to [target] (cubic Hermite from the release position and
/// velocity to rest). Fixed duration, so it settles quickly with no tail, and
/// it never passes the target.
class _SettleSimulation extends Simulation {
  _SettleSimulation({
    required this.start,
    required this.target,
    required double velocity,
    required double pageWidth,
    super.tolerance,
  }) : _d = target - start,
       _v0 = velocity {
    var t = (0.28 + 0.20 * _d.abs() / pageWidth).clamp(0.28, 0.48);
    // Keep the curve monotonic when the release velocity points at the target.
    if (_d != 0 && _v0.sign == _d.sign && _v0.abs() * t > 2.5 * _d.abs()) {
      t = math.max(0.12, 2.5 * _d.abs() / _v0.abs());
    }
    _t = t;
  }

  final double start;
  final double target;
  final double _d;
  final double _v0;
  late final double _t;

  @override
  double x(double time) {
    if (time >= _t) return target;
    final u = time / _t;
    return start + _d * (3 * u * u - 2 * u * u * u) + _v0 * _t * (u - 2 * u * u + u * u * u);
  }

  @override
  double dx(double time) {
    if (time >= _t) return 0;
    final u = time / _t;
    return (_d * (6 * u - 6 * u * u) + _v0 * _t * (1 - 4 * u + 3 * u * u)) / _t;
  }

  @override
  bool isDone(double time) => time >= _t;
}
