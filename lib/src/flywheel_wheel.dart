import 'dart:math';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';

typedef FlywheelItemBuilder<T> = Widget Function(BuildContext context, T item, bool isSelected);

/// Opacity of a card at (already clamped) wheel distance [tc] from the centre:
/// a near-centre curve up to `fadeStart`, then a linear fade to 0 at the window
/// edge so cards never pop in or out when the window moves.
double _cardOpacity(double tc, int visibleSlots) {
  final edge = visibleSlots + 0.5;
  final abs = tc.abs();
  final fadeStart = max(0.0, min(1.5, visibleSlots - 0.5));
  final base = 1.0 - Curves.easeIn.transform((min(abs, fadeStart) / 1.5).clamp(0.0, 1.0)) * 0.85;
  final fade = abs <= fadeStart ? 1.0 : ((edge - abs) / (edge - fadeStart)).clamp(0.0, 1.0);
  return base * fade;
}

/// Where one card sits on the wheel, shared by paint and hit-testing so a tap
/// lands on exactly what is drawn.
///
/// [width] is the wheel's own width (cards are centred horizontally in it).
class WheelGeometry {
  const WheelGeometry({
    required this.width,
    required this.cardWidth,
    required this.cardHeight,
    required this.angularStep,
    required this.radius,
    required this.visibleSlots,
  });

  final double width;
  final double cardWidth;
  final double cardHeight;
  final double angularStep;
  final double radius;
  final int visibleSlots;

  double get _edge => visibleSlots + 0.5;

  /// Opacity of the card at wheel distance [t] (in pages) from the centre.
  double opacityAt(double t) => _cardOpacity(t.clamp(-_edge, _edge), visibleSlots);

  /// Maps card-local coordinates to wheel coordinates for the card at wheel
  /// distance [t]: translate onto the arc, then rotate about the card centre.
  Matrix4 transformAt(double t) {
    final theta = t.clamp(-_edge, _edge) * angularStep;
    final left = (width - cardWidth) / 2;
    return Matrix4.translationValues(left + radius * sin(theta), radius * (1.0 - cos(theta)), 0)
      ..translateByDouble(cardWidth / 2, cardHeight / 2, 0, 1)
      ..rotateZ(theta)
      ..translateByDouble(-cardWidth / 2, -cardHeight / 2, 0, 1);
  }

  /// Whether [point] (wheel coordinates) falls on the card at distance [t].
  bool contains(Offset point, double t) {
    final inverse = Matrix4.tryInvert(transformAt(t));
    if (inverse == null) return false;
    final local = MatrixUtils.transformPoint(inverse, point);
    return local.dx >= 0 && local.dx <= cardWidth && local.dy >= 0 && local.dy <= cardHeight;
  }

  /// The raw page of the frontmost visible card under [point], or null.
  ///
  /// Walks [rawPages] nearest-the-centre first (the reverse of paint order)
  /// and skips cards that are fully transparent, as paint does.
  int? hitTest(Offset point, double page, Iterable<int> rawPages) {
    final candidates = rawPages.toList()
      ..sort((a, b) => (a - page).abs().compareTo((b - page).abs()));
    for (final raw in candidates) {
      final t = raw - page;
      if (opacityAt(t) <= 0) continue;
      if (contains(point, t)) return raw;
    }
    return null;
  }
}

/// Renders a window of cards arranged on the rim of a circle whose center sits
/// below the carousel.
///
/// The card widgets are built only when [centerPage] or [selectedIndex]
/// changes. Every frame in between only repaints: a [Flow] listens to
/// [controller] and re-composites each card's cached layer with a new
/// transform/opacity, painting the farthest cards first so the center card
/// always sits on top.
class FlywheelWheel<T> extends StatelessWidget {
  const FlywheelWheel({
    super.key,
    required this.controller,
    required this.fallbackPage,
    required this.centerPage,
    required this.items,
    required this.selectedIndex,
    required this.itemBuilder,
    required this.cardWidth,
    required this.cardHeight,
    required this.angularStep,
    required this.radius,
    required this.visibleSlots,
    required this.loop,
  });

