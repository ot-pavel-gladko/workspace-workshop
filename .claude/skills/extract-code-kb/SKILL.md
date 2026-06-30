---
name: extract-code-kb
description: |
  Generates a modular, hierarchical code knowledge base for a repository using LLM-driven analysis instead of tree-sitter. Decomposes the codebase into ~10 black-box modules with per-module KBs (purpose, public interface, dependencies) and a root MODULES.md index. Replaces the flat KNOW.md output of `aila-meta --document` that becomes unusable on large repos. Uses model tiers cost-effectively: Haiku for per-file summaries (massive fan-out), Sonnet for module clustering and module KBs, Opus for the root index synthesis. Recursive: when a module is too big, the same pipeline re-runs inside it and emits a nested modules/ tree.

  Use when setting up a workspace for a new repo, refreshing the navigation KB after significant code changes, or replacing an existing tree-sitter KNOW.md with something agents can actually navigate.

  Triggers: "extract code kb", "build modules.md", "generate code knowledge base", "document this repo for agents", "refresh modules", "replace know.md"

license: Proprietary - DataArt Core IP. Cannot copy, modify, or use without DataArt permission.
metadata:
  category: documentation
  level: "300"
  author: dataart-aila
  version: "1.0.0"
  last_updated: "2026-05-12"
  tags: [code-intelligence, knowledge-base, llm-driven, hierarchical, module-decomposition, navigation, workspace-setup]
---

# Extract Code KB (Hierarchical, LLM-driven)

Generate a navigation-friendly code KB by decomposing a repo into ~10 modules. No tree-sitter; no per-language parsers. The output is consumed by every developer/agent role via the Code Navigation Protocol baked into `CLAUDE.md`.

## What This Skill Does

Produces, for a target repository:

- `MODULES.md` — root index. Names the modules, draws inter-module relationships, lists entry points and repo-wide conventions.
- `modules/{name}/KB.md` — one per module. Black-box description: purpose, public interface, internal structure, dependencies, gotchas, files index.
- `_index/files.jsonl` — per-file summary cache (one record per source file: path, sha256, summary). Drives incremental refresh.

Modules recurse: a too-big module gets its own `modules/{child}/KB.md` tree underneath.

## When to Use

- Initial workspace setup for a new repo (`aila-workspace init --document`).
- Refreshing the navigation KB after major code changes.
- Replacing a flat `KNOW.md` with something an agent can navigate.

**Triggers:** "extract code kb", "build modules.md", "generate code knowledge base", "document this repo for agents".

## Why This Replaces Tree-Sitter

Tree-sitter providers in `skill-sdk-aila/skill_sdk_aila/metadata/providers/` produce one flat `KNOW.md` per `{repo}/{lang}` listing every function/class/import. On big repos the output is unusable for navigation. LLM-driven map-reduce instead chooses module boundaries *after* every file has been read (cheaply, by Haiku), and the agent loads only the module KBs relevant to its task.

## Inputs

- **Target repo root** — directory containing the source to document.
- **Output root** (default: `steering-docs/code-kb/{repo-name}/`).
- **Source file selector** — defaults to all tracked files matching common code extensions (`.py .ts .tsx .js .jsx .go .rs .java .kt .cs .tf .hcl .rb .php`), excluding tests, `__pycache__/`, `node_modules/`, build outputs.
- **Flags:** `--stage {1,2,3,all}` (default `all`), `--force` (ignore cache), `--max-modules N` (default 12), `--module-file-limit N` (default 40), `--module-token-limit N` (default 8000), `--recursion-depth N` (default 3).

## Core Workflow

Run Stage 1 → Stage 2 → Stage 3. Stages are independently invocable for debugging.

### Stage 1 — Per-file summaries (Haiku, parallel fan-out)

**Goal:** one paragraph per source file. Cheap, embarrassingly parallel.

**Process:**

1. Discover source files using the selector (above). Exclude generated artifacts and vendored code.
2. Compute `sha256(path-content)` for each file. Load `_index/files.jsonl` if it exists; skip files whose `(path, sha256)` already match.
3. Dispatch parallel sub-agents (one per file batch, batch size ~20) to **Haiku** with the prompt in `references/stage1-per-file-summary.md`. Each sub-agent returns one JSON record per file.
4. Merge results into `_index/files.jsonl` (one JSON record per line). Each record:

   ```json
   {
     "path": "skill_library_aila/skills/extract-code-kb/SKILL.md",
     "sha256": "...",
     "summary": "...",
     "exports": ["..."],
     "depends_on": ["..."],
     "framework_hints": ["..."]
   }
   ```

5. Verify: every discovered file has a record; every record has a non-empty summary.

**Cost shape:** dominates total spend, but on Haiku. Linear in file count.

See `references/stage1-per-file-summary.md` for the exact prompt and JSON schema.

### Stage 2 — Module clustering and per-module KBs (Sonnet)

**Goal:** propose 7–12 module boundaries, then write a KB per module. Recurse if a module is too big.

**Process:**

