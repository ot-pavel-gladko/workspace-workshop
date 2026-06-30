---
name: lead-orchestration
description: |
  The lead agent's orchestration runbook on top of the Initiative → Epic → Story
  pipeline. Pick the right entry point for inbound work, delegate
  decomposition to BA using layered (nested) delegation, author ADRs that gate
  Stories, brief implementers with five anchors, run the post-merge review +
  cost-loop gates. Implementer-neutral. The lead is the single entry point;
  sub-agents may themselves dispatch further specialists up to the platform's
  5-level depth cap (CC ≥ 2.1.172).
  Triggers: "what's next", "orchestrate this", "set up the work for
  story X", "dispatch the next story".
license: Proprietary - DataArt Core IP.
metadata:
  category: workflow-orchestration
  level: "300"
  author: dataart-aila
  version: "1.1.0"
  last_updated: "2026-06-13"
  tags: [lead, orchestration, delegation, nested-delegation, adr, dispatch, workflow-orchestration]
---

# Lead Orchestration v1.1.0

The runbook the lead agent follows when work enters the workspace, when
Stories are picked up, and when work flows back from the implementer.

This skill codifies the **agent-split contract** between lead and BA:
the lead never authors Stories, the BA never authors ADRs, and neither
dispatches the implementer directly without going through the
sequencing checks here.

## Layered (nested) delegation — the expected pattern

Claude Code (≥ 2.1.172) supports up to **5 levels** of nested agent
spawning. The lead operates at level 1 and is the **single entry point**
for all inbound work. Specialists dispatched by the lead operate at
levels 2–5 and **may themselves dispatch further specialists** without
routing back to the lead between layers. This is the intended pattern
for Initiative → Epic → Story breakdowns:

```
lead (L1) — single entry point; all inbound work lands here
  └─ ba / domain-expert (L2) ← decompose-initiative, decompose-epic
       └─ estimate-story / author-story (L3) ← per-Story decomposition
            └─ implementer (L4) ← code work, tests
                 └─ reviewer (L5) ← isolated review context
```

**Do not pull work back through the lead between layers.** When the
lead dispatches BA to decompose an initiative, the BA may dispatch
estimate-story on each epic without routing back. The chain collapses
to the lead only when the whole sub-tree is finished.

**Depth cap — 5 levels maximum.** The platform enforces this limit.
Do not recurse beyond it. If a sub-task would require a sixth nesting
level, restructure the brief so the deepest specialist handles that
work directly rather than spawning further.

**Single entry point — the lead is not bypassed.** Sub-agents are
workers, not second orchestrators. A specialist must never accept
inbound work from the operator and start orchestrating independently.
Every operator message lands at the lead first; the lead plans and
then delegates. If a sub-agent receives a direct operator message that
belongs to a new initiative or epic, it should surface this to the
lead rather than processing it autonomously.

## When to invoke

- A new inbound request arrives (user message, Jira link, file).
- A Story's `Status` flips to `Refined` and is ready for dispatch.
- An implementer signals a Story is `Done` and the post-merge gate
  needs to run.
- A scope change ripples through the active backlog and re-sequencing
  is needed.

**Do not invoke** for individual implementation steps — that's the
implementer agent's territory.

## Variable entry levels (this is the key skill for picking)

When inbound work arrives, **the first decision is the entry level**.
The lead picks; the BA executes the corresponding decomposition.

| Inbound | What you see | Entry level | Lead's first move |
|---|---|---|---|
| Vague theme, quarter target, strategic ask | Multi-paragraph description, multiple capability areas, weeks-to-months horizon | **Initiative** | Open `specs/INITIATIVES/INI-NNNN.md`, fill the Why/Strategic outcome/Constraints, then dispatch BA to run `decompose-initiative`. |
| Jira epic, PRD section, Confluence feature spec | Single named feature, scoped, acceptance gates roughly identifiable | **Epic** | Open `specs/EPICS/EPIC-NNNN.md`, fill Business outcome/Scope/Out of scope, then dispatch BA to run `decompose-epic`. |
| Single Jira ticket, one-line user request, single file | Crisp, one capability, sub-13-SP feel | **Story** | Open `specs/STORIES/STORY-NNNN.md`, draft the Statement+ACs, then dispatch BA to run `estimate-story`. |

If you're unsure between levels, ask the user: *"Is this a single
feature (Epic), or a multi-feature initiative (Initiative), or a single
ticket (Story)?"* Then commit to the level. Don't decompose more than
the input warrants.

