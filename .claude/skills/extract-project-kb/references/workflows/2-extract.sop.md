# Phase 2: Extract — read each source item and extract structured knowledge

## Goal

Read each classified item fully and extract structured knowledge into per-item
JSON files under `{output_dir}/raw/`. The category schemas below are identical
across modes; only the **read method** differs (Mode A files vs Mode B pages).

## Steps

### 1. Load manifest

Read `{output_dir}/.manifest.json`. Filter to items (Mode A `documents` /
Mode B `pages`) where `extract: true` and `extracted: false`. The per-item id is
`doc_id` (Mode A) or `page_id` (Mode B).

### 2. Group items for parallel processing

Group by category. Launch one agent per group (or per large item) using
`run_in_background: true`.

### 3. Read each item fully

**Mode A — local documents:**

| Type | Method |
|------|--------|
| PDF | `Read` tool — for large PDFs use `pages` param in chunks of 15-20 pages |
| DOCX | `pandoc -f docx -t markdown "{path}"` — full output |
| PPTX | `pandoc -f pptx -t markdown "{path}"` — full output |
| MD/TXT | `Read` tool — full file |

**Mode B — Confluence:** `confluence_get_page(page_id="{page_id}")` for the full
page body (storage/HTML). For long pages, fetch once and process in sections.

If pandoc is unavailable (Mode A):
```bash
python3 -c "
from docx import Document
doc = Document('{path}')
for p in doc.paragraphs:
    print(p.text)
for t in doc.tables:
    for row in t.rows:
        print(' | '.join(c.text for c in row.cells))
"
```

### 4. Extract knowledge by category

For each document, extract into the category-specific schema:

#### architecture
```json
{
  "doc_id": "string",
  "filename": "string",
  "category": "architecture",
  "extracted_at": "ISO timestamp",
  "status": "ok",
  "components": [
    { "name": "string", "type": "service|database|queue|gateway|external", "description": "string", "technology": "string" }
  ],
  "interactions": [
    { "from": "string", "to": "string", "protocol": "string", "description": "string" }
  ],
  "technology_stack": [
    { "layer": "frontend|backend|database|infra|messaging", "technology": "string", "purpose": "string" }
  ],
  "domains": [
    { "name": "string", "description": "string", "bounded_context": "string" }
  ],
  "diagrams": [
    { "type": "component|sequence|deployment|er", "description": "string", "page_or_slide": "string" }
  ]
}
```

#### requirements
```json
{
  "doc_id": "string",
  "filename": "string",
  "category": "requirements",
  "extracted_at": "ISO timestamp",
  "status": "ok",
  "features": [
    { "name": "string", "description": "string", "user_stories": ["string"], "acceptance_criteria": ["string"], "phase": "string" }
  ],
  "business_rules": [
    { "id": "string", "rule": "string", "domain": "string", "source": "string" }
  ],
  "constraints": [
    { "type": "technical|business|regulatory", "description": "string" }
  ]
}
```

#### domain
```json
{
  "doc_id": "string",
  "filename": "string",
  "category": "domain",
  "extracted_at": "ISO timestamp",
  "status": "ok",
  "terms": [
    { "term": "string", "definition": "string", "acronym": "string", "domain": "string" }
  ],
  "business_rules": [
    { "id": "string", "rule": "string", "domain": "string" }
  ],
  "entities": [
    { "name": "string", "description": "string", "attributes": ["string"], "relationships": ["string"] }
  ]
}
```

#### integration / api-docs
```json
{
  "doc_id": "string",
  "filename": "string",
  "category": "integration",
  "extracted_at": "ISO timestamp",
  "status": "ok",
  "integrations": [
    {
      "system": "string",
      "direction": "inbound|outbound|bidirectional",
      "protocol": "REST|SOAP|GraphQL|message-queue|file-transfer",
      "description": "string",
      "endpoints": [
        { "method": "string", "path": "string", "description": "string" }
      ],
      "data_flows": [
        { "from": "string", "to": "string", "payload": "string", "trigger": "string" }
      ],
      "auth": "string",
      "error_handling": "string"
    }
  ]
}
```

#### onboarding
```json
{
  "doc_id": "string",
  "filename": "string",
  "category": "onboarding",
  "extracted_at": "ISO timestamp",
  "status": "ok",
  "project_goals": [
    { "goal": "string", "phase": "string", "success_criteria": "string" }
  ],
  "team_structure": [
    { "role": "string", "responsibility": "string" }
  ],
  "terms": [
    { "term": "string", "definition": "string" }
  ]
}
```

### 5. Write raw extracts

Write each extract to `{output_dir}/raw/{id}.json` (id = `doc_id` in Mode A,
`page_id` in Mode B).

### 6. Update manifest

For each extracted item, set:
- `extracted: true`
- `extracted_at: "ISO timestamp"`
- `raw_file: "raw/{id}.json"`
- `stats: { features: N, business_rules: N, terms: N, ... }`

Update phase status:
```json
"extract": { "status": "completed", "completed_at": "ISO timestamp" }
```

## Extraction guidelines

- **Be precise:** extract what the document says, not what you infer.
- **Preserve terminology:** use the exact terms from the document.
- **Note ambiguity:** if something is unclear, add a `"notes"` field.
- **Cross-reference:** if a document references another, note it in `"references"`.
- **Diagrams:** describe what you see in diagram images — components, arrows, labels.
  PDF diagrams may not be machine-readable; describe the visual layout.

## Exit criteria

- All `extract: true` documents have corresponding `raw/{doc_id}.json` files
- Each raw file is valid JSON matching the category schema
- Manifest updated with extraction status and stats
