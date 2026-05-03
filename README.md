# flywheel_carousel

A free-spinning, arc-shaped carousel for Flutter. Cards ride the rim of a large invisible wheel — flicks coast under friction and snap to the nearest card. Builder-driven and theme-agnostic.

## Usage

```dart
import 'package:flywheel_carousel/flywheel_carousel.dart';

FlywheelCarousel<MyItem>(
  items: items,
  initialIndex: 0,
  onIndexChanged: (i) => setState(() => selected = items[i]),
  onTick: HapticFeedback.selectionClick,
  itemBuilder: (context, item, isSelected) => FlywheelItemCard(
    leading: Icon(item.icon, size: 32),
    title: item.title,
    subtitle: item.subtitle,
    selected: isSelected,
  ),
);
```

## API

`FlywheelCarousel<T>` parameters:

| Parameter | Default | Notes |
| --- | --- | --- |
| `items` | required | List of any type. |
| `itemBuilder` | required | `(context, item, isSelected) -> Widget`. |
| `initialIndex` | `0` | Starting item. |
| `onIndexChanged` | `null` | Fires when the closest-to-center item changes. |
| `onTick` | `null` | Fires once per integer page crossing — wire haptics here. |
| `height` | `230` | Total carousel height. |
| `cardHeight` | `200` | Each item's height. |
| `viewportFraction` | `0.65` | Card width as a fraction of the parent's width. |
| `angularStep` | `0.42` rad | ~24° between cards on the arc. |
| `wheelRadius` | `320` | Wheel radius in logical pixels. |
| `visibleSlots` | `2` | Half-window — cards rendered on each side of center. |
| `dragCoefficient` | `0.35` | Friction. Lower = longer coast. |
| `loop` | `true` | Infinite loop or clamped at edges. |

`FlywheelItemCard` is an opinionated layout (`leading + title + subtitle + indicator pill`) you can use or skip. For a totally custom shape, build your own widget inside `itemBuilder`.

`FreewheelPhysics` is exported for advanced consumers who want to wrap or tune the scroll behavior.
