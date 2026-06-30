# Stage 3 — Root MODULES.md synthesis (Opus)

One Opus call per repo. Synthesizes the agent-facing root index from the top-level module KBs.

## Model

Opus. This is the only step that needs to reason across all modules at once and write prose an agent will land on first. Worth the cost.

## Prompt

> You are writing the root navigation index for a repository. A fresh agent will read this file FIRST before opening any source code. Its job: let the agent decide which module(s) to load next.
>
> Inputs:
>
> - Repository name and a short root-level summary (README excerpt or `pyproject.toml` description).
> - The full text of every top-level `modules/{name}/KB.md`.
> - The top two levels of the directory tree.
>
> Write a markdown document with this exact structure:
>
> ```markdown
> # {repo-name}
>
> ## Summary
>
> {3–5 sentences. What this repo is, who uses it, how it fits into a larger system. If the repo is a CLI tool, name the binary. If it's a library, name the public import path.}
>
> ## Module map
>
> | Module | Purpose | Path |
> |---|---|---|
> | {name} | {one-line purpose from the module KB} | `modules/{name}/KB.md` |
> | ... | ... | ... |
>
> ## Relationships
>
> {How modules connect. Either prose ("`cli-entrypoints` wires `workspace-generator` and `aws-providers` through `settings`.") or a bulleted list of edges. Keep it short — 10–20 lines max. Do not duplicate per-module Dependencies sections.}
>
> ## Entry points
>
> {Where execution starts. Concrete:
> - **CLI commands** — `aila-meta`, `aila-workspace`, ... with one-line purposes.
> - **Library API** — top-level imports an external user would reach for.
> - **Servers / daemons** — if any.
>
> Omit subsections that don't apply.}
>
> ## Conventions
>
> {Repo-wide conventions worth surfacing once so module KBs don't repeat them. Examples:
> - "All packages register via `aila.skill_providers` entry-point group."
> - "Settings are loaded from `~/.aila/settings.json`; env vars override."
> - "Python is the only supported runtime; min version 3.11."
>
> Keep it tight. Omit the section entirely if nothing applies.}
>
> ## Navigation protocol
>
> > For agents reading this file: pick the module(s) relevant to the task from the table above, open `modules/{name}/KB.md`, then descend to source. Do not grep the whole tree before consulting a module KB.
> ```
>
> Constraints:
>
> - Target length: 80–200 lines. This is an index, not a dump.
> - The module map must list every top-level module from the input.
> - Do not invent modules that weren't given to you.
> - Do not include nested children — they're loaded on demand from the parent's KB.

## Output validation

- Every module from the clustering output appears in the `Module map`.
- Paths in the table point to existing `modules/{name}/KB.md` files.
- File length is in `[60, 250]` lines (warn outside `[80, 200]`, fail outside `[60, 250]`).
- The `Navigation protocol` quote block is present verbatim — the workspace generator looks for it when wiring `CLAUDE.md`.