  /// Drives the per-frame repaint; its `page` positions the cards.
  final PageController controller;

  /// The page to use while [controller] has no scroll position yet.
  final double fallbackPage;

  /// `page.round()` — the center of the built window.
  final int centerPage;
  final List<T> items;
  final int selectedIndex;
  final FlywheelItemBuilder<T> itemBuilder;
  final double cardWidth;
  final double cardHeight;
  final double angularStep;
  final double radius;
  final int visibleSlots;
  final bool loop;

  @override
  Widget build(BuildContext context) {
    final count = items.length;

    final rawIndices = <int>[];
    final children = <Widget>[];
    for (int o = -visibleSlots; o <= visibleSlots; o++) {
      final rawIndex = centerPage + o;
      final int index;
      if (loop) {
        index = ((rawIndex % count) + count) % count;
      } else {
        if (rawIndex < 0 || rawIndex >= count) continue;
        index = rawIndex;
      }
      rawIndices.add(rawIndex);
      children.add(
        RepaintBoundary(
          key: ValueKey<int>(rawIndex),
          child: SizedBox(
            width: cardWidth,
            height: cardHeight,
            // Only the centre card is announced; the rest are decoration.
            child: ExcludeSemantics(
              excluding: rawIndex != centerPage,
              child: itemBuilder(context, items[index], index == selectedIndex),
            ),
          ),
        ),
      );
    }

    return Flow.unwrapped(
      clipBehavior: Clip.none,
      delegate: _WheelFlowDelegate(
        controller: controller,
        fallbackPage: fallbackPage,
        rawIndices: rawIndices,
        cardWidth: cardWidth,
        cardHeight: cardHeight,
        angularStep: angularStep,
        radius: radius,
        visibleSlots: visibleSlots,
      ),
      children: children,
    );
  }
}

class _WheelFlowDelegate extends FlowDelegate {
  _WheelFlowDelegate({
    required this.controller,
    required this.fallbackPage,
    required this.rawIndices,
    required this.cardWidth,
    required this.cardHeight,
    required this.angularStep,
    required this.radius,
    required this.visibleSlots,
  }) : super(repaint: controller);

  final PageController controller;
  final double fallbackPage;
  final List<int> rawIndices;
  final double cardWidth;
  final double cardHeight;
  final double angularStep;
  final double radius;
  final int visibleSlots;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      BoxConstraints.tight(Size(cardWidth, cardHeight));

  @override
  void paintChildren(FlowPaintingContext context) {
    final page = controller.hasClients ? (controller.page ?? fallbackPage) : fallbackPage;
    final geometry = WheelGeometry(
      width: context.size.width,
      cardWidth: cardWidth,
      cardHeight: cardHeight,
      angularStep: angularStep,
      radius: radius,
      visibleSlots: visibleSlots,
    );

    final order = List<int>.generate(rawIndices.length, (i) => i);
    final ts = [for (final raw in rawIndices) raw - page];
    // Farthest first so the center card is painted last (on top).
    order.sort((a, b) => ts[b].abs().compareTo(ts[a].abs()));

    for (final i in order) {
      final opacity = geometry.opacityAt(ts[i]);
      if (opacity <= 0) continue;
      context.paintChild(i, transform: geometry.transformAt(ts[i]), opacity: opacity);
    }
  }

  @override
  bool shouldRelayout(_WheelFlowDelegate old) =>
      old.cardWidth != cardWidth || old.cardHeight != cardHeight;

  @override
  bool shouldRepaint(_WheelFlowDelegate old) =>
      old.controller != controller ||
      old.fallbackPage != fallbackPage ||
      old.cardWidth != cardWidth ||
      old.cardHeight != cardHeight ||
      old.angularStep != angularStep ||
      old.radius != radius ||
      old.visibleSlots != visibleSlots ||
      !listEquals(old.rawIndices, rawIndices);
}
