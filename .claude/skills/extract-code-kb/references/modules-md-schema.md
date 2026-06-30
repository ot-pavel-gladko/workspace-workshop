# MODULES.md schema

The root index. Read FIRST by any agent or human navigating the repo.

## Required sections (in order)

1. **`# {repo-name}`** — H1 matches the repo directory name.
2. **`## Summary`** — 3–5 sentences. What the repo is, who uses it.
3. **`## Module map`** — markdown table with columns `Module | Purpose | Path`. Every top-level module appears here.
4. **`## Relationships`** — short prose or edge list describing inter-module wiring.
5. **`## Entry points`** — CLI commands, library APIs, servers. Omit subsections that don't apply.
6. **`## Conventions`** — repo-wide conventions worth surfacing once. Omit the whole section if nothing applies.
7. **`## Navigation protocol`** — fixed quote block (verbatim) that tells an agent how to use this file.

## Verbatim navigation protocol block

The workspace generator (`claude_workspace.py`, `kiro_workspace.py`) searches `MODULES.md` for this exact line to confirm the file is well-formed:

```markdown
> For agents reading this file: pick the module(s) relevant to the task from the table above, open `modules/{name}/KB.md`, then descend to source. Do not grep the whole tree before consulting a module KB.
```

Keep it verbatim. If you change the wording, also update the matcher in `claude_workspace.render_md()`.

## Length budget

- Target: 80–200 lines.
- Hard floor / ceiling: 60 / 250.

## Style

- The module map is exhaustive (every top-level module) and ordered roughly from entry-point modules → core domain → infrastructure → tests/tooling.
- No nested module entries. Recursed children are reached by opening their parent's KB.
- File paths in the map are relative to the KB root (`modules/{name}/KB.md`).
