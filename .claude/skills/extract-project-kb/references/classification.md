# Classification Rules

Classify each source item (a local document in Mode A, or a Confluence page in
Mode B) into one category, with a priority and optional `secondary_categories`.
The categories are the same in both modes; only the **signals** differ.

## Categories (both modes)

### architecture (Priority 1)
- **Name/title patterns:** "Architecture", "Design", "System Overview",
  "Component Diagram", "Technical/Solution/High-Level Design", "Tech Definition",
  "Infrastructure", "Deployment".
- **Content signals:** component/service diagrams, technology-stack descriptions,
  system interaction flows, data-model diagrams, non-functional requirements.

### domain (Priority 1)
- **Name/title patterns:** "Business Rules", "Domain Model", "Glossary",
  "Terminology", "Business Logic", "Domain Concepts", "Data Dictionary".
- **Content signals:** term definitions and acronyms, business-rule lists, domain
  boundary descriptions, entity relationships, calculation formulas.

### requirements (Priority 1)
- **Name/title patterns:** "Requirements", "Specification", "Feature Spec", "PRD",
  "BRD", "User Stories", "Acceptance Criteria", "Phase …", feature-specific names.
- **Content signals:** user stories / acceptance criteria, feature descriptions
  with expected behavior, wireframe/mockup references, workflow descriptions.

### api-docs (Priority 2)
- **Name/title patterns:** "API", "REST API", "Endpoints", "Swagger", "OpenAPI",
  "Service Contract", "Interface", "Implementation Plan".
- **Content signals:** HTTP method + path descriptions, request/response schemas,
  authentication docs, error-code tables, versioning notes.

### integration (Priority 2)
- **Name/title patterns:** "Integration", "External System", "Third-Party",
  "Connector", specific external-system / vendor names in scope for this project.
- **Content signals:** connection configuration, SOAP/REST protocol details, data
  mapping tables, sequence diagrams showing external calls, error handling.

### onboarding (Priority 3)
- **Name/title patterns:** "Getting Started", "Onboarding", "Overview",
  "Current State", "Project Overview", "Setup Guide", "Discovery", "Phase Results".
- **Content signals:** project goals/objectives, team structure, current-state
  analysis, high-level timelines.
- **Extract:** project goals, domain definitions, system-overview sections.
  **Skip:** IDE/tool setup, team bios, access-request procedures.

### runbook (Priority 4 — Mode B mostly)
- **Title patterns:** "Runbook", "Operational Guide", "Incident Response",
  "Deployment", "Monitoring".
- **Extract only:** integration-related procedures, external-system dependencies.
  **Skip:** step-by-step deploy commands, monitoring-tool configuration.

### skip (No extraction)
- **Name/title patterns:** "Meeting Notes", "Sprint", "Standup", "Demo",
  "Retrospective", "Draft", "Archived", "Deprecated", "Template", personal names.
- **Always skip:** empty/stub items, duplicate content, link-only index pages
  (but follow their links in Mode B), items <1KB, items in Archive/Trash.

## Mode A — local file-type hints

| Extension | Likely category |
|-----------|----------------|
| `.pdf` with "Diagram" in name | architecture |
| `.docx` with "Phase" or "Definition" in name | requirements or architecture |
| `.pptx` with "Discovery" or "Results" in name | onboarding |
| `.xlsx` | domain (data dictionaries) or requirements (feature lists) |

## Mode B — Confluence page hints

- Use the page **title**, **content signals**, and **position in the page tree**.
- Page templates, empty/stub pages, and pages >2 years stale → `skip`.

## Ambiguous / multi-category items

When an item's name/title is ambiguous: read the first ~500 chars (Mode B) or the
first few pages (Mode A), look for the content signals above; if still unclear,
fall back to the parent page's category (Mode B) or the file-type hint (Mode A).
When an item spans categories, classify as the **primary** one and record the rest
in `secondary_categories`; Phase 2 extracts for all applicable categories.
