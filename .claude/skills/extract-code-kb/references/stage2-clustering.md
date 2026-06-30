# Stage 2a — Module clustering (Sonnet)

Cluster the Stage-1 per-file summaries into 7–12 modules. Folder structure is a strong prior but may be crossed.

## Model

Sonnet. This step needs real reasoning over the whole file index but is run once per repo per recursion level.

## Prompt

> You are designing the module decomposition for a code-navigation knowledge base. The goal is to produce **7–12** modules that each function as a black box: a clear purpose, a stable interface, and as few cross-module dependencies as possible.
>
> Inputs:
>
> - A list of per-file summaries (JSONL, one record per file).
> - The repository's directory tree (top three levels).
> - Repo metadata: name, root `README.md` excerpt if available.
>
> Output a single JSON object with this schema (no surrounding prose):
>
> ```json
> {
>   "modules": [
>     {
>       "name": "kebab-case-name",
>       "purpose": "One sentence — what this module is responsible for.",
>       "files": ["path/from/repo/root.py", "..."]
>     }
>   ],
>   "notes": "Optional short note about non-obvious boundary choices."
> }
> ```
>
> Rules:
>
> 1. **Count.** 7 ≤ `len(modules)` ≤ 12. Hard requirement.
> 2. **Coverage.** Every file in the input must appear in exactly one module's `files`. No file appears twice. No file is omitted.
> 3. **Folder prior.** Files in the same folder belong together by default. Cross a folder boundary only when responsibilities clearly cluster (e.g., a `cli.py` at the root that wires a subpackage).
> 4. **Black-box test.** Each module's `purpose` should let a reader decide "do I need to read this module?" without seeing its file list. If a module's purpose requires hedging ("does X and also Y"), split it.
> 5. **No catch-all.** No module named `misc`, `utils`, or `other`. If something doesn't fit, find or invent a real responsibility for it.
> 6. **Names.** Kebab-case, ≤ 4 words, descriptive. Examples: `workspace-generator`, `pydantic-schemas`, `aws-providers`, `cli-entrypoints`.
>
> If a folder is large and homogeneous (e.g., 80 React components in one folder), treat it as one module — Stage 2b will recurse into it.

## Self-check before returning

The running agent validates the response before proceeding:

- Module count in `[7, 12]` — if not, ask Sonnet to revise with the explicit target count.
- Set of files equals the set in `files.jsonl`.
- No module name collisions; all names kebab-case.

If the response fails, re-prompt Sonnet with the failure reason and the original input.

## Recursion entry

When this stage runs inside a too-big parent module, the inputs are a filtered subset (only that module's files and their folders) and the output lands in `modules/{parent}/modules/{child}/KB.md`. Same rules; same count target (7–12 children when the parent is huge, fewer when modest).
