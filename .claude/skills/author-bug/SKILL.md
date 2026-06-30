---
name: author-bug
description: |
  Draft a Bug ticket payload from a defect report — no spec file backing,
  straight to the tracker. Produces the Summary, Description (5 sections per
  the bug template), labels, fix-version, priority, the "Caused by" link to the
  triggering ticket, and a provenance comment. Validates the inbound is actually
  a Bug (not an enhancement, not a third-party-only issue, not a draft-PR defect).
  Triggers: "file a bug for this defect", "draft Bug ticket", "QA found a defect,
  capture it", "open Bug for this prod incident", "log this regression as a Bug".
license: Proprietary - DataArt Core IP.
metadata:
  category: requirements-management
  level: "200"
  author: dataart-aila
  version: "1.0.0"
  last_updated: "2026-06-02"
  tags: [bug-authoring, defect-triage, tracker, business-analysis, requirements-management]
---

# Author Bug v1.0.0

Drafts a tracker-ready Bug payload from a defect report. Unlike Story authoring,
Bugs have **no spec file backing** — the tracker ticket is the artefact and
`references/bug-template.md` is the contract.

## When to invoke

- **QA found a defect** during Story testing — observed behaviour contradicts an
  AC, the build was supposed to ship it, and the divergence reproduces.
- **Prod incident** in shipped code that the spec intended to prevent.
- **Staging-soak regression** — a working flow broke after a recent merge.
- **Internal discovery** — a dev/agent found a defect outside their current
  Story and policy says "file it, don't fix it sideways".

**Do not invoke** for:

- A defect in an **unmerged PR** — fix it in the PR review.
- An **enhancement request** disguised as a Bug — file a Story via
  `author-story` or a refinement comment on the parent Story.
- A **spec defect** (behaviour matches the spec; the spec is wrong) — file a
  spec edit + refinement comment.
- A **third-party-only defect** with no contract violation on your side — file a
  workaround Story/Task, not a Bug against your component.
- A **question** about expected behaviour — log to the open-questions list.

This skill **re-confirms** classification at Step 1 (mis-classification is the
most common waste) but does not auto-route a confirmed non-Bug — it surfaces the
routing to the caller.

## Inputs

- **Defect observation** — what was observed, where, when. If any of the three
  is missing, stop and surface the gap.
- **Bug template** — `references/bug-template.md` (loaded by this skill).
- **Steps to reproduce** — provided by the operator/QA/dev. Intermittent repros
  still include the triggering steps plus an intermittency note.
- **Expected vs Actual** — both required. Expected traces to the triggering
  ticket's AC, or to a vendor/spec contract.
- **Environment context** — build/commit SHA, environment, test-data ids, time
  observed (ISO 8601).
- **Triggering ticket** — the Story/Epic that introduced or should have
  prevented the defect, if discoverable.
- **Affected component** — one of the workspace's components; the Summary opens
  with it.

## Output

- A tracker-ready Bug **payload** (drafted, not yet posted): summary
  (`<component> — <one-sentence observable defect>`), description (5 sections per
  the template), labels (per the workspace's label policy), fix-version,
  priority, and a `Caused by` link to the triggering ticket.
- **Provenance comment text** — the first comment to post once the ticket exists.
- A user-facing report (see below). **The ticket is not yet created** — pushing
  to the tracker is the caller's next step.

## Process (follow exactly)

### Step 1 — Triage: confirm this is actually a Bug
Walk the exclusion rules: unmerged-PR defect → fix in PR; enhancement →
`author-story`; spec defect → spec edit; third-party-only → workaround
Story/Task. If any applies, surface the routing and **stop**.

### Step 2 — Find the triggering ticket
If QA filed it during Story testing, it's that Story. Otherwise scan recent
merged Stories in the affected component for the one whose AC the defect
contradicts. If nothing matches, record `Triggering ticket: (none found —
legacy/pre-spec code)` and flag it for the lead. This becomes the `Caused by`
link.

### Step 3 — Verify repro context is complete
Confirm steps-to-reproduce, expected (traces to AC or contract), actual (with
error/stack/log link), and environment. If any of the four is missing, **stop**
— a Bug without repro is noise.

### Step 4 — Draft the Summary
Pattern: `<component> — <one-sentence observable defect>`. Describe the
**symptom**, not the suspected cause ("Connector — retries do not honour the
back-off cap", not "Race condition in retry logic"). Keep tracker fields
ASCII-only.

### Step 5 — Draft the Description (per the template)
Instantiate the five sections from `references/bug-template.md`: Summary, Steps
to reproduce, Expected behaviour, Actual behaviour, Acceptance Criteria. **Bug
AC is the test that confirms the fix**, not a restatement of the defect (e.g.
"When <repro step>, the system shall <expected>"; "A regression test covering
<scenario> exists in CI"). Add optional Environment / Investigation-notes
sections when warranted; investigation notes carry only **clearly-marked
suspicion**, never assertion — the fixing dev owns root cause.

### Step 6 — Set labels, fix-version, priority
Apply the workspace's label policy (see your tracker-managing workflow if one is
installed). Fix-version = current active release (or the original release for a
hotfix against it). Priority: Highest (outage/data loss), High (blocks in-flight
work), Medium (degraded but has a workaround), Low (cosmetic).

### Step 7 — Draft issue links
`Caused by` → the triggering ticket. If genuinely uncertain, use `Relates` and
note the ambiguity. A separate regression-test Task → `Relates`. Bugs usually do
not set a `parent` field — the parent relationship is the link.

### Step 8 — Draft the provenance comment
Prefix with `[ba]` (or `[qa]` when QA files it) so humans can attribute it:
"Filed during <dev|QA|staging-soak|prod-incident> on <date>. Triggering ticket:
<key>. Reproduction confirmed in <env>. Logs/trace: <link>."

### Step 9 — Surface the report
The caller's next step is to push the payload to the tracker (create the issue,
post the link, post the provenance comment). This skill does **not** call the
tracker MCP itself.

## Output report (to the user)

```
Bug drafted — <date>

Defect:            <one-line observable>
Component:         <component>
Stage filed in:    <dev | QA | staging-soak | prod-incident>
Triggering ticket: <key> (<title>) | (none found — flag for lead)
Severity:          <Highest | High | Medium | Low>

Payload (ready to push):
  summary:     <Summary line>
  description: 5 sections (Summary, Steps, Expected, Actual, AC)
  labels:      <per workspace label policy>
  fixVersion:  <release>
  priority:    <level>
Issue links:   Caused by → <triggering key>;  Relates → <regression-test key>
Provenance comment drafted.

Next step: create the issue, post the link, post the provenance comment.
```

## Anti-patterns

- Cause-shaped Summary — describe the symptom, not the suspected cause.
- AC that restates the defect — AC is the fix-confirming test.
- Skipping the `Caused by` link — it is the Bug's primary attribution signal.
- Filing a Bug for an enhancement, a draft-PR defect, or a spec defect.
- Authoring a Story-shaped spec file alongside the Bug — Bugs are tracker-only.
- Pushing to the tracker inside this skill — it stops at "payload drafted".
- Empty investigation notes treated as assertion — they are explicitly suspicion.

## References

- `references/bug-template.md` — the bundled bug payload contract (sections,
  links, provenance comment, when NOT to file).
- **Workspace I/O:** `steering-docs/project-kb/` — component map and vocabulary,
  if present.
- **Related skills** (compose loosely; no file dependency): `author-story`
  (when the inbound is misclassified as a Bug).