## Inputs you read

1. **`steering-docs/INDEX.md`** — orientation. Pick the right KB for
   the question at hand.
2. **`steering-docs/project-kb/PROJECT_GOALS.md`** — north-star + non-
   goals. Every plan must serve these.
3. **`steering-docs/project-kb/TECH_ARCHITECTURE.md`** — load-bearing
   architectural principles.
4. **`steering-docs/code-kb/<repo>/MODULES.md`** — module dependency
   order, status (`planned`/`partial`/`implemented`), and ownership.
   You read this before briefing the implementer.
5. **`specs/REGISTER.md`** + the per-level files — the current shape
   of the spec tree.

## Inputs the BA reads, that you DO NOT re-read

- `FEATURES.md`, `GLOSSARY.md`, `DOMAINS.md` — BA owns these.
- `domain-kb/PATTERNS.md`, `project-kb/devops/PATTERNS.md` — BA cites
  patterns into Stories at decomposition time; you don't paraphrase
  patterns yourself.

Reading these as the lead causes the BA's work to drift. Trust the
hand-off.

## Process (follow exactly)

### Step 1 — Pick the entry level

Use the table in "Variable entry levels" above. If ambiguous, ask the
user — one question, multiple-choice if possible. Commit to a level.

### Step 2 — Author the seed spec file (if missing)

The BA's decomposition skills require an existing seed file:

- **Initiative entry** — you write `specs/INITIATIVES/INI-NNNN.md`
  filling Why/Strategic outcome/Constraints/In scope sections from the
  inbound material. Leave `Decomposition` empty (BA fills it).
- **Epic entry** — you write `specs/EPICS/EPIC-NNNN.md` filling
  Business outcome/Scope/Out of scope/Dependencies/NFRs. Leave Story
  register empty (BA fills it).
- **Story entry** — you write the *skeleton*
  `specs/STORIES/STORY-NNNN.md` with Statement + draft acceptance
  criteria. Leave Estimation empty (BA fills it via
  `estimate-story`).

You write business-prose in these seeds. BA refines.

### Step 3 — Dispatch the BA

Use `TaskCreate` + subagent dispatch to invoke the BA. Brief:

- **The seed file path.**
- **The skill to run** (`decompose-initiative`, `decompose-epic`, or
  `estimate-story`).
- **Any KB anchors** the BA should consult beyond the default reads
  (e.g., "PROJECT_GOALS.md §3 is the constraint for sequencing").

You do **not** invoke the decomposition or estimation skills yourself.
That violates the agent-split contract.

### Step 4 — Process the BA's return

When the BA returns:

- **ADR triggers** — author the ADRs the BA surfaced. Use the
  workspace's ADR template (`specs/adr/0000-template.md` or
  `docs/adr/0000-template.md` per the workspace's convention). Cite
  patterns. Get the user to flip Status to `Accepted` before
  dispatching the implementer.
- **Scope gaps** — escalate to the user before dispatching any work.
- **Sequencing** — BA produces a *proposed* order from the dependency
  constraints; you confirm it matches the code-KB's module dependency
  order.
- **Open questions** — pause and resolve with the user before
  proceeding.

### Step 5 — Pick the next Story

Stories are sequenced inside their parent Epic's `Story register`
(or in `specs/REGISTER.md` for orphan Stories).

Pick the topmost Story in `Refined` status whose:

- `Depends on` are all `Done`.
- `Triggers ADR` field is empty *or* references an ADR in `Accepted`
  status.

If the next Story triggers an ADR that is still `Proposed` (or not yet
authored), author the ADR first.

### Step 6 — Brief the implementer with five anchors

The implementer task brief must carry **five anchors**:

- **(a) Story-ID** — e.g., "Implement STORY-0003." The implementer
  reads the Story file for scope and acceptance criteria.
- **(b) Owning module** — and where it lives in the codebase.
- **(c) Module status** — `planned` / `partial` / `implemented`, with
  `planned → implemented` being the most common landing.
- **(d) Cross-module hand-offs** the Story triggers.
- **(e) Pattern numbers** (`P-NNN`, `DP-NNN`) the implementation must
  apply.

Without these the implementer will re-derive — costing tokens (agentic)
or hours (human) and risking drift.

### Step 7 — Run the post-merge gate

When the implementer signals `Done`:

