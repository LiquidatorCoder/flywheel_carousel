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
      slots.add(_Slot<T>(t: rawIndex - page, item: items[index], index: index));
    }
    slots.sort((a, b) => b.t.abs().compareTo(a.t.abs()));

    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        for (final slot in slots)
          _ArcCard<T>(
            t: slot.t,
            item: slot.item,
            selected: slot.index == selectedIndex,
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            angularStep: angularStep,
            radius: radius,
            itemBuilder: itemBuilder,
          ),
      ],
    );
  }
}

class _Slot<T> {
  const _Slot({required this.t, required this.item, required this.index});
  final double t;
  final T item;
  final int index;
}

class _ArcCard<T> extends StatelessWidget {
  const _ArcCard({
    required this.t,
    required this.item,
    required this.selected,
    required this.cardWidth,
    required this.cardHeight,
    required this.angularStep,
    required this.radius,
    required this.itemBuilder,
  });

  final double t;
  final T item;
  final bool selected;
  final double cardWidth;
  final double cardHeight;
  final double angularStep;
  final double radius;
  final FlywheelItemBuilder<T> itemBuilder;

  @override
  Widget build(BuildContext context) {
    final tc = t.clamp(-2.5, 2.5);
    final abs = tc.abs();
    final theta = tc * angularStep;

    final arcX = radius * sin(theta);
    final arcY = radius * (1.0 - cos(theta));

    final opacity = 1.0 - Curves.easeIn.transform((abs / 1.5).clamp(0.0, 1.0)) * 0.85;

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
