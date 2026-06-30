# Classification Heuristics — WHAT vs HOW signal catalog

Full pattern catalog for classifying agent / scope / task files.

## WHAT signals (+ one point each)

### W1. Role-identity phrasing
Regex (case-insensitive): `\b(You are|You own|Your role is|You act as)\b`

Examples:
- `You are the **Backend Expert** for a hackathon.`
- `You are the expert for the **angular-web** codebase`

### W2. Ownership / boundary declaration
Regex: `\b(owns?|delegate\s+to|Scope\s*&?\s*Boundaries|does NOT own)\b`

Examples:
- `You own: All TypeScript/Angular code under jsx-angular-web/`
- `Delegate to: azure-functions — for backend middleware questions`

`does NOT own` is a strong WHAT signal — explicit non-ownership boundary.

### W3. Contract sections
Match section headers (`^##?\s+`) containing:
`API Surface`, `Route(s)?|Routes table|Endpoints?`, `Data Model|Entities`,
`Tech Stack|Stack`, `WebSocket Protocol|Event Protocol`, `Component Map`,
`Environment Variables`, `Acceptance Criteria`

These headers describe *interfaces*, not *implementation sequences*.

### W4. Behavior-arrow acceptance criteria
Regex: `^-?\s*\[[\sx✓]?\]\s+.+→.+$`

Examples (aidlc `02-auth.md`):
- `- [x] Register with email/username/password succeeds; duplicate email/username returns 422`
- `- [x] Login sets HttpOnly cookie; page refresh preserves session`

Any AC item using `→` (Unicode arrow) or stating an observable outcome
(`returns <status>`, `renders <component>`, `emits <event>`, `sets <header>`)
counts.

