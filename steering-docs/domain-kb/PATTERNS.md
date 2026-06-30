# Domain Patterns — append-only journal

Industry and vendor findings discovered during engagement work that are **non-obvious** and **reusable across engagements**. DataArt IP. Project-agnostic.

> **Recording rule.** Append a pattern **only** when the finding is:
> 1. **Non-obvious** — required reading vendor docs, scanning code, or empirical testing to discover, AND
> 2. **Reusable** — would save effort on the next engagement integrating the same vendor or concept, AND
> 3. **Project-agnostic** — describes the vendor / concept itself, not the project's mapping of it.
>
> **Do NOT record** routine answers, glossary lookups, things already obvious from `GLOSSARY.md`/`VENDORS.md`, or anything project-specific (those belong in `../project-kb/`). The agent is not pushed to record after every operation — only when a real, durable finding surfaces.
>
> When a pattern stabilises and is consulted often, promote it into the curated `VENDORS.md` (per-vendor section) or `GLOSSARY.md` (terminology), and delete it from this journal.

## Format

```
## <Short, specific title>
- **Where:** vendor / protocol / concept this applies to
- **What:** one-line description of the finding
- **Detail:** why it matters / what breaks without it / workaround
- **Source:** vendor doc URL, ticket reference, or "empirical"
- **Discovered:** YYYY-MM-DD
```

---

<!-- Agents: append new patterns below this line. Newest at the bottom. -->
