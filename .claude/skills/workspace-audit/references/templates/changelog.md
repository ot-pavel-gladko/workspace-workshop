# Template: Scope changelog (`specs/CHANGELOG.md`)

Use when `GAP-CHANGELOG` is flagged. A scope-level changelog lets agents in
new sessions quickly answer "what's already shipped?" without re-reading all
scope files.

---

```markdown
# Changelog

High-signal summary of every shipped scope, newest first. Each entry links
to the scope file and (if applicable) a release note.

Versioning: `MAJOR.MINOR.PATCH`. Dates UTC.

---

## Unreleased

- (nothing yet)

---

## `0.1.0` — <First milestone name>
**Date:** <YYYY-MM-DD>

- **Shipped:** [01-<topic>](01-<topic>.md), [02-<topic>](02-<topic>.md)
- **Notes:** <one-liner on what the user can now do>
```

---

## Rules

- One entry per shipped scope file (or group of tightly coupled scope files
  shipped together).
- The entry MUST reference scope file names (e.g. `01-scaffold.md`) so the
  orchestrator can match it to the specs tree.
- Keep entries to 1–3 lines. Depth goes in a `RELEASE-NOTES.md` if needed.
- Newest first. Never reorder older entries.
- "Unreleased" section is always at the top. Agents append here when work
  is accepted; maintainer moves to a version block on release.