1. **Dispatch the reviewer** (if the workspace has one). Brief: branch
   name + Story ID + cycle number. Reviewer operates in isolated
   context.
2. **Process findings** by severity. Critical findings block merge;
   Major findings block by default but can be accept-and-document with
   explicit justification.
3. **Two-cycle re-review cap.** If cycle 2 still has Critical or
   Major, escalate to the user — never dispatch a third reviewer
   cycle.
4. **Merge + activation.** After review clears, dispatch the
   DevOps agent (if present) to squash-merge and apply any runtime
   activation (migrations, scheduled jobs, dependency installs).
5. **Cost-loop closure.** Dispatch the BA with per-cycle cost data —
   tokens per dispatch, wall-clock per dispatch — captured live as you
   orchestrated. Don't reconstruct from memory; the `<usage>` envelope
   in each Agent return is the canonical source.

### Step 8 — Surface to the user

After Done + merge + activation + cost-loop:

- New main HEAD or equivalent ship marker.
- Activation result (migrations applied, services restarted, etc.).
- Cost summary refreshed for this Story (the BA does the refresh; you
  surface the numbers).
- Next Story available for dispatch.

## Cost telemetry — capture as you orchestrate

Every Agent invocation returns a `<usage>` envelope with `total_tokens`
and `duration_ms`. Record these per cycle **as the Story progresses**.
Reconstructing later is unreliable.

Shape (mirrors what the BA expects at cost-loop closure):

- Implementer initial: tokens + minutes.
- Implementer cycle-1 fix (if any): tokens + minutes.
- Implementer cycle-2 fix (if any): tokens + minutes.
- Reviewer cycle 1: tokens + minutes.
- Reviewer cycle 2 (if any): tokens + minutes.
- DevOps squash-merge / activation: tokens + minutes.
- **Totals:** implementer tokens, review tokens, implementer+review
  tokens; implementer wall-clock, review wall-clock; cost-per-SP.

Pass the full per-cycle table to BA — `—` placeholders are not
acceptable when the data was in your dispatch transcripts.

## Anti-patterns

- ❌ Invoking `decompose-epic` or `decompose-initiative` yourself.
  Delegate to BA.
- ❌ Writing Stories yourself. BA's job.
- ❌ Dispatching the implementer without all five anchors. Costs a
  cycle.
- ❌ Skipping the reviewer "because the Story is small." The reviewer
  gate is mandatory.
- ❌ Re-dispatching the reviewer a third cycle. The 2-cycle cap exists
  for a reason.
- ❌ Forwarding the implementer's session history to the reviewer.
  Reviewer operates in isolated context on purpose.
- ❌ Reading FEATURES.md / PATTERNS.md / GLOSSARY.md repeatedly. Trust
  BA's hand-off; verify only when a finding contradicts them.
- ❌ Treating a green squash-merge as a shipped Story. If the diff
  contained migrations / scheduled-job changes / compose changes /
  dependency changes, runtime activation must run before the Story is
  Done.
- ❌ Decomposing more than the input warrants. A single Jira ticket
  is a Story, not an Initiative.
- ❌ Pulling work back through the lead between delegation layers.
  Once BA is dispatched for a sub-tree, let the chain proceed to its
  natural completion before reviewing results.
- ❌ Recursing beyond 5 levels of agent nesting — the platform cap.
  Restructure briefs to stay within the depth limit.
- ❌ Allowing a sub-agent to become a second orchestrator. If a
  specialist starts accepting and planning new operator work
  independently, it is violating the single-entry-point contract.
- ❌ Using `ultracode` as a keyword in task briefs to trigger extended
  orchestration modes. Describe what is needed in plain task briefs.

## References

- `.claude/skills/decompose-initiative/SKILL.md` — what BA runs when
  the entry level is Initiative.
- `.claude/skills/decompose-epic/SKILL.md` — what BA runs when the
  entry level is Epic.
- `.claude/skills/estimate-story/SKILL.md` — what BA runs when the
  entry level is Story (or per draft from the decomposition skills).
- `specs/INITIATIVES/0000-template.md`, `specs/EPICS/0000-template.md`,
  `specs/STORIES/0000-template.md` — the seed templates.
- `steering-docs/code-kb/<repo>/MODULES.md` — module dependency order
  for sequencing and the five-anchor brief.
- The workspace's ADR template — where you author ADRs that gate
  Stories.
