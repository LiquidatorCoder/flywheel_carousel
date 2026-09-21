// flywheel_carousel's own file classifier: changed files -> required verification tier.
//
// Repo-specific by design. The generic harness runtime (~/.claude/harness/runtime/lib)
// deliberately ships no classifier, because "what does this change risk" is a question
// only a specific repo can answer. This one answers it for a published, dependency-free
// Flutter widget package whose test suite covers the builder contract but none of the
// physics or arc geometry.
//
// LOCKSTEP: `.claude/docs/routing.yaml` is the human-readable statement of this same
// policy, and `RULES` below is its executable form. Node has no built-in YAML parser and
// this repo has no YAML dependency (it is a Dart package with zero dependencies), so the
// policy is not parsed from the YAML at runtime. Change both files together. Both are
// listed in POLICY_FILES, so editing either one changes the verification policy
// fingerprint and invalidates every existing verify.json — which is what makes drift loud
// instead of silent.

export const TIERS = ["fast", "normal", "full"];
export const TIER_RANK = { fast: 0, normal: 1, full: 2 };

// Files whose content defines what verification means here. Hashed into every
// verify.json's verification_policy_fingerprint.
export const POLICY_FILES = [
  "tool/harness/verify",
  "tool/harness/lib/classify.mjs",
  "tool/harness/lib/reviewpolicy.mjs",
  ".claude/docs/routing.yaml",
  "analysis_options.yaml",
];

// Never part of a workspace fingerprint: task bookkeeping, managed worktrees, and this
// repo's generated-but-TRACKED pub artifacts.
//
// The last group is unusual and deserves the note. flywheel_carousel's .gitignore is a
// single line (`build/*`), so `.dart_tool/` and both `pubspec.lock` files were committed
// in the initial commit. Every `flutter pub get` — which `flutter analyze` runs
// implicitly — rewrites them, so a plain verify run dirties five tracked files that
// nobody edited. Excluding them here keeps the completion gate from reading pub
// resolution noise as a workspace change. See AGENTS.md's generated-files trap.
export const FINGERPRINT_EXCLUDE_PREFIXES = [
  ".claude/tasks/",
  ".claude/worktrees/",
  ".dart_tool/",
  "build/",
  "example/.dart_tool/",
  "example/build/",
  "pubspec.lock",
  "example/pubspec.lock",
  "coverage/",
];

// Shared resources a worker may serialize on. This repo has no codegen step (no
// build_runner — in fact no third-party dependency of any kind), no native platform
// directory of its own, and no device/simulator pool — so none of those appear here.
export const LOCK_RESOURCES = ["dependency-resolution", "repo-format", "release"];

// First match wins, in order. Mirrors routing.yaml's `classification:` block.
export const RULES = [
  { match: "pubspec.yaml", tier: "full", why: "SDK/Flutter constraints, the dependency list, the published version and the pub.dev metadata all live here" },
  { match: "CHANGELOG.md", tier: "full", why: "part of the pub.dev release artifact, changed together with the version" },
  { match: "LICENSE", tier: "full", why: "distribution terms of the published archive; pub validates its presence" },
  { match: "lib/flywheel_carousel.dart", tier: "full", why: "the public export barrel — four explicit `show` clauses are the entire public surface, with no wildcard export to soften a rename" },
  { match: "lib/src/flywheel_physics.dart", tier: "full", why: "FreewheelPhysics is exported and subclassable, and nothing in the test suite flings the carousel — the suite cannot catch a regression here" },
  { match: "lib/**", tier: "normal", why: "package implementation consumed by real apps; the widget-test suite is what exercises it" },
  { match: "test/**", tier: "normal", why: "a change to a test changes what passing means — the suite must actually run" },
  { match: "analysis_options.yaml", tier: "normal", why: "flutter_lints plus seven hand-enabled rules; a change here re-scopes every analyze run on the package side" },
  { match: "tool/harness/**", tier: "normal", why: "verifier and gate logic" },
  { match: ".claude/docs/routing.yaml", tier: "normal", why: "verification policy" },
  { match: "AGENTS.md", tier: "normal", why: "the rules agents work from" },
  { match: "demo/**", tier: "fast", why: "README media; inside the published archive but not validated by pub (pubspec.yaml declares no `screenshots:` block)" },
  { match: "example/**", tier: "fast", why: "demo app (publish_to: none), ios/ runner included; not depended on by lib/, and analysed on its own in the normal tier" },
  { match: "README.md", tier: "fast", why: "documentation — but it carries the API/defaults table that must stay in step with the constructor" },
  { match: "docs/**", tier: "fast", why: "agent-facing documentation; not shipped in the archive" },
  { match: ".claude/tasks/**", tier: "fast", why: "task bookkeeping" },
  { match: ".dart_tool/**", tier: "fast", why: "tracked by accident and rewritten by every `flutter pub get`; excluded from fingerprints" },
  { match: "pubspec.lock", tier: "fast", why: "generated by pub resolution, tracked here; same trap as .dart_tool/" },
  { match: "*", tier: "fast", why: "default floor — nothing here is verification-exempt" },
];

const DOUBLESTAR = "__HARNESS_DOUBLESTAR__";

/**
 * Minimal glob matcher for the forms RULES actually uses: an exact path, a `dir/**`
 * prefix, a single `*` segment wildcard, and the bare `*` catch-all. Deliberately not a
 * general glob implementation — a rule form not listed above is a policy authoring
 * mistake, and a silently-mismatching clever matcher would be worse than an obvious one.
 */
export function matchesPattern(path, pattern) {
  if (pattern === "*") return true;
  if (!pattern.includes("*")) return path === pattern;
  if (pattern.endsWith("/**")) {
    const prefix = pattern.slice(0, -2); // keep the trailing slash
    return path.startsWith(prefix);
  }
  const escaped = pattern.replace(/[.+^${}()|[\]\\]/g, "\\$&");
  const body = escaped.split("**").join(DOUBLESTAR).split("*").join("[^/]*").split(DOUBLESTAR).join(".*");
  return new RegExp(`^${body}$`).test(path);
}

/** The tier one path demands, plus the rule that decided it. */
export function classifyFile(path) {
  for (const rule of RULES) {
    if (matchesPattern(path, rule.match)) return { tier: rule.tier, rule: rule.match, why: rule.why };
  }
  // Unreachable while the `*` catch-all is present. Fail closed rather than return
  // undefined if someone ever removes it.
  return { tier: "full", rule: "(no rule matched)", why: "fail closed: no classification rule matched" };
}

/**
 * The highest tier any changed file demands. An EMPTY change set returns "fast" — the
 * floor, not "full": a verify run with nothing changed has nothing to escalate for.
 * Returns { requiredTier, reasons: [{path, tier, rule, why}] } with reasons listing only
 * the files that drove the maximum.
 */
export function classifyChanges(changedFiles) {
  let requiredTier = "fast";
  const all = [];
  for (const path of changedFiles) {
    const c = classifyFile(path);
    all.push({ path, ...c });
    if (TIER_RANK[c.tier] > TIER_RANK[requiredTier]) requiredTier = c.tier;
  }
  return { requiredTier, reasons: all.filter((r) => r.tier === requiredTier) };
}
