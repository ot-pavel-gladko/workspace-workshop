# Vendor & Integration Know-How

Reusable, project-agnostic facts about suppliers and integration partners. Seeded with protocol-level facts; extend with edge cases, auth flow gotchas, and sandbox-vs-prod gaps as the team learns them.

For project-specific per-supplier mapping (env credentials, queue maps, data model decisions), see `../project-kb/INTEGRATIONS.md`.

---

## How to use this file

When you discover a vendor quirk that any team integrating with the same supplier would also hit, add it here under the relevant section. Examples worth recording:

- Working auth flow (token rotation, scope quirks, certificate setup).
- API version that actually works for a given use case vs. one that looks correct but silently fails.
- Mapping edge cases (field semantics, multi-value handling, currency/timezone pitfalls).
- Sandbox-vs-prod gaps the vendor docs don't mention.
- Recurring "why does this fail?" troubleshooting answers.

Avoid: client business logic, project requirements, env-specific credentials, PII.

---

## `<vendor>`

Add per-vendor sections here. For each vendor include:
- **Protocol** — API style (REST/SOAP/gRPC/WebSocket), auth mechanism.
- **Identity** — how the integration identifies itself (API key, OAuth client, certificate).
- **Key field semantics** — primary booking/record reference, cross-reference fields.
- **Known gotchas** — sandbox-vs-prod differences, rate limits, pagination quirks.
