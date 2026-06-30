---
name: extract-project-kb
description: |
  Build a structured project knowledge base in steering-docs/project-kb/ from
  one of two sources: (A) local documents (PDF, DOCX, PPTX, MD, TXT, XLSX) or
  (B) a Confluence space / page tree. Same three-phase pipeline — discover,
  extract, structure — and the same output regardless of source, so downstream
  agents work identically. Produces DOMAINS, FEATURES, INTEGRATIONS, GLOSSARY,
  PROJECT_GOALS, and TECH_ARCHITECTURE.
  Triggers: "build project KB", "extract project knowledge from these documents",
  "build project KB from Confluence", "create the project KB from raw-docs".
license: Proprietary - DataArt Core IP.
metadata:
  category: project-knowledge
  level: "200"
  author: dataart-aila
  version: "1.0.0"
  last_updated: "2026-06-03"
  tags: [project-kb, knowledge-base, extraction, local-docs, confluence, steering-docs]
---

# Extract Project KB v1.0.0

Populate `steering-docs/project-kb/` — the **project-specific** layer of the
three-layer KB (client IP; distinct from `domain-kb` reusable know-how and
`code-kb` codebase indices). Two source modes feed the **same** three-phase
pipeline and the **same** output files:

- **Mode A — Local documents.** A folder of PDF / DOCX / PPTX / MD / TXT / XLSX
  files (e.g. `raw-docs/<project>/`). Discover by filesystem scan; read with the
  Read tool / `pandoc`.
- **Mode B — Confluence.** A Confluence space key or root page URL. Discover by
  crawling the page tree via the Confluence MCP; read with `confluence_get_page`.

Pick the mode from the inputs; the discover and extract phases branch on it, and
the **structure phase is source-agnostic**.

## When to use

- After workspace setup, when `steering-docs/project-kb/` still has TODO stubs.
- When project scope changes and the KB needs a refresh.
- When agents lack business context for cross-repo tasks.

## Inputs

- **Source mode** — `local` or `confluence` (inferred from the inputs below).
- **Source location** — Mode A: a directory path (default `raw-docs/<project>/`);
  Mode B: a `space_key` or root page URL.
- **Output directory** — `steering-docs/project-kb/` (default).
- **Prerequisites** — Mode A: `pandoc` for DOCX/PPTX (falls back to
  `python-docx`/`python-pptx`); PDFs read natively. Mode B: the Confluence MCP
  configured with credentials.

## Core workflow (three phases)

### Phase 1 — Discover
Read and follow `references/workflows/1-discover.sop.md`. Inventory the source
(Mode A: scan the folder; Mode B: crawl the space/page tree), classify each
item per `references/classification.md`, and write `{output_dir}/.manifest.json`.
**Model:** opus (classification judgment). **Checkpoint — stop for user
confirmation** before Phase 2: present the manifest (what will be extracted) and
wait for the go-ahead. This is a mid-run review gate, NOT completion — do not
report the skill "done", and do not mark the project-kb step complete, here:
Phases 2–3 have not run and no KB files exist yet (BUG-0046).

### Phase 2 — Extract
Read and follow `references/workflows/2-extract.sop.md`. Read each item flagged
`extract: true` (Mode A: file readers; Mode B: `confluence_get_page`) and write
per-item structured JSON to `{output_dir}/raw/`. **Model:** sonnet. Parallel:
group by category, one agent per group.

### Phase 3 — Structure
Read and follow `references/workflows/3-structure.sop.md`. Synthesize all raw
extracts (dedupe, cross-reference) into the final KB files. **Model:** opus.
Report the skill complete — and mark the project-kb step done — ONLY after this
phase has written the KB files to `{output_dir}` (3-structure step 10) and the
manifest `structure.status` is `completed`. Never report completion earlier (BUG-0046).
Source-agnostic — identical for both modes.

## Output

```
steering-docs/project-kb/
├── DOMAINS.md            # Business domain map
├── FEATURES.md           # Feature catalog with user journeys
├── INTEGRATIONS.md       # External system integrations
├── GLOSSARY.md           # Domain terminology
├── PROJECT_GOALS.md      # Project objectives and phases
├── TECH_ARCHITECTURE.md  # Technology stack and architecture
├── raw/                  # Per-item JSON extracts
└── .manifest.json        # Source tracking, staleness detection
```

## When to re-run

- New documents/pages added to the source.
- Project scope changed significantly.
- Agents lack business context for cross-repo tasks.

## References

- `references/workflows/1-discover.sop.md`, `2-extract.sop.md`,
  `3-structure.sop.md` — the three phases (Mode A / Mode B inside discover+extract).
- `references/classification.md` — category rules (file-type and Confluence-page signals).
- `references/kb-schema.md` — manifest + output-file schema.

**Related skills** (compose loosely; no file dependency): `extract-domain-kb`
(the domain-kb layer), `extract-code-kb` (the code-kb layer).
