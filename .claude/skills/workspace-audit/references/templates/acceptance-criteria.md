# Template: Acceptance Criteria block

Use when:
- `GAP-AC` is flagged — scope file has no Acceptance Criteria section
- `FLAG-AC-NOT-BEHAVIOR` is flagged — AC items are file-path-keyed rather
  than behavior-based

Append to (or replace the AC section in) the scope file.

---

```markdown
## Acceptance Criteria

- [ ] <Happy path — observable behavior with expected outcome>
- [ ] <Auth / permission failure returns correct HTTP status>
- [ ] <Input validation failure returns correct message>
- [ ] <Edge case — empty / duplicate / not-found>
- [ ] <Cross-layer contract — e.g. "WS event X received by client renders Y">
```

---

## Progress tracking via checkboxes

AC items use `[ ]` / `[x]` checkboxes intentionally. The orchestrator
(`/lead` or equivalent) flips items from `[ ]` to `[x]` as each is
satisfied during implementation, turning the scope file into a live
progress board.

This is a positive workspace practice — see `PRACTICE-AC-PROGRESS` in
`01-classification-heuristics.md`. If your team treats AC checkboxes as
read-only "definition of done" only, consider adopting the live-update
pattern: it gives reviewers a single place to see what's left without
chasing the chat transcript.

If your QA/BA process explicitly forbids editing AC after sign-off, keep
`[ ]` static and track progress in CHANGELOG.md instead.

---

## Behavior-arrow notation

Every AC item should be testable by reading the line alone — no need to
read the body. Preferred forms:

| Pattern | Example |
|---|---|
| `<action> → <observable outcome>` | `Join public room → user added as member, room appears in sidebar` |
| `<input> returns <status/message>` | `POST /api/auth/login with wrong password returns 401` |
| `<condition> renders/displays <thing>` | `Unread badge count > 0 displays notification dot on room icon` |
| `<boundary condition> succeeds/fails` | `Uploading file > 10 MB returns 413 with detail "File too large"` |

---

## AC ↔ test mapping: two modes

How tightly QA tests should map back to AC items depends on project
maturity:

| Mode | AC ↔ test relationship | When |
|---|---|---|
| **Prototype / hackathon** | QA agent has creative latitude — derives valuable tests from implementation, AC is the floor not the ceiling | Early scope, exploratory work, scope still moving |
| **Stable / post-release** | Strict 1:1 — every AC item maps to ≥ 1 test; test plan is templated output of the QA agent | Stabilization, regression coverage, audit prep |

The audit does **not** force prototype workspaces into strict mode. If you
see a workspace whose QA prompt encourages creative test selection and the
scope is iteratively grown, do not flag missing 1:1 AC↔test mappings as a
gap. Recommend the strict mode only after the workspace shows
stability signals: locked overview, steady CHANGELOG cadence, no recent
post-hoc scope additions.

A useful two-step adoption: run prototype mode during build-out, then run
a milestone review where /lead + /qa walk every AC and flip checkboxes
(see `PRACTICE-AC-PROGRESS`). Strict mapping kicks in for new scope after
that milestone.

---

## Coverage heuristic

At minimum, one AC per:
- Happy path (the golden path)
- Auth / permission failure
- Input validation failure
- Edge case (empty list, duplicate, not-found)
- Cross-layer integration (if the feature spans multiple agents)

5–8 items covers most features. If you need more, the scope file is
probably too large — split it.

---

## What NOT to write

| Bad (HOW) | Good (WHAT) |
|---|---|
| `- [ ] Edit models.py line 47` | `- [ ] Room created via POST /api/rooms appears in GET /api/rooms` |
| `- [ ] Create src/auth/middleware.ts` | `- [ ] 401 returned on any protected route without valid cookie` |
| `- [ ] Run alembic migration` | `- [ ] Database schema includes rooms table after migration` |
