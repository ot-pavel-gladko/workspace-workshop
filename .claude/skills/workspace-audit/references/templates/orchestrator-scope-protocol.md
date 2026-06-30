# Template: Orchestrator scope-reading protocol

Use when `GAP-ORCHESTRATOR-SCOPE` is flagged — the lead/orchestrator agent
does not instruct itself to read scope files before delegating.

Prepend this block to the orchestrator agent's **source** prompt body
(for aila-SDK: `prompts/lead.md`; for hand-written: the agent file directly).

After applying, for aila-SDK workspaces regenerate:
```bash
python3 workspace.py generate --agent claude
```

Do NOT edit the generated `.claude/agents/<lead>.md` directly.

---

```markdown
## Scope reading protocol

`$ARGUMENTS` is flexible — it may be a `TASK-NN` reference, a Jira
ticket link, a free-form task description, an instruction like
"read X.md then implement Y", or a plain feature request. Decide which
form you have, then proceed:

1. **Identify the input form.**
   - `TASK-NN` ref or a path to a scope file → load that scope file.
   - Jira link or external ticket → fetch / quote the description.
   - "Read X then …" → read X first, treat the remainder as the task.
   - Free-form description → treat the argument body as the task.

2. **Read the feature/product overview** to understand what is being built
   and why. This may be `specs/00-overview.md`, a top-level `README.md`,
   `Initial-goal-definition.md`, or an equivalent doc — whichever the
   workspace uses as its product brief. Do not skip this step even when the
   incoming request seems narrow.

3. **Read the relevant scope file** (e.g. `specs/NN-*.md`) for full scope
   and acceptance criteria, when one exists for the requested work and
   the input form points at it.

4. **Decide whether to refuse, draft, or proceed:**
   - No scope file and the work is non-trivial → offer to draft a scope
     file using the scope-file template, or proceed with the task body
     as the de-facto scope if the user explicitly asked for that.
   - Scope file present but missing Acceptance Criteria → ask before
     proceeding.
   - Trivial change with clear intent → proceed without a scope file.

5. **Synthesize delegation plan** citing the overview and any scope file IDs
   to the specialist agents you invoke.

6. **Track AC progress.** When a delegated task completes, flip the
   relevant AC items in `specs/NN-*.md` from `[ ]` to `[x]` (and add a
   one-line note if the AC was satisfied with caveats). This applies
   only when a scope file exists — for ad-hoc / Jira-only tasks, post
   completion to the originating channel instead.

Never delegate code edits silently — name the source the work is
satisfying (scope file ID, Jira ticket, or quoted task body).
```

---

## Placement in the prompt body

Insert immediately after the role-identity sentence(s), before the "Available
Agents" or "How to Work" section. This ensures the scope-reading instruction
is the first substantive behavior the agent reads.

Example (before):
```
You are the technical lead for <project>.
Your role is to analyse requirements, break down tasks, and delegate to specialist agents.

## Available Agents
...
```

Example (after):
```
You are the technical lead for <project>.
Your role is to analyse requirements, break down tasks, and delegate to specialist agents.

## Scope reading protocol
[insert template above]

## Available Agents
...
```
