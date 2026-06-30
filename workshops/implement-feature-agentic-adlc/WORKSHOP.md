# Workshop: Implement a Feature with the Agentic Development Lifecycle (ADLC)

> # 🚧 UNDER CONSTRUCTION — preview only
>
> **This workshop is not runnable yet.** What follows is a description of what it
> *will* cover — the feature it will build and how the agentic flow will work — but
> the hands-on, executable steps are still being authored. There is **no real
> implementation to run in this version.**
>
> In the meantime, complete the prerequisite **`configure-workspace-kb-and-agents`**
> workshop (that one is fully runnable), and check back here later.

**Level:** 02 — advanced (planned)
**Status:** 🚧 Under construction — description only, not yet executable
**Prerequisite (when ready):** the `configure-workspace-kb-and-agents` workshop — a configured workspace with 7 agents (incl. the design agent and a Jira-driving lead).

---

## What this workshop will be about

A hands-on experience of the **Agentic Development Lifecycle (ADLC)**: taking a real
product feature from idea to a reviewed pull request with a **team of AI agents**,
where the learner is the **human in the loop at every decision gate** (Product
Owner, BA reviewer, Tech-lead). The aim is to *experience how agents collaborate* —
how an orchestrator delegates across specialists with different tools, where they
hand off, and where human judgment belongs — not just to ship the feature.

**Intended learning outcomes:**
- Run a feature through a **design → requirements → implementation** agentic pipeline with human-in-the-loop gates.
- See **multi-agent orchestration**: a lead delegating to design, BA, and code agents that have *different* tool scopes — and how the lead bridges them.
- Use a **persistent feature manifest** so the workflow survives stopping and resuming (state-driven, not session-driven).
- Keep many participants safe in **one shared Jira + repo** via per-run uniqueness and branch discipline.

## The feature it will build

> **Add a time-tracking feature to the full-stack-fastapi-template application.**
> Users can create **projects**, log **time entries** against them (date, hours,
> description, billable flag), and view a **dashboard** summarizing hours worked.
> Built to mirror the existing **Items module** — backend (SQLModel, FastAPI CRUD,
> Alembic migrations) and frontend (TanStack Router/Query, React Hook Form,
> shadcn/ui). Deliberately simple: no approval workflows, invoicing, CSV export, or
> timer/stopwatch.

Two new entities (**Project**, **TimeEntry**) plus a summary dashboard — enough to
exercise backend, frontend, and a wireframe.

## How it will work (planned approach — design-first)

The workshop will run as **three consecutive sessions**, each ending at a human
review gate (a natural stop/resume point):

1. **Design** — scaffold a unique Jira epic + feature branch, then the **design
   agent** produces a clickable HTML wireframe grounded in the product's real
   styles; the learner reviews it as **Product Owner** (approve, or send back with
   comments).
2. **Requirements** — the **BA agent** authors BE/FE/Wireframe stories *from the
   approved wireframe*; the learner reviews them as **BA reviewer** and marks them
   ready.
3. **Implementation** — the **lead agent** orchestrates the **code agent** to build
   the feature against the stories + wireframe, push to the branch, and open a PR;
   the learner reviews it as **Tech-lead**.

Underlying mechanics it will teach:
- **Persistent feature manifest** (`.adlc/feature.json` on the feature branch) as the source of truth, so any session can resume where the last left off.
- **Per-run uniqueness/isolation** in a shared Jira + repo: an epic-key-derived branch and `run-<id>` labels on the epic and stories.
- **Feature-branch discipline** — all work on the branch, `main` untouched.
- **Orchestrator-bridges-tool-scopes** delegation — the lead carries Jira-authored requirements to the code agent (which can't read Jira) and points it at the on-branch wireframe.

## What's not ready yet

The runnable parts are still being authored and are intentionally **not** included
in this version:
- the pre-flight gate + identity/RUN_ID setup,
- the step-by-step hands-on (scaffold → wireframe → requirements → implementation → review),
- the manifest mechanics, the reject-loop, and the acceptance/validation checks.

These will be added in a future release of this workshop.

> **Facilitator note (incl. `workshop-executor`):** present the **🚧 UNDER
> CONSTRUCTION** notice above and **stop**. Do **not** attempt to run any steps —
> there are none in this version. Point the learner at the prerequisite
> `configure-workspace-kb-and-agents` workshop instead.

## References

- Prerequisite workshop: `configure-workspace-kb-and-agents` (fully runnable — configures the workspace this one will build on).
- Concepts it will demonstrate: state-driven resumability (the manifest), per-run isolation in shared Jira/repo, feature-branch discipline, and orchestrator-bridges-tool-scopes delegation.

**Status last updated:** 2026-06-23 · **Generated:** 2026-06-17
