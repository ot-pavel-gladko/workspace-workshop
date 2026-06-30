# aidlc Templates — Index

Templates for rewrite proposals, one file per artifact type.

The pattern is defined by four principles:
- **Agents declare role, not steps** — role identity, stack, boundaries, delegation
- **Scope files declare contracts, not file lists** — routes, data models, events, behavior AC
- **Acceptance Criteria are behavior-based** — testable without reading the body; use `→` notation
- **Layer section headers match agent names** — `## angular-web` not `## Frontend`

---

## Templates

| File | Use when |
|---|---|
| [templates/agent-prompt.md](templates/agent-prompt.md) | Agent file is HOW/MIXED due to file-navigation or missing role structure |
| [templates/scope-file.md](templates/scope-file.md) | HOW-coded task/step file needs rewriting as aidlc scope file |
| [templates/overview.md](templates/overview.md) | `GAP-OVERVIEW` — no execution plan exists |
| [templates/changelog.md](templates/changelog.md) | `GAP-CHANGELOG` — no scope-level changelog |
| [templates/slash-command.md](templates/slash-command.md) | Workspace lacks role-scoped slash commands (optional; skip for aila-SDK) |
| [templates/acceptance-criteria.md](templates/acceptance-criteria.md) | `GAP-AC` or `FLAG-AC-NOT-BEHAVIOR` — AC missing or file-path-keyed |
| [templates/orchestrator-scope-protocol.md](templates/orchestrator-scope-protocol.md) | `GAP-ORCHESTRATOR-SCOPE` — lead agent not wired to read scope first |

## Which signals each template removes

| Template | HOW signals removed |
|---|---|
| agent-prompt | H1 (file-navigation imperatives) |
| scope-file | H2 (Deliverables), H3 (file-path AC), H4 (sequential steps) |
| overview | (structural — enables `GAP-OVERVIEW` resolution) |
| changelog | (structural — enables `GAP-CHANGELOG` resolution) |
| acceptance-criteria | H3 (file-path AC); enables `GAP-AC` and `FLAG-AC-NOT-BEHAVIOR` resolution |
| orchestrator-scope-protocol | (structural — enables `GAP-ORCHESTRATOR-SCOPE` resolution) |
