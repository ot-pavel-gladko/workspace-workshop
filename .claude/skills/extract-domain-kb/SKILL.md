---
name: extract-domain-kb
description: |
  Extract project-agnostic domain knowledge into a workspace's
  steering-docs/domain-kb/ directory. Two source modes: (A) a local shared
  knowledge base on disk — filter for project-relevant content and adapt; or
  (B) external vendor developer portals — discover a machine-readable spec,
  scrape verbatim, then distil. Writes GLOSSARY.md, VENDORS.md, PATTERNS.md,
  and one prose file per vendor.
  Triggers: "extract domain kb", "enrich domain-kb from <source>", "pull domain
  knowledge", "scrape <vendor> docs into domain-kb".
license: Proprietary - DataArt Core IP.
metadata:
  category: documentation
  level: "200"
  author: dataart-aila
  version: "1.0.0"
  last_updated: "2026-06-02"
  tags: [domain-kb, knowledge-extraction, vendor-docs, openapi, steering-docs]
---

# Extract Domain KB v1.0.0

Populate `steering-docs/domain-kb/` — the **project-agnostic** layer of the
three-layer KB (reusable industry/vendor know-how, distinct from project-kb
client IP and code-kb codebase indices). Two source modes write into the same
target structure:

- **A. Local KB source** — a shared domain knowledge base on disk. Filter for
  project-relevant content and adapt.
- **B. External vendor docs** — a vendor's public developer portal. Discover a
  machine-readable spec, scrape verbatim, then distil.

## When to use

- After workspace setup, when `domain-kb/` still has TODO-stub files.
- When a source KB gains new patterns/vendor docs relevant to the project.
- When adding an integration that needs domain context.
- When a vendor's public docs are needed and the internal KB doesn't cover them.

## Inputs

- **Source mode** — `local-kb` or `external-docs`.
- **Source location** — a directory path (`local-kb`) or the vendor docs URL
  (`external-docs`).
- **Relevance filter** — which vendors, APIs, and domain areas are in scope,
  derived from `steering-docs/project-kb/INTEGRATIONS.md` and `DOMAINS.md`.
- **Output directory** — `steering-docs/domain-kb/` (default).

## Mode A — local KB source

### Phase 1 — Discover relevant content
Read the source KB index, then read `project-kb/INTEGRATIONS.md` and
`DOMAINS.md` to identify in-scope vendors, protocols, and domain concepts. Build
a relevance map scoring each source file (vendor match, protocol match, domain
match, pattern applicability) and present it grouped High / Medium / Low for the
user to confirm before extracting.

### Phase 2 — Extract and adapt
For each high-relevance file: keep the in-scope API endpoints, auth patterns,
request/response shapes, applicable patterns, and glossary terms; drop
capabilities not used by this project. **Do not copy verbatim** — adapt,
summarise, and restructure for this project's context.

### Phase 3 — Write domain-kb files
| File | Content |
|------|---------|
| `GLOSSARY.md` | Industry terms relevant to this project. |
| `VENDORS.md` | Vendor reference — endpoints, auth, capabilities. |
| `<VENDOR>.md` | Per-vendor API patterns, auth variants, lifecycle, pitfalls. |
| `PATTERNS.md` | Reusable integration patterns (append-only; preserve header). |

Rules: merge, don't overwrite; add a `<!-- Source: <path> -->` provenance
comment; keep each file under ~300 lines (split a large vendor section into its
own file); end each vendor file with a **project-operation → vendor-endpoint**
mapping table (the agent-facing index).

## Mode B — external vendor docs

Most modern vendor docs are JavaScript-rendered SPAs, so naive HTML fetching
returns empty shells. **Do not start by scraping pages** — find the API the docs
site itself queries.

### Phase 1 — Reconnaissance (in order)
1. **One WebFetch on the docs root.** Inspect raw HTML for `__NEXT_DATA__`
   (Next.js), `__INITIAL_STATE__` / `__APOLLO_STATE__` (React/Apollo), framework
   markers (`readme.io`, `stoplight.io`, `redoc`, `swagger-ui`), or direct links
   to `openapi.json` / `swagger.json` / `postman_collection.json`.
