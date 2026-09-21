// Builds the text packet handed to the independent reviewer, and the two fingerprints
// the completion gate compares it against.
//
// Repo-local on purpose: the generic runtime deliberately does not ship a packet builder
// (arch_wallet's carried a Dart-generated-file regex — see runtime/README.md's "Left
// out"). This one is Dart-aware in the only way that matters for flywheel_carousel.
//
// Determinism is the whole contract here: `buildPacket` must produce byte-identical
// output for an unchanged workspace, or every review goes stale on the next gate check.
// Nothing time-, path-, or environment-dependent may enter the packet text.

import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { join } from "node:path";

// Dart codegen output. flywheel_carousel has no build_runner today — it has no
// third-party dependency at all — so this matches nothing right now. It is here so that
// adding codegen later does not silently start feeding machine-written files to a
// reviewer.
const GENERATED_RE = /\.(g|freezed|config|gr|mocks)\.dart$/;

// Generated-but-tracked pub artifacts. Unlike the regex above, these DO match today: a
// `flutter pub get` rewrites all of them and they are committed in this repo (see
// AGENTS.md's generated-files trap). Feeding a reviewer a package_config.json diff wastes
// the whole budget on noise.
const GENERATED_PATH_RE = /^(\.dart_tool\/|example\/\.dart_tool\/)|(^|\/)pubspec\.lock$/;

function isGenerated(path) {
  return GENERATED_RE.test(path) || GENERATED_PATH_RE.test(path);
}

const MAX_DIFF_BYTES = 400 * 1024;

export function sha256Hex(s) {
  return createHash("sha256").update(s).digest("hex");
}

export function fingerprintOf(text) {
  return `sha256:${sha256Hex(text)}`;
}

function readOr(path, fallback) {
  try {
    return readFileSync(path, "utf8");
  } catch {
    return fallback;
  }
}

/**
 * The brief/plan content the review was produced against. Kept separate from the packet
 * fingerprint so the gate can tell "the code changed" from "the task's own definition of
 * done changed" — both invalidate a review, for different reasons.
 */
export function reviewInputContentFingerprint({ cwd, taskId }) {
  const dir = join(cwd, ".claude", "tasks", taskId);
  const brief = readOr(join(dir, "brief.md"), "<absent>");
  const plan = readOr(join(dir, "plan.md"), "<absent>");
  return fingerprintOf(`v1\nbrief\n${brief}\nplan\n${plan}\n`);
}

/**
 * The reviewer's input. Returns the packet text; `fingerprintOf(text)` is what lands in
 * review.json's `review_input_fingerprint`.
 */
export function buildPacket({ cwd, taskId, base, changedEntries, mode, tier }) {
  const dir = join(cwd, ".claude", "tasks", taskId);
  const reviewable = changedEntries.filter((e) => !isGenerated(e.path));
  const excluded = changedEntries.filter((e) => isGenerated(e.path));

  let diff = "";
  try {
    diff = execFileSync("git", ["diff", "-M", base, "--", ...reviewable.map((e) => e.path)], {
      cwd,
      encoding: "utf8",
      maxBuffer: 64 * 1024 * 1024,
      stdio: ["ignore", "pipe", "pipe"],
    });
  } catch (e) {
    diff = `<diff unavailable: ${String(e.message ?? e).split("\n")[0]}>`;
  }
  if (diff.length > MAX_DIFF_BYTES) {
    diff = `${diff.slice(0, MAX_DIFF_BYTES)}\n...[diff truncated at ${MAX_DIFF_BYTES} bytes]`;
  }

  const lines = [
    "# Independent review packet — flywheel_carousel",
    "",
    "flywheel_carousel is a published Flutter package (pub.dev): a free-spinning,",
    "arc-shaped carousel. It has zero third-party dependencies. Review the diff below for",
    "correctness and for anything that would break a downstream consumer:",
    "",
    "- changed `show` clauses in lib/flywheel_carousel.dart (four symbols are the entire",
    "  public surface — there is no wildcard export),",
    "- changed constructor parameters OR DEFAULT VALUES on FlywheelCarousel and",
    "  FlywheelItemCard: the defaults are documented in README.md's API table and in",
    "  CHANGELOG.md, and a changed default silently restyles every consumer on upgrade,",
    "- changed FlywheelItemBuilder or FreewheelPhysics signatures,",
    "- the ballistic/friction maths in flywheel_physics.dart and the arc trigonometry in",
    "  flywheel_wheel.dart: NOTHING in the test suite covers either, so a green verify run",
    "  is not evidence about them,",
    "- version/CHANGELOG/README consistency.",
    "",
    "Keep `package:flutter/material.dart` out of everything except",
    "flywheel_item_card.dart — theme-agnosticism is a documented property of this package.",
    "The `example/` app is a demo, not a product.",
    "",
    `task_id: ${taskId}`,
    `mode: ${mode}`,
    `tier: ${tier}`,
    `base: ${base}`,
    "",
    "## Brief",
    "",
    readOr(join(dir, "brief.md"), "<no brief.md>").trimEnd(),
    "",
    "## Plan",
    "",
    readOr(join(dir, "plan.md"), "<no plan.md>").trimEnd(),
    "",
    "## Changed files",
    "",
    ...reviewable.map((e) => `- ${e.status} ${e.path}${e.oldPath ? ` (from ${e.oldPath})` : ""}`),
  ];
  if (excluded.length > 0) {
    lines.push("", "## Excluded (generated)", "", ...excluded.map((e) => `- ${e.path}`));
  }
  lines.push("", "## Diff", "", "```diff", diff.trimEnd(), "```", "");
  return lines.join("\n");
}
