// flywheel_carousel's own review policy: changed files -> required independent-review mode.
//
// Repo-specific by design (the generic runtime ships no review policy — see
// ~/.claude/harness/runtime/README.md's "Left out" section).
//
// The judgement encoded here is narrow and was arrived at by reading this repo, not by
// importing another repo's categories. flywheel_carousel makes no network calls, handles
// no credentials, persists nothing, depends on no third-party package, and contains no
// platform code of its own — so none of the usual trust-boundary categories apply. It has
// exactly one way to affect anyone outside this checkout: **being published to pub.dev**
// and consumed as a widget API. That is what review gates.
//
// One judgement here is broader than a barrel-only policy would be, and it is deliberate:
// this package's *default parameter values* are part of its public contract. Thirteen
// tunables on FlywheelCarousel and twelve on FlywheelItemCard are documented in
// README.md's API table and in CHANGELOG.md. Changing one compiles fine everywhere and
// silently restyles every consumer's UI on upgrade — the exact failure a reviewer catches
// and a compiler does not.
//
// LOCKSTEP with `.claude/docs/routing.yaml`'s `review:` block — see the same note in
// classify.mjs.

import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { join } from "node:path";

import { matchesPattern } from "./classify.mjs";

export const REVIEW_MODES = ["none", "standard", "adversarial"];
export const MODE_RANK = { none: 0, standard: 1, adversarial: 2 };

// Files whose content defines what review means here. Hashed into a review.json's
// review_policy_fingerprint.
export const REVIEW_POLICY_FILES = ["tool/harness/lib/reviewpolicy.mjs", "tool/harness/review", ".claude/docs/routing.yaml"];

// The release path, and nothing else.
export const RELEASE_PATH_PATTERNS = [
  { match: "pubspec.yaml", mode: "standard", why: "version, SDK/Flutter constraints and publish metadata" },
  { match: "lib/flywheel_carousel.dart", mode: "standard", why: "the export barrel; four explicit `show` clauses are the whole public surface, so a changed export is a compile break downstream" },
  { match: "lib/src/flywheel_carousel.dart", mode: "standard", why: "FlywheelCarousel's thirteen constructor parameters and their defaults are the public contract documented in README.md's API table; a changed default restyles every consumer on upgrade" },
  { match: "lib/src/flywheel_physics.dart", mode: "standard", why: "FreewheelPhysics is exported for consumers to wrap or subclass, and its createBallisticSimulation override has no test coverage at all" },
  { match: "lib/src/flywheel_item_card.dart", mode: "standard", why: "FlywheelItemCard is an exported widget host apps construct directly; its twelve defaults are its layout contract" },
  { match: "LICENSE", mode: "standard", why: "distribution terms of a published artifact" },
];

export const DEFAULT_MODE = "none";

export function maxMode(a, b) {
  return MODE_RANK[a] >= MODE_RANK[b] ? a : b;
}

/** { mode, reasons:[{path, mode, why}] } — reasons lists only files at the max mode. */
export function requiredReviewMode(changedFiles) {
  let mode = DEFAULT_MODE;
  const hits = [];
  for (const path of changedFiles) {
    for (const rule of RELEASE_PATH_PATTERNS) {
      if (matchesPattern(path, rule.match)) {
        hits.push({ path, mode: rule.mode, why: rule.why });
        mode = maxMode(mode, rule.mode);
        break;
      }
    }
  }
  return { mode, reasons: hits.filter((h) => h.mode === mode) };
}

/** sha256 over REVIEW_POLICY_FILES' bytes. A missing file hashes as absent, not zero. */
export function reviewPolicyFingerprint({ cwd, policyFiles = REVIEW_POLICY_FILES }) {
  const h = createHash("sha256");
  const sep = Buffer.from([0]);
  for (const rel of [...policyFiles].sort()) {
    h.update(rel);
    h.update(sep);
    try {
      h.update(readFileSync(join(cwd, rel)));
    } catch {
      h.update("<absent>");
    }
    h.update(sep);
  }
  return `sha256:${h.digest("hex")}`;
}