2. **Hunt for an OpenAPI/Swagger/Postman spec** by convention: `{root}/openapi.json`,
   `{root}/openapi.yaml`, `{root}/swagger.json`, `{root}/api/spec`,
   `{root}/reference/{api}.openapi.json`, or the vendor's GitHub.
3. **Look for a GraphQL endpoint that returns the spec.** ReadMe.io/Stoplight
   often expose one to bootstrap the SPA. Try `{root}/api/graphql` with known
   operation names (`getPublicSpec`, `getApiDefinition`, `getOpenApi`, `getSpec`).
   *Illustrative:* some portals return a full OpenAPI spec from a single
   no-auth GraphQL `getPublicSpec` query — worth checking before any scraping.
4. **Per-page JS chunks.** If 1–3 fail, page MDX is bundled into
   `_next/static/chunks/pages/<route>.js`; curl and search for inlined strings.
5. **Headless browser (last resort)** — only if 1–4 fail and Playwright/Puppeteer
   is already available. Don't install heavyweight tooling just for this.

### Phase 2 — Extract verbatim
Write raw scraped content under `steering-docs/domain-kb/<vendor>/` (verbatim
artefacts live beside the prose summary). **Verbatim is the goal** — preserve
example payloads, error envelopes, schema tables, and headers
character-for-character; adaptation comes in Phase 3. Layout:

```
steering-docs/domain-kb/<vendor>/
├── openapi.json            # full machine-readable spec, if found
├── 01-getting-started.md   # one file per docs section
├── 02-authorization.md
└── 03-<resource-tag>.md
```

Each section file starts with a provenance block:

```markdown
> Scraped from <vendor-docs-url> on <YYYY-MM-DD>.
> Method: <GraphQL getPublicSpec | OpenAPI | MDX chunks | curl | ...>
```

Commit machine-readable specs in-workspace (1–5 MB is fine for git; use git-LFS
only above ~50 MB).

### Phase 3 — Adapt into `<VENDOR>.md`
Same rules as Mode A, plus: one file per major vendor (authentication variants,
key endpoints, lifecycle/flow, decision points, conventions, pitfalls); keep
~300 lines and link the verbatim section files + spec for the long tail; end
with the project-operation → endpoint table; preserve `<!-- Source: ... -->`
provenance including the verbatim path(s) and spec path.

## Vendor spec bundles (raw schema downloads)

When the user drops raw vendor artefacts (WSDL/XSD/OpenAPI) into the workspace:
place each method bundle under `domain-kb/<vendor>/<MethodName>-v<X_Y_Z>/` as
loose files (flat — no per-method KB.md); co-locate sample payloads and the spec;
treat them as **domain knowledge, not code-kb**; update the vendor prose file
with endpoint, headers, wire root element, request highlights, and the bundle
path; and capture any name-vs-wire divergences explicitly.

## Per-vendor playbooks

After a vendor's first extraction, append a short playbook to its `<VENDOR>.md`
(or a sibling notes file): the method that worked (spec URL / GraphQL op),
sections already scraped, sections deferred (with the trigger to extract them),
and known gotchas (error-envelope shapes, token TTLs, pagination model, filter
grammar, regional hosts). This turns the next run into a `jq` over the cached
spec instead of a re-scrape.

## Quality checklist

- [ ] Every vendor in `INTEGRATIONS.md` has domain-kb coverage.
- [ ] Auth patterns for each API variant are documented.
- [ ] Glossary covers terms used in project-kb but not defined there.
- [ ] No out-of-scope vendor capabilities leaked in.
- [ ] Source-attribution comments present for adapted content.
- [ ] Each file under ~300 lines.
- [ ] (external-docs) verbatim scrape preserved under `domain-kb/<vendor>/`.
- [ ] (external-docs) machine-readable spec cached if discovered.
- [ ] (external-docs) vendor file ends with the project-operation → endpoint table.

## References

- **Workspace I/O:** `steering-docs/project-kb/INTEGRATIONS.md` and `DOMAINS.md`
  (the relevance filter) → `steering-docs/domain-kb/` (the output).
- **Related skills** (compose loosely; no file dependency): `extract-code-kb`
  (code-kb counterpart), `extract-project-kb` (populates the project-kb layer
  from local docs or Confluence).
