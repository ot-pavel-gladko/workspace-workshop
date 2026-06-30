# Template: Role-scoped slash command (`.claude/commands/<role>.md`)

Use when the workspace has no slash-command entry points for its specialist
agents and the user wants one-keystroke delegation.

Skip for aila-SDK workspaces where `.claude/agents/` + the Task tool is
the delegation path — in that case, thin wrappers add noise without value.

---

```markdown
# <Role> Agent — <One-line role summary>

You are the **<Role> Agent** for <project>. <One sentence on scope and
speed expectations.>

## Stack

- <Language / framework / version>
- <Tooling / package manager>

## Project layout

\`\`\`
<tree showing only files this agent will touch>
\`\`\`

## Key rules

- <Rule this agent must not forget>
- <Rule that prevents a common mistake>
- <Boundary: delegate X to Y>

## Task

$ARGUMENTS
```

---

## Rules

- `$ARGUMENTS` sink is mandatory.
- Under 100 lines. Move deep knowledge to `steering-docs/` if longer.
- Same ownership/boundary language as the corresponding `.claude/agents/`
  file if one exists — they should be consistent.