1. **Cluster.** Load `_index/files.jsonl` and the directory tree. Call **Sonnet** with the prompt in `references/stage2-clustering.md`. It returns a JSON `modules:` array — each entry has `name`, `purpose` (one line), and `files: [paths]`. Constraints: 7–12 top-level modules; folder boundaries are a strong prior but may be crossed when responsibilities cluster; every file belongs to exactly one module.
2. **Sanity-check the clustering.**
   - Module count in `[7, 12]`. If outside, ask Sonnet to revise with an explicit count target.
   - Every file in `files.jsonl` appears in exactly one module's `files`.
   - No two modules share a name.
3. **Write module KBs.** For each module, call **Sonnet** with the prompt in `references/stage2-module-kb.md` and the Stage-1 summaries of files in that module. Output: `modules/{name}/KB.md` following `references/module-kb-schema.md`.
4. **Recurse on too-big modules.** A module is "too big" when *either*:
   - `len(files) > module-file-limit` (default 40), OR
   - Sum of Stage-1 summary tokens for those files exceeds `module-token-limit` (default 8000).

   For each too-big module, treat its file set as a sub-repo and rerun Stages 1–2 inside `modules/{name}/`. Stage 1 reuses the per-file cache. Stop recursing at `recursion-depth` (default 3); at the leaf, accept the larger module and log a warning — this is a signal for human refactoring, not deeper recursion.

**Cost shape:** moderate. ~1 clustering call + N module-KB calls per recursion level.

### Stage 3 — Root index synthesis (Opus, one call)

**Goal:** the agent-facing `MODULES.md` that lets a fresh agent route to the right module without reading anything else.

**Process:**

1. Load all top-level `modules/*/KB.md`. Recursed children are *not* loaded — the root index only names top-level modules.
2. Call **Opus** with the prompt in `references/stage3-root-index.md`, providing the module KBs and the top of the directory tree.
3. Write `MODULES.md` per `references/modules-md-schema.md`.
4. Verify: every top-level module appears in the module map; entry points section is non-empty if the repo has CLIs or public APIs.

**Cost shape:** one Opus call per repo.

## Quality Checklist

- [ ] `_index/files.jsonl` has one record per discovered source file.
- [ ] Top-level module count in `[7, 12]`.
- [ ] Every file appears in exactly one module.
- [ ] Each module KB follows `references/module-kb-schema.md` (Purpose, Public Interface, Internal Structure, Dependencies, Conventions, Files).
- [ ] `MODULES.md` follows `references/modules-md-schema.md` (Repo summary, Module map table, Relationships, Entry points, Conventions).
- [ ] `MODULES.md` is under ~200 lines (it's an index, not a dump).
- [ ] At least one module recursed if the repo has > ~250 source files.
- [ ] Rerun on unchanged files makes zero Haiku calls (cache hit).

## Output Structure

```
steering-docs/code-kb/{repo}/
├── MODULES.md                          # root index (Opus)
├── _index/files.jsonl                  # per-file summaries (Haiku, cached)
└── modules/
    ├── {module-a}/
    │   ├── KB.md
    │   └── modules/{sub}/KB.md         # only if recursed
    └── {module-b}/KB.md
```

The old per-language `{lang}/KNOW.md` layout is replaced. Modules are language-agnostic.

## Per-agent views

One canonical KB. Each developer agent declares which `modules/{name}/KB.md` files it pulls into its resource list (existing `file://steering-docs/code-kb/...` mechanism in `kiro_agent.py`). Different views via selection, not different generations.

## Examples

### Example 1: Initial generation for a small repo

**Input:** `aila-catalog-schema/`

**Process:**
1. Stage 1: ~40 `.py` files → ~40 Haiku calls in parallel batches.
2. Stage 2: Sonnet proposes 8 modules (e.g., `cli`, `init`, `claude-workspace`, `kiro-workspace`, `kiro-agents`, `schemas`, `bootstrap`, `tests`). Writes 8 module KBs. No recursion (all modules under 40 files).
3. Stage 3: Opus writes `MODULES.md`.

**Result:** `steering-docs/code-kb/aila-catalog-schema/MODULES.md` + 8 `modules/*/KB.md`.

### Example 2: Big repo with recursion

**Input:** a large external Kotlin/Java repo (~800 files).

**Process:**
1. Stage 1: ~800 Haiku calls (batched, parallel).
2. Stage 2: Sonnet proposes 10 top-level modules; 3 of them have >40 files and recurse. Each of those 3 gets its own `modules/{name}/modules/{child}/KB.md` tree.
3. Stage 3: Opus writes a `MODULES.md` that names only the 10 top-level modules; nested children are discovered by an agent on demand by reading the parent's KB.

## Related Skills

- **repo-documentation** — legacy AST/tree-sitter-based generator. Kept for compatibility; not the default backend anymore.
- **aila-knowledge-extraction** — sibling skill for knowledge extraction from non-code sources.
- **workspace-management**, **workspace-prompts** — consume the output via `aila-workspace init`.

## Notes

- Tree-sitter providers in `skill-sdk-aila/skill_sdk_aila/metadata/providers/` are not removed by this skill; they remain available behind a legacy flag in `aila_catalog_schema.init.document_repos()`. Removing them is a follow-up after this skill is validated.
- Refresh story is conservative: only Stage 1 caches. Stages 2 and 3 always rerun, because module boundaries can shift when files change.
- Costs concentrate on Stage 1 (cheap, Haiku). Stage 3 is a single Opus call.
- Per-stage prompts are kept in `references/` so they can be edited without touching this manifest.
