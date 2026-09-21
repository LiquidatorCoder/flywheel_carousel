# flywheel_carousel — agent working rules

Discovered from this repository on 2026-09-21. Everything here is observed, not assumed:
if a rule below is not backed by a file in this repo, it does not belong here.

## What this repo is

A **published Dart/Flutter widget package** (`flywheel_carousel`, version `0.1.0` in
`pubspec.yaml`): a free-spinning, arc-shaped carousel whose cards ride the rim of a large
invisible wheel, coasting under friction and snapping to the nearest card. Plus a demo app
under `example/`.

- Library source is small and flat — four implementation files, 422 lines total:
  - `lib/flywheel_carousel.dart` — the public export barrel. It exports exactly four
    symbols with explicit `show` clauses: `FlywheelCarousel`, `FlywheelItemCard`,
    `FreewheelPhysics`, `FlywheelItemBuilder`. Nothing else in `lib/src/` is reachable
    from outside the package.
  - `lib/src/flywheel_carousel.dart` — `FlywheelCarousel<T>`, a `StatefulWidget` wrapping
    a `PageController`. Two stacked layers: an invisible `PageView.builder` that owns the
    gesture/scroll, and an `IgnorePointer`ed visual layer driven by an `AnimatedBuilder`
    on that same controller.
  - `lib/src/flywheel_wheel.dart` — `FlywheelWheel<T>` and the private `_ArcCard`: the
    trigonometry that places a window of cards on the arc, plus the z-order sort that
    keeps the center card on top.
  - `lib/src/flywheel_physics.dart` — `FreewheelPhysics`, a `ScrollPhysics` subclass
    overriding `createBallisticSimulation` (friction coast + spring settle).
  - `lib/src/flywheel_item_card.dart` — `FlywheelItemCard`, an optional opinionated
    `leading + title + subtitle + indicator` layout. The only file that imports
    `package:flutter/material.dart`; everything else imports `package:flutter/widgets.dart`.
- **Zero third-party dependencies.** `pubspec.yaml` declares only the Flutter SDK, plus
  `flutter_test` and `flutter_lints ^6.0.0` as dev dependencies. There is no network,
  auth, storage, crypto, platform-channel or codegen surface anywhere in this package.
- SDK constraints (`pubspec.yaml`): Dart `^3.11.1`, Flutter `>=3.0.0`.
- Demo app: `example/` — its own pubspec (`publish_to: "none"`), depends on the package by
  `path: ../`, and includes `package:flutter_lints/flutter.yaml` directly rather than the
  root `analysis_options.yaml`. It ships **only an `ios/` runner** (no `android/`, `macos/`,
  `web/` or `linux/`), so `flutter run` from `example/` targets iOS or a desktop/web device
  Flutter can synthesize — nothing in this repo builds an Android artifact.
- Lints: the root `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`
  and turns on seven additional rules by hand (`prefer_const_constructors`,
  `prefer_const_literals_to_create_immutables`, `prefer_const_declarations`,
  `avoid_unnecessary_containers`, `sized_box_for_whitespace`,
  `use_key_in_widget_constructors`). `example/analysis_options.yaml` does **not** include
  the root file, so the demo app is analysed against plain `flutter_lints` only.
- `demo/` holds six tracked media files (three `.gif`, three `.mov`, ~6.7 MB) that
  `README.md` embeds by relative path. They are **not** referenced from a `screenshots:`
  block in `pubspec.yaml` — this package declares none — so `flutter pub publish` does not
  validate them, but they are inside the published archive and count against its size.

**The package is published to pub.dev.** `lib/`'s public surface, `pubspec.yaml`'s
version/metadata, `CHANGELOG.md` and `LICENSE` are therefore a release path, not ordinary
source — see `.claude/docs/routing.yaml`.

## Commands (the real ones)

There is **no CI workflow, no Makefile, and no script runner** in this repo — no
`.github/`, no `Makefile`, no `package.json`. These are the actual toolchain commands,
each confirmed to run here at bootstrap (Flutter 3.44.3 stable, Dart 3.12.2):

| Purpose | Command |
|---|---|
| Static analysis | `flutter analyze` |
| Format check | `dart format --output=none --set-exit-if-changed .` |
| Format (write) | `dart format .` |
| Tests | `flutter test` |
| Demo app analysis | `flutter analyze` from `example/` |
| Release dry-run | `flutter pub publish --dry-run` |
| Dependencies | `flutter pub get` |

Run them through `tool/harness/verify <tier>` rather than one at a time — that is what the
completion gate reads.

## The generated-files trap (read this before running anything)

This repo **tracks files that its own toolchain rewrites**:

- `.dart_tool/package_config.json`, `.dart_tool/package_graph.json`, `.dart_tool/version`
- `pubspec.lock` and `example/pubspec.lock`

The root `.gitignore` contained only `build/*` at bootstrap, so `.dart_tool/` was committed
in the initial commit. The consequence is concrete and was observed during bootstrap:
**running `flutter analyze` (or anything else that implies `flutter pub get`) dirties the
working tree** with five modified tracked files, none of them source.

- That churn is *not* a change you made. Do not commit it as part of a feature, and do not
  "fix" it by reformatting or re-resolving on purpose.
