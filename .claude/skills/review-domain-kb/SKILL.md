---
name: review-domain-kb
description: |
  Audit steering-docs/domain-kb/ before commits or engagement handoffs so the
  DataArt-owned domain knowledge stays vendor-general: no client names/branding,
  no client-specific business rules or requirements, no client confidential
  information, no credentials/secrets, no PII. Builds a client-term lexicon from
  the Client-IP project-kb, scans every domain-kb file, then classifies each
  finding as MOVE, REDACT, or GENERALIZE.
  Triggers: "review domain kb", "audit domain-kb before commit", "check domain-kb
  for client info / PII", "is domain-kb vendor-general", "gate the domain-kb
  handoff".
license: Proprietary - DataArt Core IP.
metadata:
  category: governance
  level: "201"
  author: dataart-aila
  version: "1.0.0"
  last_updated: "2026-06-10"
  tags: [domain-kb, governance, ip-boundary, pii, review, steering-docs]
---

# Review Domain KB v1.0.0

Gate everything that enters `steering-docs/domain-kb/` so DataArt-owned knowledge
stays **vendor-general**. The workspace `steering-docs/` split *is* the IP
boundary: `project-kb/` + `code-kb/` are **Client IP**; `domain-kb/` plus the
workspace framework are **DataArt IP** (the client keeps a free, perpetual,
non-exclusive internal-use license). To keep that boundary clean, this skill
audits domain-kb for any content that should never live in DataArt-owned
knowledge.

Run this **before** any domain-kb commit and **before** any engagement handoff.

## Purpose

Confirm that no domain-kb file contains:

- **Client identity** — client names, brand names, product names, internal
  system/codenames, repo names, team names.
- **Client-specific business rules or requirements** — "the client requires…",
  ticket IDs, engagement-specific decisions, SLAs negotiated for this project.
- **Client confidential information** — commercial terms, pricing, contracts,
  roadmaps, anything marked confidential.
- **Credentials / secrets** — tokens, API keys, passwords, connection strings,
  private/internal URLs and hostnames.
- **PII** — emails, phone numbers, person names in examples, postal addresses,
  account/customer IDs.

Anything found is **not** vendor-general and must be moved, redacted, or
generalized before the content can stay in domain-kb.

## Inputs

- **Workspace root** (required) — the directory containing `steering-docs/`.
- **Change set** (optional) — a diff or list of changed domain-kb files
  (e.g. `git diff --name-only` filtered to `steering-docs/domain-kb/`). When
  provided, scope the scan to those files; otherwise scan all of `domain-kb/`.

## Procedure

### Step 1 — Build the client-term lexicon

Domain-kb is judged *relative to* this engagement's Client IP. Build a lexicon of
client/project-specific terms from the Client-IP sources, then treat any of those
terms appearing in domain-kb as a finding.

Read and harvest terms from:

- `steering-docs/project-kb/GLOSSARY.md` — client jargon, acronyms.
- `steering-docs/project-kb/PROJECT_GOALS.md` — engagement, client, product names.
- `steering-docs/project-kb/DOMAINS.md` — bounded contexts, ubiquitous language.
- `steering-docs/project-kb/INTEGRATIONS.md` — internal system names, environments.
- `steering-docs/project-kb/FEATURES.md` and `TECH_ARCHITECTURE.md` — service /
  component / module names.
- `workspace-profile.yaml` (or `.aila/` profile) — project name, description.
- Repo names (from the profile's repo list or the workspace's repos).

Collect: project/client name(s), product names, internal system names, service
and component names, environment names, team names, and any distinctive
client-coined term. De-duplicate and drop generic words that are also legitimate
vendor/industry terms (judge by context, not the raw token).

### Step 2 — Scan every in-scope domain-kb file

For each file, scan for:

1. **Lexicon hits** — any client-term from Step 1. Record file + line + excerpt.
2. **PII patterns**
   - emails (`[\w.+-]+@[\w-]+\.[\w.-]+`),
   - phone numbers,
   - postal/street addresses,
   - person names used in examples (real-looking first/last names, not
     `Alice`/`Bob`/`<user>` placeholders),
   - account / customer / order IDs.
