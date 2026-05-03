<h1 align="center">Flywheel Carousel 🎡</h1>

<p align="center">A free-spinning, arc-shaped carousel for Flutter. 🛞</p>

<p align="center">
Cards ride the rim of a large invisible wheel — flicks coast under friction and snap to the nearest card. Builder-driven and theme-agnostic, so you bring the cards and the wheel handles the motion.
</p>

<p align="center">
  <img src="https://img.shields.io/pub/v/flywheel_carousel.svg?label=pub&color=blue" alt="pub" />
  <img src="https://img.shields.io/badge/Platform-Flutter-blue?logo=flutter" alt="Platform" />
  <img src="https://img.shields.io/badge/license-BSD--3-orange" alt="license" />
</p>

---

```yaml
dependencies:
  flywheel_carousel: ^0.1.0
```

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

## 📦 What's inside

- 🧩 **Widgets:** `FlywheelCarousel<T>`, `FlywheelItemCard`.
- ⚙️ **Physics:** `FreewheelPhysics` — exported for advanced consumers who want to wrap or tune the scroll behavior.
- 🎛️ **Tunables:** wheel radius, angular step, viewport fraction, drag coefficient, visible slots, loop vs. clamp.
- 🪶 **Theme-agnostic:** no opinions on colors or fonts — `itemBuilder` owns the look.

## 🎚️ API

`FlywheelCarousel<T>` parameters:

| Parameter          | Default    | Notes                                                     |
| ------------------ | ---------- | --------------------------------------------------------- |
| `items`            | required   | List of any type.                                         |
| `itemBuilder`      | required   | `(context, item, isSelected) -> Widget`.                  |
| `initialIndex`     | `0`        | Starting item.                                            |
| `onIndexChanged`   | `null`     | Fires when the closest-to-center item changes.            |
| `onTick`           | `null`     | Fires once per integer page crossing — wire haptics here. |
| `height`           | `230`      | Total carousel height.                                    |
| `cardHeight`       | `200`      | Each item's height.                                       |
| `viewportFraction` | `0.65`     | Card width as a fraction of the parent's width.           |
| `angularStep`      | `0.42` rad | ~24° between cards on the arc.                            |
| `wheelRadius`      | `320`      | Wheel radius in logical pixels.                           |
| `visibleSlots`     | `2`        | Half-window — cards rendered on each side of center.      |
| `dragCoefficient`  | `0.35`     | Friction. Lower = longer coast.                           |
| `loop`             | `true`     | Infinite loop or clamped at edges.                        |

`FlywheelItemCard` is an opinionated layout (`leading + title + subtitle + indicator pill`) you can use or skip. For a totally custom shape, build your own widget inside `itemBuilder`.

## 🚀 Example

A runnable demo app lives in [`example/`](example/):

```bash
cd example
flutter run
```

## 📄 License

BSD 3-Clause. See [LICENSE](LICENSE).
