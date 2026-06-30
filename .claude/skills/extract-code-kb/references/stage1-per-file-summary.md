# Stage 1 — Per-file summary (Haiku)

Per-file summarization. Cheap, parallel, embarrassingly cacheable. The running agent dispatches one sub-agent per batch of ~20 files; each sub-agent receives this prompt and the file contents.

## Model

Haiku. Optimize for cost; quality target is "good enough to cluster on", not "good enough to navigate alone".

## Sub-agent prompt

> You are summarizing a single source file for a code-navigation index. The summary will be read by a later stage that decides which module this file belongs to.
>
> For the file below, return a single JSON object (no surrounding prose) with these fields:
>
> - `path` *(string)* — file path exactly as given.
> - `sha256` *(string)* — value provided in the input; copy through.
> - `summary` *(string, 2–5 sentences)* — what this file is for, in plain language. Mention the dominant abstraction (a CLI command, a Pydantic model, a React component, a Terraform module, etc.). Do not list every function.
> - `exports` *(array of strings, ≤ 10)* — names a downstream importer would reach for (public functions, classes, default export). Skip private helpers.
> - `depends_on` *(array of strings, ≤ 10)* — import targets that look meaningful for module boundaries. Prefer internal package paths; collapse stdlib and third-party to a single representative entry each (e.g., `"stdlib"`, `"pydantic"`).
> - `framework_hints` *(array of strings, optional)* — short tags like `"click-cli"`, `"fastapi-route"`, `"pydantic-schema"`, `"react-component"`, `"terraform-module"`, `"pytest-fixture"`. Empty list if nothing distinctive.
>
> Constraints:
>
> - Do not include code snippets in the summary.
> - Do not speculate about behaviour that is not visible in the file.
> - If the file is empty or contains only license headers, set `summary: "Empty or license-only."` and leave the other lists empty.
> - Return *only* the JSON object. No commentary, no markdown fence.

## Batching

Send up to 20 files per sub-agent call. Bigger batches risk truncation; smaller batches waste handshake overhead.

## Caching

Before dispatching, compute `sha256` over the file contents. If `_index/files.jsonl` already has a record with matching `(path, sha256)`, skip the file. After dispatch, merge new records into `files.jsonl`; remove records whose paths no longer exist on disk.

## Output validation

After all batches return:

- Every discovered source file has exactly one record.
- Every record's `summary` is non-empty (or is the explicit "Empty or license-only." sentinel).
- `path` values are unique.
- File records are written one JSON object per line (JSONL).
