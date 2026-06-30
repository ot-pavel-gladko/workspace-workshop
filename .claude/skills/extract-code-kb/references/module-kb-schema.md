# Module KB schema

Each `modules/{name}/KB.md` must follow this shape. Stage 2b enforces it; Stage 3 reads it.

## Required sections (in order)

1. **`# {module-name}`** — H1 matches the kebab-case module name.
2. **`## Purpose`** — 1–3 sentences. Black-box description.
3. **`## Public Interface`** — symbols / commands / routes / config keys an outside caller touches. Group by surface. Omit empty subsections.
4. **`## Internal Structure`** — sub-areas with anchor files. For small modules: `"Single-file module. See Files below."`
5. **`## Dependencies`** — sibling modules talked to + reason. Optional trailing bullet for notable third-party / stdlib deps.
6. **`## Conventions / Gotchas`** — non-obvious only. Omit if nothing to say.
7. **`## Files`** — flat bulleted list of file paths in the module.

## Length budget

- Target: 50–250 lines.
- Hard ceiling: 300 lines. Past that, the module is too big — add a final `> NOTE: module exceeds size budget; recurse.` line and the running agent will re-enter Stage 1–2 inside this module's file set.

## Style

- No code snippets except a single line if it illustrates a non-obvious public API.
- File paths verbatim from the index.
- Sibling module names are the same kebab-case names used in clustering and in `MODULES.md`.

## Example (abbreviated)

```markdown
# workspace-generator

## Purpose

Renders agent workspaces (`.claude/`, `.kiro/`) from a list of repos and skill catalogs. Owns the templating step of `aila-workspace init` — repo discovery and KB extraction live elsewhere.

## Public Interface

- **Functions** — `generate_workspace(repos, agent)`, `render_md(spec)`.
- **CLI** — none directly; invoked via `aila-workspace init`.

## Internal Structure

- **Claude renderer** (`claude_workspace.py`) — emits `.claude/agents/*.md`.
- **Kiro renderer** (`kiro_workspace.py`) — emits `.kiro/steering/`.

## Dependencies

- `pydantic-schemas` — workspace + agent models.
- `aila.skill_providers` — to discover available skills.

## Files

- `aila_catalog_schema/claude_workspace.py`
- `aila_catalog_schema/kiro_workspace.py`
- `aila_catalog_schema/kiro_agent.py`
```
