# Brief: <task-id>

## Asked for

<What the user actually requested, in their framing. Not your restatement of it.>

## Done means

<Observable conditions. Each one must be checkable by someone who was not in the
conversation — a command that exits zero, a named widget test that passes, a behaviour
visible in the example app. "Feels right" and "works correctly" are not conditions. If
the change is to the physics or the arc geometry, note that no existing test covers those
and say how you will check it instead.>

- [ ]
- [ ]

## Out of scope

<Things deliberately not being changed, so a later reader knows they were considered.>

## Tier

<fast | normal | full — and why. Cross-check against .claude/docs/routing.yaml; the
classifier's opinion of the changed files overrides a too-low declaration anyway.>

## Review

<none | standard | adversarial — and why. `none` is correct for a change confined to
example/, demo/, README.md or docs/. Anything touching pubspec.yaml,
lib/flywheel_carousel.dart's `show` clauses, either exported widget's constructor
parameters or defaults, lib/src/flywheel_physics.dart, or LICENSE is not.>
