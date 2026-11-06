# Changelog

## Unreleased

- Fixed: `FreewheelPhysics` no longer throws (debug) or leaves the wheel stuck between cards (release) on a gentle swipe.
- Fixed: slow flicks no longer crawl for seconds toward the next card; the wheel settles promptly.
- Fixed: in non-loop mode a hard fling no longer coasts far past the last or first card before springing back.
- Fixed: hard flings no longer leave a long, barely-moving tail; a 3000 px/s fling is idle in about 3 s instead of 6 s or more.
- Changed: snapping to a card is now a short fixed-duration ease (about 0.3 to 0.5 s) with no overshoot and no tail.
- Docs: `dragCoefficient` direction was documented backwards; higher means longer spin.
- Fixed: loop mode no longer floods debug builds with a sliver precision assertion at common phone widths.
- Fixed: stateful item widgets keep their `State` as the wheel turns (cards are keyed by page).
- Fixed: card width follows the carousel's own width instead of the screen width.
- Fixed: `visibleSlots` above 2 no longer stacks the outer cards on top of each other.
- Fixed: cards fade out fully at the edge of the window instead of popping in and out at 15% opacity.
- Fixed: `onTick` fires once per crossed page, also when several pages pass in one frame.
- Fixed: changing `items`, `loop` or `viewportFraction` after the first build keeps the current item and a valid selection.
- Performance: `itemBuilder` now runs once per page crossing instead of for every visible card on every frame (about 15× fewer calls during a fling); per-frame work is paint-only.

## 0.1.0

- Initial release.
- `FlywheelCarousel<T>` — arc-shaped, free-spinning carousel with friction-based coast and snap-to-nearest.
- `FlywheelItemCard` — opinionated `leading + title + subtitle + indicator` layout.
- `FreewheelPhysics` — exported for custom scroll tuning.
- Tunables: `wheelRadius`, `angularStep`, `viewportFraction`, `dragCoefficient`, `visibleSlots`, `loop`, plus `onIndexChanged` and `onTick` callbacks.
