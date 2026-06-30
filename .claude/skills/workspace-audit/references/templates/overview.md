# Template: Execution plan (`specs/00-overview.md`)

Use when `GAP-OVERVIEW` is flagged — no single file declaring phases, agent
assignment, parallelism, and risks exists.

Substitute `<angle-bracket>` placeholders. Agent names MUST match files in
`.claude/agents/` or `.claude/commands/`. Every scope file matching
`specs/NN-*.md` must be linked.

---

```markdown
# <Project Name> — Task Overview & Execution Plan

## Approach

Build in **<N> sequential phases**, each gated on the previous:

```
Phase 1 — <Foundation>       Phase 2 — <Features>        Phase 3 — <Polish>
──────────────────────       ──────────────────────      ──────────────────
01-<topic>                   NN-<topic>                  NN-<topic>
02-<topic>                   NN-<topic>                  NN-<topic>
```

## Agent Assignment

| Task | Agent | Parallel with |
|------|-------|---------------|
| 01-<topic> | `<agent-name>` | — (must be first) |
| 02-<topic> | `<agent-a>` + `<agent-b>` | — |
| 03-<topic> | `<agent-a>` | 04-<topic> |
| 04-<topic> | `<agent-b>` | 03-<topic> |

## Key Risks

1. **<Risk title>** — <one-line description of failure mode and mitigation>
2. **<Risk title>** — …
3. **<Risk title>** — …

## Task Files

- [01-<topic>.md](01-<topic>.md)
- [02-<topic>.md](02-<topic>.md)
- [03-<topic>.md](03-<topic>.md)
```

---

## Rules

- Risks list = 3–7 items. Non-obvious only — no "DB might go down".
- This file is the orchestrator's first read on any multi-scope request.
  Write it to answer "where do we start?" unambiguously.
- When adding a new scope file later, add it to both the Agent Assignment
  table and the Task Files index.
