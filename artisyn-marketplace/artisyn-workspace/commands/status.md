---
description: Show workspace setup progress — 15-phase checklist with the next step highlighted
argument-hint: "[--verbose] [--json]   |   mark <phase>   |   clear <phase>"
allowed-tools: Bash
---

Render a checklist of every workspace setup phase, marking each one done or
pending based on what's on disk plus the small `.artisyn/setup-state.json` state
file. Phases are grouped into four `<PROJECT>-N` blocks (CLI & bootstrap,
Domain knowledge, Code & agents, Validation) so progress lines up with the
typical onboarding pipeline.

The **NEXT** call-out highlights the first pending phase so post-install
content steps (the `artisyn-ws-setup` subagent invocation, secret-filling,
the pilot task, etc.) don't slip through.

## Phases tracked

**Group 1 — CLI & bootstrap** (probe-driven):
- CLI + wheels installed
- Profile collected (`workspace-profile.yaml`)
- Structural files generated (`workspace.py`, `.mcp.json`, `.claude/agents/`, `.claude/settings.json`)
- Marketplace plugin wired (`artisyn-marketplace/` + `extraKnownMarketplaces` / `enabledPlugins`)
- Repos manifest populated (`repos.txt`)
- Secrets filled (`.env`)

**Group 2 — Domain knowledge** (heuristic "authored": >30 lines, ≤4 placeholder markers):
- Project KB authored (`project-kb/{PROJECT_GOALS,DOMAINS,FEATURES,INTEGRATIONS,TECH_ARCHITECTURE}.md`)
- DevOps docs authored (`code-kb/devops/{BRANCHING,CICD,DEPLOYMENT,ENVIRONMENTS,PATTERNS}.md`)
- Domain KB authored (`domain-kb/{GLOSSARY,PATTERNS,VENDORS}.md`)
- Repos reachable (every repo in the manifest resolves to a checkout under `../src`)

**Group 3 — Code & agents**:
- Code KB built per repo (`steering-docs/code-kb/<repo>/MODULES.md`)
- Workspace-setup review *(state marker — set by the `artisyn-ws-setup` subagent)*
- INDEX.md authored (`steering-docs/INDEX.md`)

**Group 4 — Validation**:
- WORKSPACE_SELFTEST passed *(state marker)*
- Pilot task delivered *(state marker — first real ticket walked end-to-end)*

## Subcommands

- (no args) — render the checklist.
- `mark <phase>` — set a state marker. Markable phases: `workspace_setup_completed`, `selftest_passed`, `pilot_task_delivered`.
- `clear <phase>` — delete a state marker.
- `--verbose` — print per-phase next-step hints inline.
- `--json` — machine-readable output.

## Execute

```bash
artisyn-workspace status $ARGUMENTS
```

After the run, report the rendered checklist, leading with the **NEXT**
call-out the CLI prints.
