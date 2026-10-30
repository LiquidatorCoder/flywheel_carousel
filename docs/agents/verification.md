# Verification — flywheel_carousel

`tool/harness/verify` is the only thing that decides whether this repo's code passes. An
agent saying "I verified it" is not evidence; a `verify.json` written by that command is.

```
tool/harness/verify <fast|normal|full> [--base <ref>] [--files a b ...]
                                       [--json-out <path>] [--quiet]
```

Exit 0 only when `result === "passed"`. Exit 1 for `failed` or `incomplete`. Exit 2 means
the verifier itself could not start (bad tier, missing runtime, not a git repo).

## The tiers, and the real commands behind them

Every command below exists in this repo's toolchain and was run against this tree at
bootstrap. There is no CI workflow, no `Makefile` and no script runner here — no
`.github/`, no `package.json` — so these come from the Dart/Flutter CLI directly.

| Tier | Checks | Roughly |
|---|---|---|
| `fast` | `format`, `analyze` | seconds — the default working loop |
| `normal` | `fast` + `test`, `example_analyze` | the suite and the demo app's own analysis |
| `full` | `normal` + `publish_dry_run` | the pub.dev release gate |

| Check | Command | Runs in |
|---|---|---|
| `format` | `dart format --output=none --set-exit-if-changed .` | repo root |
| `analyze` | `flutter analyze` | repo root |
| `test` | `flutter test` | repo root |
| `example_analyze` | `flutter analyze` | `example/` |
| `publish_dry_run` | `flutter pub publish --dry-run` | repo root |

Which tier a change *requires* is not a judgement call — `tool/harness/lib/classify.mjs`
computes it from the changed paths, and `.claude/docs/routing.yaml` states the same policy
in prose. Declaring `fast` on a change that touches `pubspec.yaml` does not make it a fast
change; the classifier's `required_tier` lands in the artifact and the completion gate
compares the two.

## passed / failed / incomplete — the distinction that matters

- **passed** — every check in the tier ran and exited zero.
- **failed** — a check ran and exited non-zero. The code (or the format, or the analysis)
  is wrong.
- **incomplete** — a check *could not run*: the `dart` or `flutter` CLI is not on PATH,
  `example/pubspec.yaml` is missing, `test/` holds no `*_test.dart`, or the command timed
  out (15 min). It is listed in `unsatisfied_required`.

`incomplete` is never a pass. It is also not a failure of the code — it is the verifier
saying "I do not know". The completion gate treats both the same way: not done.

There is no code path in `tool/harness/verify` that records `passed` for a command it did
not execute. Do not add one.

## What the artifact contains

`--json-out <path>` writes the `verify.json` the gate reads. Its fields, at minimum:

| Field | Meaning |
|---|---|
| `result` | `passed` / `failed` / `incomplete` |
| `completion_tier_satisfied` | `result === "passed"` |
| `unsatisfied_required` | `[{check, reason}]` — the checks that could not run |
| `required_tier` | what the classifier says these changed files demand |
| `tier` | what was actually run |
| `verification_policy_fingerprint` | sha256 over `policy_files` — changing policy invalidates old artifacts |
| `workspace_fingerprint` | sha256 over the changed files' content |
| `verified_at_commit` | HEAD at run time |
| `checks` | one entry per check: status, exit code, duration, output on failure |

Never hand-write one of these. `verify.json` is generated evidence; a hand-made one is a
forged test result, and `.claude/tasks/README.md` says the same about `review.json` and
`adjudication.json`.

## Two things specific to this repo

**1. `analyze` dirties the working tree.** `flutter analyze` runs `flutter pub get`
implicitly, and this repo *tracks* `.dart_tool/package_config.json`,
`.dart_tool/package_graph.json`, `.dart_tool/version`, `pubspec.lock` and
`example/pubspec.lock` (the root `.gitignore` is a single `build/*` line). So a verify run
on an untouched checkout leaves five modified tracked files behind. Those paths are in
`FINGERPRINT_EXCLUDE_PREFIXES`, so the gate does not read that churn as a workspace
change, and `tool/harness/lib/reviewpacket.mjs` keeps them out of a reviewer's diff.
`git checkout -- .dart_tool pubspec.lock example/pubspec.lock` cleans it up. See AGENTS.md.

**2. A green `test` proves less here than in most repos.** The suite is one file and two
widget tests. They cover the `itemBuilder` contract and non-loop slot windowing. They do
**not** touch `FreewheelPhysics.createBallisticSimulation`, `onTick`, the arc trigonometry
in `_ArcCard`, or the 5000-turn virtual-page scheme. A `normal` run that passes says
nothing about a physics or geometry change — which is exactly why
`lib/src/flywheel_physics.dart` is classified `full` tier and carries a `standard` review
requirement despite being one 66-line file.

## Known baseline (2026-09-21, at harness bootstrap)

Measured on the pre-existing tree, before any harness file was written:

| Check | Result |
|---|---|
| `format` | **fails** — 6 of 7 Dart files reformat |
| `analyze` | passes — "No issues found!" |
| `test` | passes — 2/2 |

The six files `dart format` wants to rewrite are `example/lib/main.dart`, all four
`lib/src/*.dart`, and `test/flywheel_carousel_test.dart`.

This means **`tool/harness/verify fast` reports `failed` on a clean checkout**, and will
keep doing so until someone reformats. That is recorded, not hidden: the bootstrap
deliberately did not run `dart format .`, because rewriting six source files to make a
harness install look green would have buried the harness commit in unrelated churn and
changed code nobody asked to change.

To clear it when you decide to — as its own commit, not folded into a feature:

```
dart format .
tool/harness/verify normal
```

Until then, read a `fast`/`normal` failure by looking at *which* check failed. If the only
failure is `format` and its output lists files you did not touch, that is this baseline,
not your change. If `analyze` or `test` fails, that is new and it is yours.

## Independent review

Optional here, and required only on the release path — see `review:` in
`.claude/docs/routing.yaml` and `tool/harness/lib/reviewpolicy.mjs`. Independent review is performed by the reviewer configured in the active global harness policy
(`~/.claude/harness/current/policies/global.md`); this repo only sets risk floors. If the reviewer is
unavailable, `tool/harness/review run` writes an `incomplete` review and exits non-zero. There is no
path from "review unavailable" to "review passed".
