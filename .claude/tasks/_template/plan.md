# Plan: <task-id>

## Change, file by file

| File | Change | Why |
|---|---|---|
| `lib/src/<file>.dart` | | |

## Public API impact

<Does `lib/flywheel_carousel.dart`'s four `show` clauses change? Does any constructor
parameter on `FlywheelCarousel` or `FlywheelItemCard` change — including a **default
value**? Does `FlywheelItemBuilder`'s or `FreewheelPhysics`'s signature change? If yes to
any: this is a release-path change — full tier, `CHANGELOG.md` gets an entry, and
`README.md`'s API/defaults table is updated in the same change.>

## Verification

<Which tier, and which checks in it actually exercise this change. The suite is ONE file
with two tests (`test/flywheel_carousel_test.dart`), covering the itemBuilder contract and
non-loop slot windowing — nothing else. If this change touches the friction/settle maths
in `flywheel_physics.dart`, the arc trigonometry or z-ordering in `flywheel_wheel.dart`,
`onTick`, or the virtual-page scheme, say so plainly here: a green run proves nothing
about those, and either add a test or state how you checked it by hand.>

## Risks

<What could break for a downstream consumer: a changed default that restyles their
carousel on upgrade; a card that stops rendering at the window edge; a flick that no
longer settles on an integer page; Material leaking into a file that is meant to stay on
package:flutter/widgets.dart.>
