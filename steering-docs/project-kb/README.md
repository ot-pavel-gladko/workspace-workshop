# workspace-workshop — Project Knowledge Base

This directory captures **client-specific knowledge** for workspace-workshop. It is
distinct from the project-agnostic `domain-kb/` (DataArt IP, reusable across engagements)
and the codebase-specific `code-kb/` (extracted from source).

Files in this directory:

- `PROJECT_GOALS.md` — what the engagement is trying to achieve, KPIs, success criteria.
- `DOMAINS.md` — bounded contexts and ubiquitous language inside the product.
- `FEATURES.md` — the product surface area (modules, screens, capabilities).
- `INTEGRATIONS.md` — every third-party and internal system this product talks to.
- `GLOSSARY.md` — project-specific terms and acronyms (client jargon).
- `TECH_ARCHITECTURE.md` — runtime topology, data flow, deployment shape.
- `devops/` — runbooks for CI/CD, environments, branching, deployments.

## Ownership & boundary

- **Client IP**, along with `code-kb/`. Client-specific knowledge — business rules,
  requirements, client/product/system names, confidential information — belongs
  **here**, not in `domain-kb/` (which is DataArt IP and must stay vendor-general).
- When in doubt about where a piece of knowledge belongs, put it here. The Domain
  KB steward reviews domain-kb additions via the `review-domain-kb` skill and
  moves any client-specific content back into this layer.

Agents read this KB via their `resources=` list in `workspace.py`. Keep entries
**short** (paragraphs, not pages); link out to Confluence for long-form context.
