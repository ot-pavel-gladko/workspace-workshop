# KB Output Schema

## Directory Layout

```
steering-docs/project-kb/
├── DOMAINS.md            # Business domain map
├── FEATURES.md           # Feature catalog with user journeys
├── INTEGRATIONS.md       # External system integrations
├── GLOSSARY.md           # Domain terminology
├── PROJECT_GOALS.md      # Project objectives and phases
├── TECH_ARCHITECTURE.md  # Technology stack and architecture
├── raw/                  # Per-document JSON extracts
│   ├── {doc_id}.json
│   └── ...
└── .manifest.json        # Source tracking
```

## .manifest.json Schema

```json
{
  "version": "1.0.0",
  "source_type": "local",
  "source_dir": "raw-docs/<project>",
  "created_at": "2026-05-14T10:00:00Z",
  "last_updated": "2026-05-14T12:30:00Z",
  "phases": {
    "discover": { "status": "completed", "completed_at": "ISO timestamp" },
    "extract": { "status": "completed", "completed_at": "ISO timestamp" },
    "structure": { "status": "completed", "completed_at": "ISO timestamp" }
  },
  "documents": [
    {
      "doc_id": "phase-1-tech-definition",
      "filename": "Phase 1 - tech definition.docx",
      "path": "raw-docs/<project>/Phase 1 - tech definition.docx",
      "extension": "docx",
      "category": "architecture",
      "secondary_categories": ["requirements"],
      "priority": 1,
      "extract": true,
      "extracted": true,
      "extracted_at": "ISO timestamp",
      "raw_file": "raw/phase-1-tech-definition.json",
      "stats": { "features": 5, "business_rules": 2, "terms": 10 }
    }
  ],
  "total_documents": 6,
  "documents_to_extract": 5,
  "output_files": ["DOMAINS.md", "FEATURES.md", "INTEGRATIONS.md", "GLOSSARY.md", "PROJECT_GOALS.md", "TECH_ARCHITECTURE.md"],
  "summary": {
    "domains": 4,
    "features": 12,
    "integrations": 3,
    "glossary_terms": 30,
    "source_documents": 5,
    "generated_at": "ISO timestamp"
  }
}
```

## Source variants

`source_type` is `"local"` or `"confluence"`.

- **Mode A (local):** top-level `source_dir`; the item array is `documents` with
  `doc_id` / `filename` / `path` / `extension`.
- **Mode B (confluence):** top-level `space_key` (or `root_page_url`); the item
  array is `pages` with `page_id` / `title` / `url` / `parent_id`. Counts are
  `total_pages` / `pages_to_extract`.

Both share `category`, `secondary_categories`, `priority`, `extract`, `extracted`,
`raw_file`, and `stats`. The output files and structure phase are identical.

## Raw Extract Schema (per item)

Each `raw/{doc_id}.json` contains extracted knowledge specific to the document
category. See Phase 2 SOP for category-specific schemas.

Common fields across all categories:

```json
{
  "doc_id": "string",
  "filename": "string",
  "path": "string",
  "category": "architecture|requirements|api-docs|integration|domain|onboarding",
  "extracted_at": "ISO timestamp",
  "status": "ok|error"
}
```

## Staleness Detection

The manifest tracks `last_updated` timestamps. To detect stale KB:
- Compare `summary.generated_at` with current date
- If >30 days old, suggest re-running the skill
- Compare file modification times of source documents against extraction timestamps
