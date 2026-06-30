# STORY-NNNN: <Title — imperative, business language; no module/file names>

- **Status:** New   <!-- Status flow (ADR-0010): New → Triage → BA Review → Sprint Ready → In Progress → In Review → QA Ready → QA In Progress → UAT → Ready for Deploy → Done (or Discarded) -->
- **Parent epic:** <EPIC-NNNN or "(none — orphan story, no Epic above)">
- **Parent initiative:** <INI-NNNN or "(none)">
- **Estimate:** <_ SP — assessed YYYY-MM-DD via the estimate-story skill>
- **Assignee:** <agent name (e.g. artisyn-be, artisyn-dev, artisyn-domain) — set with Status: Sprint Ready to authorize autonomous dispatch; "(none)" otherwise>
- **Labels:** <adlc-auto (opt-in automation gate, ADR-0010 §3); add more labels separated by commas; omit field if unused>

## Statement

As a <single role>, I want <capability>, so that <outcome>.

## Acceptance criteria

<3–8 black-box, testable behaviours. Each assertable in an integration test.
User-observable shape ("the user sees …"), not implementation ("the API returns …").>

1. <behaviour>
2. <behaviour>

## Capabilities affected

<Plain prose — what changes from the user's perspective. No file paths, no module
names, no code references. A reader who never opened the repo should follow this.>

## Non-functional requirements

<Only NFRs that constrain THIS story (latency, reliability, security/PII, cost
ceiling, observability). Drop project-wide defaults.>

## Out of scope

<Explicit contract of what this story does NOT cover.>

## Dependencies

- **Depends on:** <other STORY-NNNN, or external readiness: vendor endpoint /
  schema baseline / ADR Accepted state>

## Triggers ADR

- <ADR-NNNN — decision that must be pinned before implementation, or "(none)">

## Cites patterns

- <P-NNN / pattern name from the workspace pattern catalogue>

## Estimation

<Filled by the estimate-story skill: per-dimension scores, sum → bucket → SP,
nearest anchor, and a short rationale.>

## Status flow reference (ADR-0010)

The runner watch loop gates the Development stage on **Status: Sprint Ready** (the
configured entry status) AND an **Assignee** naming a known agent AND the **Labels:**
field containing `adlc-auto` (the default require-label).

Full canonical flow:
`New → Triage → BA Review → Sprint Ready → In Progress → In Review → QA Ready
→ QA In Progress → UAT → Ready for Deploy → Done` (or `Discarded`, terminal)

The Development stage (v1 automated): `Sprint Ready → In Progress → In Review`.
Merge (`In Review → Done`) is **always human-gated** (strong-HITL; ADR-0010 §4).
