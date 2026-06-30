# Domain KB

**The third knowledge layer.** Captures specialist expertise that usually lives only in senior engineers' heads: vendor quirks, working auth flows, mapping edge cases, integration gaps.

- **Not project-specific.** No client business logic, no project-specific decisions.
- **Not codebase-specific.** No code from project repositories.
- **Reusable across engagements.** Patterns proven on one integration accelerate the next.

## What goes here

- **Industry concepts** — `<concept>`, `<concept>`, `<concept>`. Vendor-neutral.
- **Vendor know-how** — `<vendor>`, `<vendor>`. Auth flows, working API versions, mapping edge cases, sandbox-vs-prod gaps, certification gotchas.
- **FAQ / troubleshooting** — recurring "why does this fail?" answers a new engineer would otherwise rediscover from scratch.

## What does NOT go here

- No client business logic.
- No project requirements (those live in `project-kb/`).
- No code from client repositories (lives in `code-kb/`).
- No PII, no commercial terms, no environment credentials.

## Ownership & boundary

- **DataArt IP** by structural separation — **vendor-general knowledge only**.
- **Never** put client-specific information, client confidential data, or PII here. Client-specific knowledge is Client IP and lives in `project-kb/` (or `code-kb/`).
- Every addition is **reviewed via the `review-domain-kb` skill by the Domain KB steward** before any domain-kb commit or engagement handoff, to keep this layer clean of client names/branding, client business rules, secrets, and PII.
- Client receives a perpetual, non-exclusive license to use everything here within the engagement workspace.
- DataArt may carry these patterns forward into other engagements.

## Files

- `GLOSSARY.md` — industry-neutral terms for the domain.
- `VENDORS.md` — vendor know-how index. Per-vendor sections seeded with protocol-level facts; extend as the team learns.
- `PATTERNS.md` — append-only journal of non-obvious, reusable, project-agnostic findings.

## How agents use it

- The domain expert agent reads this layer **first**, then falls back to `project-kb/` for project-specific instantiation.
- Business analyst agents consult it for terminology grounding.
- Code agents may reference vendor specifics here when implementing supplier integrations.
