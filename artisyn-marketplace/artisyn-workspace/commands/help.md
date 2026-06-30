---
description: Show a colored recommended workflow for a role (lead, ba, pm, code, devops, design, domain)
argument-hint: "[<role>]   |   --list   |   <role> --json"
allowed-tools: Bash
---

Print a concise, colored **recommended flow** for an agent role — the staged
steps (TRIAGE → DECOMPOSE → ESTIMATE → CREATE → REFINE → HANDOFF), the skills
used at each step, who the role delegates to / is invoked by, and the KB layers
it reads. Built in; works out of the box.

If the workspace has a generated `pm/roles/<role>-workflow.md` (from the
`role-workflow-doc` skill), the output points to that richer doc too.

## Roles

`lead` · `pm` · `ba` · `code` · `devops` · `design` · `domain`

## Usage

- `<role>` — render that role's recommended flow (e.g. `ba`, `lead`).
- `--list` — list the available roles.
- `--json` — machine-readable output (all roles, or one with a role arg).

## Execute

```bash
artisyn-workspace help $ARGUMENTS
```

After the run, relay the rendered flow. Recommended skills not yet installed are
flagged with an `artisyn-workspace skills add <name>` hint.
