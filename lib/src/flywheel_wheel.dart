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
            child: itemBuilder(context, items[index], index == selectedIndex),
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
    final edge = visibleSlots + 0.5;

    final order = List<int>.generate(rawIndices.length, (i) => i);
    final ts = [for (final raw in rawIndices) raw - page];
    // Farthest first so the center card is painted last (on top).
    order.sort((a, b) => ts[b].abs().compareTo(ts[a].abs()));

    // Cards are laid out at the origin; centre them horizontally at the top.
    final left = (context.size.width - cardWidth) / 2;
    for (final i in order) {
      final tc = ts[i].clamp(-edge, edge);
      final opacity = _cardOpacity(tc, visibleSlots);
      if (opacity <= 0) continue;
      final theta = tc * angularStep;
      final transform =
          Matrix4.translationValues(left + radius * sin(theta), radius * (1.0 - cos(theta)), 0)
            ..translateByDouble(cardWidth / 2, cardHeight / 2, 0, 1)
            ..rotateZ(theta)
            ..translateByDouble(-cardWidth / 2, -cardHeight / 2, 0, 1);
      context.paintChild(i, transform: transform, opacity: opacity);
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
