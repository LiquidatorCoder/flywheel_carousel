import 'dart:math';

import 'package:flutter/widgets.dart';

typedef FlywheelItemBuilder<T> = Widget Function(BuildContext context, T item, bool isSelected);

/// Renders a window of cards arranged on the rim of a circle whose center sits
/// below the carousel. The center card always sits on top of its neighbours
/// thanks to the z-order sort below.
class FlywheelWheel<T> extends StatelessWidget {
  const FlywheelWheel({
    super.key,
    required this.page,
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

  final double page;
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
    final centerInt = page.round();
    final count = items.length;

    final slots = <_Slot<T>>[];
    for (int o = -visibleSlots; o <= visibleSlots; o++) {
      final rawIndex = centerInt + o;
      final int index;
      if (loop) {
        index = ((rawIndex % count) + count) % count;
      } else {
        if (rawIndex < 0 || rawIndex >= count) continue;
        index = rawIndex;
      }
      slots.add(_Slot<T>(t: rawIndex - page, item: items[index], index: index, rawIndex: rawIndex));
    }
    slots.sort((a, b) => b.t.abs().compareTo(a.t.abs()));

    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        for (final slot in slots)
          _ArcCard<T>(
            key: ValueKey<int>(slot.rawIndex),
            t: slot.t,
            item: slot.item,
            selected: slot.index == selectedIndex,
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            angularStep: angularStep,
            radius: radius,
            visibleSlots: visibleSlots,
            itemBuilder: itemBuilder,
          ),
      ],
    );
  }
}

class _Slot<T> {
  const _Slot({required this.t, required this.item, required this.index, required this.rawIndex});
  final double t;
  final T item;
  final int index;
  final int rawIndex;
}

class _ArcCard<T> extends StatelessWidget {
  const _ArcCard({
    super.key,
    required this.t,
    required this.item,
    required this.selected,
    required this.cardWidth,
    required this.cardHeight,
    required this.angularStep,
    required this.radius,
    required this.visibleSlots,
    required this.itemBuilder,
  });

  final double t;
  final T item;
  final bool selected;
  final double cardWidth;
  final double cardHeight;
  final double angularStep;
  final double radius;
  final int visibleSlots;
  final FlywheelItemBuilder<T> itemBuilder;

  @override
  Widget build(BuildContext context) {
    // The window edge: a card this far from the centre is fully faded out.
    final edge = visibleSlots + 0.5;
    final tc = t.clamp(-edge, edge);
    final abs = tc.abs();
    final theta = tc * angularStep;

    final arcX = radius * sin(theta);
    final arcY = radius * (1.0 - cos(theta));

    // Near-centre curve up to `fadeStart`, then a linear fade to 0 at the edge
    // so cards never pop in or out when the window moves.
    final fadeStart = max(0.0, min(1.5, visibleSlots - 0.5));
    final base = 1.0 - Curves.easeIn.transform((min(abs, fadeStart) / 1.5).clamp(0.0, 1.0)) * 0.85;
    final fade = abs <= fadeStart ? 1.0 : ((edge - abs) / (edge - fadeStart)).clamp(0.0, 1.0);
    final opacity = base * fade;
    if (opacity <= 0) return const SizedBox.shrink();

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(arcX, arcY),
        child: Transform.rotate(
          angle: theta,
          child: SizedBox(
            width: cardWidth,
            height: cardHeight,
            child: itemBuilder(context, item, selected),
          ),
        ),
      ),
    );
  }
}
