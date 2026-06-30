# Stage 2b — Per-module KB (Sonnet)

For each module produced by Stage 2a, write `modules/{name}/KB.md`. One Sonnet call per module.

## Model

Sonnet. Receives only the file summaries for files inside the module — not the whole repo index.

## Prompt

> You are writing the navigation KB for a single module. An agent will read this *instead of* the source code when it needs to decide whether to descend into this module's files.
>
> Inputs:
>
> - Module name and one-line purpose (from clustering).
> - The Stage-1 summaries for every file in this module.
> - The list of file paths in this module.
> - Optionally, a short list of "sibling modules" (name + one-line purpose) so you can name cross-module dependencies correctly.
>
> Write a markdown document following this exact section order:
>
> ```markdown
> # {module-name}
>
> ## Purpose
>
> {1–3 sentences. What this module is for. Why someone changing code in this module is here.}
>
> ## Public Interface
>
> {List the symbols an outside caller would import or invoke. Group by surface:
> - **Functions / classes** — names with one-line descriptions.
> - **CLI** — command names if any.
> - **HTTP routes** — paths and methods if any.
> - **Config / env** — environment variables or config keys this module owns.
>
> Omit sections that don't apply. Do not list private helpers.}
>
> ## Internal Structure
>
> {Two to five sub-areas if the module has internal seams. For each: name, what it does, anchor file paths. If the module is small, write "Single-file module. See Files below."}
>
> ## Dependencies
>
> {Other modules this one talks to and why. One line each: `- {sibling-module-name} — {reason in 4–10 words}`. Group external deps (third-party, stdlib) into a single trailing bullet if worth mentioning.}
>
> ## Conventions / Gotchas
>
> {Only the non-obvious. Skip if there's nothing to say. Examples: "All public functions are async.", "Settings load order: env > settings.json > defaults.", "Do not import from `legacy/` even though it's still in the tree."}
>
> ## Files
>
> {Flat list of file paths in the module, one per line as a bulleted list. No descriptions — the index lives in files.jsonl.}
> ```
>
> Constraints:
>
> - Target length: 50–250 lines. If you're approaching 300, the module is probably too big and should have been split — note this in a final `> NOTE` line so the running agent can recurse.
> - Do not include code snippets unless a single line illustrates a non-obvious public API.
> - Do not restate what the source code says line by line. Summarize.
> - Use the file paths verbatim from the input.

## Output validation

The running agent checks:

- Document has the required section headings in order.
- `Public Interface`, `Dependencies`, and `Files` sections exist (others may be absent if not applicable, but these three are required).
- File list matches the module's `files` from clustering.
- Length is reasonable (< 300 lines, or a `> NOTE` line flags it for recursion).
