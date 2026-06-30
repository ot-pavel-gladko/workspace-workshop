# Phase 1: Discover — inventory the source and classify

## Execution
- **Model:** `opus` — classification needs judgment on ambiguous names/titles.
- **Processing:** sequential, single agent. **Stop for user confirmation** before Phase 2.

## Goal
Inventory the source, classify each item per `references/classification.md`, and
write `{output_dir}/.manifest.json` (default `{output_dir}` = `steering-docs/project-kb/`).
Run **Mode A** or **Mode B** depending on the source; both produce the same manifest
shape (with `source_type`).

```bash
mkdir -p {output_dir}/raw
```

---

## Mode A — Local documents

**Input:** a source directory (e.g. `raw-docs/<project>/`).

1. **Scan the directory:**
   ```bash
   find {source_dir} -type f \( -name "*.pdf" -o -name "*.docx" -o -name "*.pptx" -o -name "*.md" -o -name "*.txt" -o -name "*.xlsx" \) | sort
   ```
   Record path, filename, extension, size for each file.
2. **Generate `doc_id`** by slugifying the filename (lowercase, hyphenate, strip ext):
   `Phase 1 - tech definition.docx` → `phase-1-tech-definition`.
3. **Quick-read to classify:** PDF → `Read` tool `pages:"1-3"`; DOCX/PPTX →
   `pandoc -f {fmt} -t markdown "{path}"` (first ~200 lines; fall back to
   `python-docx`/`python-pptx`); MD/TXT → `Read` first ~100 lines.
4. **Classify** each per `references/classification.md` → `category`, `priority`,
   `secondary_categories`.
5. Go to **Confirm + finalize** below.

Manifest item shape (Mode A):
```json
{ "doc_id": "phase-1-tech-definition", "filename": "Phase 1 - tech definition.docx",
  "path": "raw-docs/<project>/Phase 1 - tech definition.docx", "extension": "docx",
  "category": "architecture", "secondary_categories": ["requirements"],
  "priority": 1, "extract": true, "extracted": false }
```

---

## Mode B — Confluence space / page tree

**Input:** a `space_key` or a root page URL. Requires the Confluence MCP.

1. **Search the space:** `confluence_search(query="space:{space_key} type:page", limit=100)`.
   If given a root page URL: extract the page id, `confluence_get_page` it, then
   traverse with `confluence_get_page_children` (or follow child links).
   Collect `page_id`, `title`, `url`, `parent_id`.
2. **Classify** each page per `references/classification.md` (title + content
   signals + tree position) → `category`, `priority`, `secondary_categories`.
3. Go to **Confirm + finalize** below.

Manifest item shape (Mode B):
```json
{ "page_id": "123456", "title": "Architecture Overview",
  "url": "https://confluence.example.com/pages/123456", "parent_id": "100000",
  "category": "architecture", "priority": 1, "extract": true, "extracted": false }
```

> Error handling: if search returns 0 results, broaden terms or ask for another
> space/page; if a page fetch fails, log and continue (don't abort); if >200 pages,
> warn and suggest narrowing to a root page.

---

## Confirm + finalize (both modes)

1. **Preview** the classified inventory grouped by category with counts, e.g.:
   ```
   architecture (5) — extract   requirements (12) — extract   ...   skip (11)
   Total to extract: 36.  Proceed? [Y/n]
   ```
   If the user declines, let them reclassify items or exclude categories.
2. **Write `{output_dir}/.manifest.json`** per `references/kb-schema.md`:
   set `source_type` (`local`/`confluence`), the item array (`documents` or `pages`),
   `total_*` and `*_to_extract` counts, and `phases.discover.status = "completed"`.

## Exit criteria
- `.manifest.json` exists and is valid JSON, with the classification user-confirmed.
- `phases.discover.status` is `completed`.
