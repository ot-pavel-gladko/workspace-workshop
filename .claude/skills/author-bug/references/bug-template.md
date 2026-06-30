# Bug payload template

The contract for a tracker-ready Bug authored by `author-bug`. Bugs have no spec
file — this payload **is** the artefact. Keep all tracker-field text ASCII-only.

## Summary (tracker `summary` field)

`<component> — <one-sentence observable defect>`

- Describe the **symptom**, not the suspected cause.
- Open with the affected component name.
- Good: `Connector — SessionCreate retries do not honour the back-off cap`
- Bad:  `Race condition in retry logic` (cause, not symptom)

## Description (tracker `description` field)

Five sections, in order:

```
## Summary
<one paragraph: what was observed, why it matters>

## Steps to reproduce
1. <step>
2. <step>
3. <step>

## Expected behaviour
<what should happen — trace to the triggering ticket's AC, or a vendor/spec contract>

## Actual behaviour
<what happens now — error message, stack-trace excerpt, or log link>

## Acceptance Criteria
1. When <repro step>, the system shall <expected behaviour>.
2. A regression test covering <scenario> exists and runs in the default CI pipeline.
```

Optional sections when warranted:

```
## Environment
- Build / commit SHA: <sha>
- Environment: <dev | staging | prod>
- Test data: <ids>
- Observed at: <ISO 8601>

## Investigation notes
<clearly-marked suspicion only — never assertion. The fixing dev owns root cause.>
```

## Fields

- **labels** — apply the workspace's label policy (e.g. a `bug` label plus any
  tracking label). If no policy is defined, a single `bug` label is enough.
- **fixVersion** — the current active release; for a hotfix against a released
  version, keep the original.
- **priority** — `Highest` (outage / data loss) · `High` (blocks in-flight work)
  · `Medium` (degraded, has a workaround) · `Low` (cosmetic / docs).

## Issue links

- `Caused by` → the triggering Story/Epic that introduced or should have
  prevented the defect. If genuinely uncertain, use `Relates` and flag it.
- `Relates` → a separate regression-test Task, if the fix needs one.
- Do **not** set a `parent` field; the parent relationship is the link.

## Provenance comment (first comment after the ticket is created)

```
[ba] Filed during <dev | QA | staging-soak | prod-incident> on <date>.
Triggering ticket: <key> (parent Story/Epic). Reproduction confirmed in <env>.
Logs / trace: <link or "see Investigation notes">.
```

Use `[qa]` instead of `[ba]` when QA files the Bug.

## When NOT to file a Bug

- Defect in an unmerged PR → fix it in the PR review.
- Enhancement request → `author-story` or a refinement comment.
- Spec defect (behaviour matches the spec; the spec is wrong) → spec edit.
- Third-party-only defect with no contract violation on your side → workaround
  Story/Task.
- Question about expected behaviour → the open-questions list.