### W5. Reference pointers (contract-framing)
Regex: `\b(Read|Reference|See)\s+[`\w/.-]+\s+(before|for contract|as spec)\b`

Examples:
- `Read design/detailed-design.md before implementing`
- `See glossary for business rule definitions`

The key signal: the reference is *contract-framing* (consulted before, not as
a navigation step during execution).

### W6. Interface tables without file paths
Markdown tables where rows describe:
- Routes: `METHOD | PATH | REQUEST | RESPONSE`
- Components: `Name | Props | Events`
- Entities: `Field | Type | Constraints`

Detection: markdown table with header row containing none of
`file|path|line|location|src/|.py|.ts|.cs|.tsx`.

### W7. Delegation clause with explicit non-ownership
Regex: `\bdoes NOT own\b.*\(see\s+[`\w-]+\)`

Example (workspace-myproj `promotions-backend.md`):
- `Does NOT own the admin UI (see promotions-frontend)`

Strong signal — forces delegation clarity.

---

## Informational tags (do not affect classification)

These tags are recorded on a file for context but do **not** count as WHAT
or HOW signals and never trigger a rewrite proposal on their own.

### INFO-NAVIGATION
A clearly delimited "Code Navigation Protocol" section in an agent prompt
that prescribes how to look up code (read JSON metadata, open file at exact
line). Defensible micro-HOW for *comprehension*, not *execution*.

### INFO-STACK-DUPLICATION
The same stack/version block appears in `CLAUDE.md` and one or more agent
prompts (Python version, Node version, Postgres version, port mappings,
docker-compose service list, project layout tree).

This is **intentional** for workspaces where each agent runs in an isolated
sub-context and benefits from having stack pinned in its own prompt rather
than triggering an extra read. Do not flag as drift, do not propose
de-duplication.

The one case worth noting (advisory only, not a gap): if the same value
disagrees across files (e.g., CLAUDE.md says PG18, `/backend` says PG16),
record it as `FLAG-STACK-DRIFT` on the agent file with the stale value, and
recommend updating the stale copy — not consolidating to a single source.

### INFO-INLINE-FIXTURE
An agent prompt inlines a canonical code fixture (e.g., `conftest.py`,
`vite.config.ts`, `playwright.config.ts`, `test-setup.ts`) that also exists
elsewhere in the repo.

Do **not** flag as duplication. Inlining configuration that the human
operator must read alongside agent guidance keeps agent prompts
self-contained and reviewable. Threshold: up to ~120 inline lines per
fixture in a human-edited agent prompt is acceptable.

Only consider rewriting when the inline fixture *contradicts* the in-repo
file — that's a `FLAG-FIXTURE-DRIFT`, not duplication.

---

## HOW signals (− one point each)

### H1. File-navigation imperatives
Regex (case-insensitive):
```
\b(read|open|grep)\s+[`\w/.-]+\s+(at\s+line\s+\d+|first|before\s+searching)\b
```
Also match phrases:
- `exact path and line number`
- `find the function/class in the JSON metadata`
- `Only use grep/glob as a fallback`

Examples (workspace-myproj `angular-web.md` lines 61–68):
- `ALWAYS read KNOW.md first before searching or grepping`
- `Find the function/class in the JSON metadata (has exact path and line)`
- `Open the file directly at the exact path and line number`

**Special handling:** if these appear in a clearly delimited "Code Navigation
Protocol" section (header match), tag as `INFO-NAVIGATION` rather than HOW.
This pattern is defensible when scoped to *comprehension*, not *execution*.

### H2. Deliverables section with file inventories
Regex (case-insensitive):
```
^##?\s+Deliverables?\s*$
```
Followed within 30 lines by:
```
\*\*(New files?|Modified files?|Deleted files?|Files created)\*\*
```

Example (workspace-myproj `myproj-feature-area/tasks/step-01-scaffold-and-schema.md`
lines 54–73):
```
**New files**
- `JSX.Domain/Entities/` — `Promotion.cs`, `NavitairePromotion.cs`, ...
**Modified files**
- All five csproj files — added EF Core 10.0.0 packages
```

Strongest HOW signal. A scope file that enumerates file paths as
deliverables has drifted into commit-log shape.

### H3. AC items keyed by file path
Regex:
```
^-?\s*\[[\sx✓]?\]\s*(Create|Edit|Modify|Add|Remove|Delete)\s+.*[/\\][\w.-]+\.(cs|py|ts|tsx|js|jsx|yaml|yml|json|md)\b
```

Example:
- `- [x] Create JSX.Domain/Entities/Promotion.cs`
- `- [ ] Edit src/auth/middleware.py to add session check`

File-path-keyed AC = HOW. Rewrite as behavior-arrow AC.

### H4. Sequential step imperatives tied to file outputs
Regex:
```
^Step\s+\d+:\s+.*(edit|add|create|modify|remove)\b.*[`\w/.-]+
```

Examples:
- `Step 1: Edit line 47 of models.py`
- `Step 2: Add import to __init__.py`

Sequential numbered steps with file operations = HOW.

**Scope of this signal:** match only inside `Acceptance Criteria`,
`Deliverables`, or top-level numbered step lists. Do **not** match line
numbers cited inside a `## Design`, `## Notes`, or descriptive prose
section (e.g., "every `_to_room_public` call site (rooms.py:145, 167, 223)
now accepts a viewer_id"). Citations in design prose are short-lived and
explanatory; they are not execution prescriptions and rot at roughly the
same rate as the surrounding prose. If you want to flag them, use the
softer `FLAG-DESIGN-LINENUMS` (advisory only).

### FLAG-DESIGN-LINENUMS (advisory)
Scope-file design/notes prose cites raw line numbers (`file.py:123`).
These will silently rot on the next refactor but are not execution
imperatives. Recommend rewriting as a behavior statement (e.g., "every
call site now accepts viewer_id") only if the scope file is otherwise
being rewritten. Do not propose a rewrite proposal solely on this flag.

### H5. Tool-call prescriptions
Regex:
```
\b(Run|Execute|Call)\s+`[^`]+`\s+then\s+(open|read|grep)
```

Examples:
- `` Run `git grep "class Room"` then open the file that comes back ``
- `` Execute `uv run alembic...` then edit the generated migration ``

Prescribing a specific sequence of tool calls = HOW.

### H6. Phase/iteration planning keyed by file outputs
Heuristic: any section describing phases where each phase's "output" is
counted in files.

Regex:
```
Phase\s+\d+.*\b(outputs?|produces?|generates?)\b.*\b\d+\s+files?\b
```

Example:
- `Phase 1 outputs: 3 files; Phase 2 outputs: 5 files`

---

## Classification rule

For each file, let `w = count(WHAT signals)` and `h = count(HOW signals)`
(excluding `INFO-NAVIGATION` from `h`).

- **WHAT** if `h == 0 AND w >= 2`
- **HOW** if `h >= 2 AND h > w`
- **MIXED** otherwise

Additional attributes to record on each file:
- `signals_present`: list of W1..W7 / H1..H6 codes found
- `informational_flags`: list of `INFO-NAVIGATION` etc.
- `evidence_lines`: file:line excerpts for each matched signal (max 3
  excerpts per signal, prefer first occurrence)

---

## Corpus-level structural checks

Run these after per-file classification.

### GAP-OVERVIEW
No file matches `specs/00-*.md` AND no existing scope file contains an
"Agent Assignment" table.

### FLAG-SCOPE-HEADER (advisory only)
For each scope file, check for header block (top 20 lines). The
preferred field is `Components:`; `Agent:` is accepted as a legacy
alias from earlier template drafts.
```
\*\*(Components|Agent):\*\*\s+`?[\w-]+`?
\*\*Depends on:\*\*\s+.+
```
If `Components`/`Agent` is missing → `FLAG-SCOPE-HEADER` (advisory).
`Depends on:` is the load-bearing field; flag separately as
`FLAG-DEPENDS-ON-MISSING` when absent.

When a scope file uses the legacy `**Agent:**` field, surface it as
`FLAG-LEGACY-HEADER-FIELD` (advisory only — do not propose rewrite
solely on this; if rewriting for other reasons, rename to
`**Components:**`). The semantic difference matters: `Components`
describes the parts of the system being changed (declarative scope
content); `Agent` reads as a routing decision, which is `/lead`'s job
at execution time, not the scope file's.

`Phase:` and `Parallel with:` are **not** required:
- `Phase:` is optional — useful in strict greenfield with a locked
  overview, irrelevant in kanban / iterative flows. A missing `Phase` is
  not a flag.
- `Parallel with:` is **deprecated** and should not appear in the
  template at all. Earlier drafts included it but it overconstrains the
  implementation — `/lead` decides parallelism at execution time based
  on current worktree load. If a scope file already has a `Parallel
  with:` line, do **not** flag it on that basis; if you are emitting a
  Before/After rewrite for other reasons, drop the field in the After.

This is intentionally **not** a `GAP-*`. Workspaces are used in many modes —
strict greenfield with locked scope, kanban-style iteration, manual UI tasks
authored mid-sprint, post-milestone polish work added retroactively. A
missing Agent header is normal for the latter modes and does not by
itself indicate drift.

Reporting rule:
- List `FLAG-SCOPE-HEADER` files in the structural-flags table.
- Do **not** generate a rewrite proposal solely on a missing header.
- Only propose a header rewrite when the file *also* has another concern
  being addressed (e.g., it is being rewritten anyway because of `H2`/`H3`).
- In `--mode strict` (see SKILL.md "Scope rigor mode"), promote to
  `GAP-SCOPE-HEADER` and emit rewrite proposals.

### GAP-AC
Scope file has no section matching `^##?\s+Acceptance Criteria\s*$` →
`GAP-AC` on that file.

### FLAG-AC-NOT-BEHAVIOR
Scope file has Acceptance Criteria section, but < 50% of its AC items match
W4 (behavior-arrow or observable-predicate) → `FLAG-AC-NOT-BEHAVIOR`.

### FLAG-LAYER-NAMING
Scope file has section headers matching `^##?\s+(Frontend|Backend|Infra|Database|API)\s*$`
where the workspace has specific agent names that could replace them
(`angular-web`, `promotions-backend`, etc.) → `FLAG-LAYER-NAMING`.

### GAP-ORCHESTRATOR-SCOPE
Orchestrator agent file body does not match either:
```
(read|reference|check)\s+(the\s+)?(specs?/|scope\s+file|00-overview|overview|task\s+file)
```
or any reference to a feature/product overview surface:
```
(read|reference|check|consult)\s+(the\s+)?(README|product[-\s]overview|feature[-\s]overview|initial[-\s]goal|project[-\s]brief)
```
→ `GAP-ORCHESTRATOR-SCOPE`.

The orchestrator does not need to point at `specs/00-overview.md` specifically.
A workspace may carry product context in a README, a dedicated overview doc,
or an initial-goal definition. What matters is that the orchestrator is
instructed to read *some* product/feature overview before planning, not the
exact path. Do not flag a workspace whose lead reads, e.g.,
`Initial-goal-definition.md` or a top-level README.

### FLAG-ORPHAN-SPEC
Detect files inside `specs/` (or the workspace's scope directory) that are
neither numbered `NN-*.md` scope files **nor** referenced from
`specs/00-overview.md` (or the equivalent execution plan).

Detection:
1. Build the set of files referenced from `00-overview.md` (links + bare
   filename mentions).
2. Build the set of files matching the `specs/NN-*.md` naming pattern
   (`^\d{2}-[\w-]+\.md$`), plus known infrastructure files
   (`CHANGELOG.md`, `RELEASE-NOTES.md`, `current-state.md`,
   `patterns.md`).
3. Any file in `specs/` not in either set → `FLAG-ORPHAN-SPEC`.

Example: `Initial-goal-definition.md` and `JabberIntegrationResults.md` in
`aidlc_hackathon/specs/` are user-facing context files that the user
references manually (e.g., `@specs/Initial-goal-definition.md`) but agents
may *also* discover them by directory scan, leading to unpredictable
behavior.

Disposition options (recommend **one**, do not prescribe):
- **Relocate** — move to `docs/notes/` or `docs/user-context/` so they are
  outside the agent-discoverable scope tree.
- **Namespace** — rename with a `_user-` or `_context-` prefix
  (`_user-initial-goal.md`); document in workspace conventions that
  `_*` prefixed files are user-pointed only.
- **Index explicitly** — add a "User-pointed context (not auto-discovered)"
  subsection in `00-overview.md` listing them and the situations in which
  the orchestrator should consult them.

This is a `FLAG-*`, not a `GAP-*` — it surfaces unpredictability without
asserting the file is wrong.

### GAP-CHANGELOG
No file matches `specs/CHANGELOG.md` OR `CHANGELOG.md` exists but contains
zero references to scope file IDs (regex `\b0[1-9]-[\w-]+\.md\b` or
`TASK-\d+`) → `GAP-CHANGELOG`.

---

## Positive practices (record, do not flag)

Surface these in the report's "What looked right" section. They are
features of healthy workspaces, not gaps. Detecting them helps users
understand which patterns to keep when applying rewrites elsewhere.

### PRACTICE-AC-PROGRESS
Scope files use `[ ]` / `[x]` checkboxes in the Acceptance Criteria
section, AND at least one file shows mixed `[ ]` / `[x]` state (i.e., the
checkboxes are actually being maintained, not all-empty templates).

Detection:
- Per scope file with an AC section: at least 50% of AC items use `[ ]`
  or `[x]` notation.
- Workspace-level: at least one scope file has both `[ ]` and `[x]`
  items present (proves orchestrator/team is flipping them on completion).

Why it matters: turns scope files into a live progress board readable by
the orchestrator and humans without a separate tracker. Specifically
endorsed by users who saw `/lead` mark AC items `[x]` on completion and
found it valuable for cross-task reviews.

Reporting:
- Workspace-level `PRACTICE-AC-PROGRESS` in "What looked right".
- Per-file note when present.
- If AC items are present but never use checkboxes, do **not** flag — but
  do mention the practice in the report's "Optional improvements"
  appendix (one line, no rewrite proposal) so the user can adopt it.

---

## Recording signals in the report

For each file, the audit report produces a row:

| Path | Bucket | Class | WHAT signals | HOW signals | Evidence (line:excerpt) |
|---|---|---|---|---|---|
| `prompts/angular-web.md` | agent | WHAT | W1, W2, W3, W7 | — | L3: "You are the expert..." |
| `myproj-feature-area/tasks/step-01-*.md` | task | HOW | W3, W4 | H2, H3 | L54: "**New files**" |

Keep evidence to 1–2 lines per signal to keep the table scannable.
