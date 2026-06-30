# Template: Scope file (`specs/NN-<feature>.md`)

Use when rewriting a HOW-coded task/step file into aidlc scope shape.
This is the most important template — it removes H2 (Deliverables), H3
(file-path AC), and H4 (sequential steps) in one pass.

Substitute `<angle-bracket>` placeholders. Layer section headers MUST match
the agent names used in the workspace.

---

```markdown
# TASK-NN: <Feature Name>

**Components:** `<component-1>` [+ `<component-2>`] (the parts of the
system this task touches — e.g. `backend`, `frontend`, `docker`. `/lead`
picks the actual agents to invoke at execution time.)
**Phase:** <N> — <phase name> (optional — drop in kanban-style flows)
**Depends on:** <NN-other-feature> [or "nothing"]

---

## <agent-name-verbatim — e.g. promotions-backend>

### <Subsection — Routes | Entities | Messages | Rules>

<interface definition — table, code sketch, or event shape>

| <Column> | <Column> | <Column> |
|---|---|---|
| <row> | <row> | <row> |

### Rules

- <business rule, declarative>
- <security constraint, declarative>

---

## <second-agent-name-verbatim>

### <Subsection>

…

---

## Acceptance Criteria

- [ ] <happy path — observable behavior testable without reading the body>
- [ ] <auth / permission failure returns correct status>
- [ ] <input validation failure returns correct message>
- [ ] <edge case — empty / duplicate / not-found>
- [ ] <cross-layer integration check>
```

---

## Concrete example (authentication task)

```markdown
# TASK-02: Authentication & Session Management

**Components:** `backend` (API) + `frontend` (UI)
**Phase:** 1 — Foundation
**Depends on:** 01-architecture

---

## backend

### Routes

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/auth/register` | Create user + return session token |
| POST | `/api/auth/login` | Validate credentials + return session token |
| POST | `/api/auth/logout` | Revoke current session |
| GET  | `/api/sessions` | List active sessions for current user |

### Token Strategy

- Generate a random 32-byte token (`secrets.token_urlsafe(32)`)
- Store SHA-256 hash in `Session.token_hash`
- Send raw token in `Set-Cookie: auth_token=<token>; HttpOnly; SameSite=Lax; Path=/`

### Rules

- Never log or return passwords
- `persistent=true` → `Max-Age=30d`; default → session cookie

---

## frontend

### Pages

- `/login` — sign-in form (email + password + "keep me signed in" checkbox)
- `/register` — registration form (email + username + password + confirm)

### Auth State

- `useAuth` hook reads `/api/users/me` on mount; provides `user`, `login()`, `logout()`
- Store nothing in `localStorage`; cookie presence determines auth state

---

## Acceptance Criteria

- [ ] Register with email/username/password succeeds; duplicate email/username returns 422
- [ ] Login sets `HttpOnly` cookie; page refresh preserves session
- [ ] "Keep me signed in" sets 30-day cookie; unchecked = session cookie
- [ ] Logout revokes only current session; other sessions remain valid
- [ ] All protected routes return 401 without valid cookie
```

---

## Rules

- Layer headers MUST match agent names verbatim (the delegation anchor).
  `## angular-web` not `## Frontend`.
- AC items state observable behaviors — not file paths.
  Bad: `Edit src/auth.py`. Good: `POST /api/auth/login returns 200 and sets HttpOnly cookie`.
- No "Deliverables: New files / Modified files" section.
  File inventories belong in PR descriptions, not scope files.
- Scope file count ≠ ticket count. One scope file may cover multiple
  closely coupled tickets.

## Header field rationale

- **Components** describes the parts of the system this scope touches —
  `backend`, `frontend`, `docker`, `infra`, etc. It is **not** an agent
  assignment. `/lead` decides which agents to invoke at execution time
  based on the components, current workspace state, and any unknowns
  surfaced during implementation. Naming components keeps the scope
  file declarative ("what is being changed") and leaves routing to the
  orchestrator. This is the rename from earlier drafts that called
  this field `Agent` — the old name implied an assignment that the
  scope file does not actually control.
- **Phase** is *optional*. In strict greenfield projects with a locked
  overview, phases give `/lead` a sequence to walk. In kanban / iterative
  workflows there is no fixed phase plan — drop the field entirely
  rather than inventing one.
- **Depends on** is the *load-bearing* field. It captures the only
  upstream knowledge a kanban-style executor cannot trivially re-derive.
  Always populate (use `nothing` for foundation tasks).
- **Parallel with** is *not part of this template*. Earlier drafts
  included it, but it overconstrains the implementation: the orchestrator
  decides parallelism based on current workspace load and active
  worktrees, not on scope-time projections. If a strict project genuinely
  needs to declare mutual exclusion, encode it as a `Depends on` (one
  task depends on the other being shipped) rather than as a `Parallel
  with` directive.