- `tool/harness/lib/classify.mjs` excludes these paths from every workspace fingerprint
  (`FINGERPRINT_EXCLUDE_PREFIXES`), so the completion gate does not read pub-resolution
  noise as a workspace change.
- `git checkout -- .dart_tool pubspec.lock example/pubspec.lock` restores them.
- Removing `.dart_tool/` from tracking would be a reasonable cleanup, but it is a
  repository decision, not a harness one. The bootstrap deliberately did not make it.

## Test layout

`test/` holds **one flutter_test widget-test file, 2 tests, both passing at bootstrap**:

| File | Pins |
|---|---|
| `flywheel_carousel_test.dart` | that `initialIndex` renders as selected while its neighbours render as not-selected and `onIndexChanged` stays silent on first build; and that `loop: false` does not render off-end slots |

There are **no golden tests** — nothing calls `matchesGoldenFile`, so there is no golden
directory to update and no platform pinning to worry about.

Be honest about what this suite does and does not cover. It exercises the *builder
contract* and the *slot windowing*. It does **not** exercise:

- `FreewheelPhysics.createBallisticSimulation` — no test flings the carousel, so friction
  coast, the settle spring, and the `pageWidth` maths are entirely uncovered.
- `onTick` — nothing drives a page crossing.
- The arc geometry in `_ArcCard` (`sin`/`cos` placement, rotation, the opacity falloff) —
  no test asserts a transform or an opacity.
- The `_loopMultiplier * _count` virtual-page scheme, including its behaviour at the ends
  of the 5000-turn virtual range.

A green `flutter test` therefore does **not** mean a physics or geometry change is safe.
If you change `flywheel_physics.dart` or `flywheel_wheel.dart`'s maths, say so in the
task's `plan.md` under Verification and add a test rather than letting a green run imply
coverage that does not exist.

## Architecture conventions

Observable, and deliberately short — this is a small widget package, not a layered app:

- `lib/flywheel_carousel.dart` exports the public API with explicit `show` clauses.
  Anything not named there is internal; adding, removing or renaming a `show` entry is a
  public-API change.
- `lib/src/` holds the implementation. Private types there are `_`-prefixed (`_Slot`,
  `_ArcCard`, `_FlywheelCarouselState`) and are genuinely private.
- Only `flywheel_item_card.dart` imports `package:flutter/material.dart`. The carousel,
  the wheel and the physics import `package:flutter/widgets.dart` and take their colours
  and text styles from the caller's `itemBuilder`. **Keep it that way** — "theme-agnostic"
  is a documented selling point in `README.md`, and pulling Material into the core would
  quietly break it.
- The gesture layer and the visual layer are separate on purpose: the `PageView` is
  invisible (`SizedBox.shrink` items) and the cards are painted by a second, pointer-inert
  layer reading the same `PageController`. Do not merge them.
- `example/` must never be imported by `lib/`. The dependency runs one way only.

There is no state-management, DI, routing or persistence convention in this repo — do not
introduce one as a side effect of another change.

## Rules for agents

- Never edit `example/` to make a `lib/` change look like it works; fix `lib/`.
- A change to `lib/flywheel_carousel.dart`'s `show` lists, to `FlywheelCarousel`'s or
  `FlywheelItemCard`'s constructor parameters or their **default values**, to
  `FlywheelItemBuilder`'s signature, to `FreewheelPhysics`'s constructor, or to
  `pubspec.yaml`'s `version` is a **release-path** change: full tier, and `CHANGELOG.md`
  gets an entry in the same change.
- The tunable defaults (`height: 230`, `cardHeight: 200`, `viewportFraction: 0.65`,
  `angularStep: 0.42`, `wheelRadius: 320`, `visibleSlots: 2`, `dragCoefficient: 0.35`,
  `loop: true`) are documented in `README.md`'s API table **and** in `CHANGELOG.md`.
  Changing one silently changes every consumer's visuals on upgrade, and leaves the README
  wrong. Change the code, the table and the changelog together.
- The three `assert`s in `FlywheelCarousel`'s constructor are the package's only input
  validation. Do not remove one without replacing the guarantee.
- `demo/*.gif` and `demo/*.mov` are README assets inside the published archive; do not
  regenerate or rename them unless asked.
- `.dart_tool/`, `pubspec.lock` and `example/pubspec.lock` are tracked-but-generated — see
  the trap section above. They are never part of a deliberate change set.

## Known baseline (2026-09-21, at harness bootstrap)

Measured on the pre-existing tree, before any harness file was written:

| Check | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed .` | **fails** — 6 of 7 Dart files reformat (`example/lib/main.dart`, all four `lib/src/*.dart`, `test/flywheel_carousel_test.dart`) |
| `flutter analyze` | clean — "No issues found!" |
| `flutter test` | 2/2 green |

The format failure is **pre-existing repository state and was deliberately left
untouched** by the bootstrap: reformatting six files would have buried the harness commit
in unrelated churn. It means a `fast` or `normal` run reports `failed` on an otherwise
untouched checkout. See `docs/agents/verification.md` for how to read that, and for the
one-line command that clears it when someone decides to.
