# Phase 3: Structure — Assemble KB

## Goal

Synthesize all raw extracts into the final KB files. Deduplicate, cross-reference,
and organize into a coherent knowledge base.

## Steps

### 1. Load all raw extracts

Read every `{output_dir}/raw/*.json` file. Build an in-memory index of all
extracted knowledge by type: components, features, integrations, terms,
business rules, etc.

### 2. Deduplicate

- Terms: merge entries with the same term (case-insensitive). Keep the richest definition.
- Features: merge features with the same name across documents. Combine user stories
  and acceptance criteria.
- Integrations: merge by external system name. Combine endpoints and data flows.
- Components: merge by name. Combine technology details.

When merging, note all source documents in a `Sources` field.

### 3. Write DOMAINS.md

```markdown
# Business Domains

## {Domain Name}

**Description:** ...
**Bounded context:** ...
**Key entities:** ...
**Owning repo:** ... (if known)

### Business rules
- BR-001: ...
- BR-002: ...

---
```

Group related components and entities into domains. If the source documents
don't explicitly name domains, infer them from feature groupings and
component boundaries.

### 4. Write FEATURES.md

```markdown
# Feature Catalog

## {Feature Name}

**Phase:** ...
**Description:** ...
**User journey:** ...

### Acceptance criteria
- [ ] ...

### Involved systems
- ...

**Source:** {document name(s)}

---
```

Order features by phase, then by priority.

### 5. Write INTEGRATIONS.md

```markdown
# External Integrations

## {System Name}

**Direction:** inbound / outbound / bidirectional
**Protocol:** REST / SOAP / ...
**Description:** ...

### Endpoints
| Method | Path | Description |
|--------|------|-------------|
| ... | ... | ... |

### Data flows
- ...

### Authentication
...

### Error handling
...

**Source:** {document name(s)}

---
```

### 6. Write GLOSSARY.md

```markdown
# Glossary

| Term | Acronym | Definition | Domain |
|------|---------|------------|--------|
| ... | ... | ... | ... |
```

Sort alphabetically. Include all terms from all extracts after deduplication.

### 7. Write PROJECT_GOALS.md

```markdown
# Project Goals

## Phase {N}: {Phase Name}

**Objectives:**
- ...

**Success criteria:**
- ...

**Timeline:** ... (if known)

---
```

### 8. Write TECH_ARCHITECTURE.md

```markdown
# Technology Architecture

## Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| ... | ... | ... |

## Components

### {Component Name}
**Type:** service / database / gateway / ...
**Technology:** ...
**Description:** ...

## Component Interactions

| From | To | Protocol | Description |
|------|----|----------|-------------|
| ... | ... | ... | ... |

## Diagrams

- {Diagram description} (from: {source document}, page/slide {N})
```

### 9. Update manifest

Set phase status:
```json
"structure": { "status": "completed", "completed_at": "ISO timestamp" }
```

Add summary:
```json
"summary": {
  "domains": N,
  "features": N,
  "integrations": N,
  "glossary_terms": N,
  "source_documents": N,
  "generated_at": "ISO timestamp"
}
```

Add output files list:
```json
"output_files": ["DOMAINS.md", "FEATURES.md", "INTEGRATIONS.md", "GLOSSARY.md", "PROJECT_GOALS.md", "TECH_ARCHITECTURE.md"]
```

### 10. Report

Print a summary table:

```
KB extraction complete:
  Domains:       {N}
  Features:      {N}
  Integrations:  {N}
  Glossary:      {N} terms
  Source docs:    {N}

Output: steering-docs/project-kb/
```

Suggest: `python3 workspace.py generate --agent claude`

## Quality checks

- Every KB file has at least one section with content (no empty files)
- Every entry cites its source document(s)
- No duplicate terms in GLOSSARY.md
- Cross-references between files use consistent naming (e.g. domain names in
  FEATURES.md match those in DOMAINS.md)

## Exit criteria

- All 6 KB files written and non-empty
- Manifest fully updated with summary
- Quality checks pass
