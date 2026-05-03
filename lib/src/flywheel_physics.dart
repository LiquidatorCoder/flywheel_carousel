import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Free-spinning physics for the wheel. A flick decelerates under friction
/// and lands on whichever card the momentum carries it to — the harder the
/// flick, the further it spins. Lower [dragCoefficient] = longer spin.
class FreewheelPhysics extends ScrollPhysics {
  const FreewheelPhysics({
    required this.viewportFraction,
    this.dragCoefficient = 0.35,
    super.parent,
  });

  final double viewportFraction;

  /// 0.0 = instant stop; 1.0 = perpetual motion. iOS scroll views use 0.135;
  /// the default here is higher to let the wheel coast through several cards
  /// on a flick.
  final double dragCoefficient;

  @override
  FreewheelPhysics applyTo(ScrollPhysics? ancestor) {
    return FreewheelPhysics(
      viewportFraction: viewportFraction,
      dragCoefficient: dragCoefficient,
      parent: buildParent(ancestor),
    );
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final tolerance = toleranceFor(position);
    final pageWidth = position.viewportDimension * viewportFraction;

    if (position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }

    if (velocity.abs() < tolerance.velocity) {
      final currentPage = position.pixels / pageWidth;
      final targetPage = currentPage.round();
      final target = targetPage * pageWidth;
      if ((target - position.pixels).abs() < tolerance.distance) {
        return null;
      }
      return ScrollSpringSimulation(
        SpringDescription.withDampingRatio(mass: 1.0, stiffness: 120, ratio: 1.1),
        position.pixels,
        target,
        0,
        tolerance: tolerance,
      );
    }

    final predicted = FrictionSimulation(dragCoefficient, position.pixels, velocity).finalX;
    final settlingPage = (predicted / pageWidth).round();
    final settlingDestination = settlingPage * pageWidth;

    return FrictionSimulation.through(
      position.pixels,
      settlingDestination,
      velocity,
      tolerance.velocity * velocity.sign,
    );
  }
}