3. **Secrets patterns**
   - API tokens / keys (`AKIA…`, `ghp_…`, `xox[bap]-…`, long base64/hex blobs),
   - passwords, `Authorization:` header values,
   - connection strings (`postgres://…`, `mongodb://…`, JDBC URLs with creds),
   - internal/private URLs and hostnames (`*.internal`, VPN/intranet hosts,
     non-public IPs `10.`, `192.168.`, `172.16–31.`).
4. **Client-specific requirements masquerading as vendor patterns**
   - phrases like "the client requires…", "per <ClientName>…", "as agreed for
     this project…",
   - ticket IDs (`PROJ-1234`, `JIRA-…`),
   - internal team / Slack-channel / wiki-space references,
   - decisions that only make sense inside this engagement.

Provenance comments (`<!-- Source: … -->`) and scrape attribution that point to
**vendor public docs** are fine; flag only those that point to client-internal
sources.

### Step 3 — Classify each finding

| Classification | When | Suggested action |
|----------------|------|------------------|
| **MOVE** | Genuine, useful knowledge that is *client-specific* (a project business rule, an internal-system integration detail). | Relocate to `steering-docs/project-kb/` (or `code-kb/` if it's codebase-specific). It is Client IP, not DataArt IP. |
| **REDACT** | PII or a secret. No reuse value; carries risk. | Remove entirely. Replace with a neutral placeholder (`<email>`, `<api-token>`, `https://api.<vendor>.com`) if an example is still needed. |
| **GENERALIZE** | A valid vendor/industry pattern that got contaminated with client specifics. | Rewrite vendor-general: strip the client name/IDs/values, keep the reusable pattern. |

## Output

1. **Findings report** — for every hit: `file` + `line` + `excerpt` +
   `classification` (MOVE / REDACT / GENERALIZE) + `suggested action`. Group by
   classification and lead with a one-line verdict (CLEAN / FINDINGS: N). If the
   scan was scoped to a change set, say so.
2. **Apply changes — only after the user approves.** Do not mutate files in the
   scan pass. Once approved:
   - MOVE: cut the content into the correct project-kb/code-kb file (create or
     append), and remove it from domain-kb.
   - REDACT: delete the offending text (or swap in a placeholder).
   - GENERALIZE: rewrite the passage vendor-general in place.
   Re-run Step 2 on the touched files to confirm the findings are resolved.

A clean run (no findings) means domain-kb is safe to commit / hand off.

## Boundary rules

The `steering-docs/` split is the contractual IP boundary:

- **`project-kb/` + `code-kb/` = Client IP.** Client-specific knowledge,
  business rules, requirements, and codebase indices belong here.
- **`domain-kb/` + the workspace framework = DataArt IP.** Vendor-general,
  reusable industry/vendor know-how only. The client receives a free, perpetual,
  non-exclusive internal-use license to it; DataArt may carry these patterns
  forward into other engagements.

**When in doubt, put it in project-kb.** It is always safe to classify content as
Client IP; the unsafe failure mode is letting client-specific or confidential
information leak into DataArt-owned domain-kb. The cost of an over-broad MOVE is
trivial; the cost of a missed leak is an IP-boundary breach.

## Quality checklist

- [ ] Lexicon built from every available project-kb source + the profile.
- [ ] Every in-scope domain-kb file scanned for lexicon / PII / secrets /
      client-requirement patterns.
- [ ] Each finding classified MOVE / REDACT / GENERALIZE with a suggested action.
- [ ] No file mutated before user approval.
- [ ] Post-apply re-scan confirms findings resolved.
- [ ] Verdict (CLEAN / FINDINGS: N) stated up front.

## References

- **Workspace I/O:** `steering-docs/project-kb/*` (Client-IP lexicon source) and
  `steering-docs/domain-kb/*` (the audited target).
- **Role:** the **Domain KB steward** owns this review and runs this skill before
  every domain-kb commit or handoff.
- **Related skills** (compose loosely; no file dependency): `extract-domain-kb`
  (populates domain-kb — run this review after it), `extract-project-kb` /
  `extract-code-kb` (the Client-IP layers that MOVE findings land in),
  `workspace-audit` (broader workspace structure review).
