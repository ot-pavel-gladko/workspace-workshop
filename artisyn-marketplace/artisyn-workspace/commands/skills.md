---
description: Discover and install Artisyn skills into this workspace (.claude/skills/)
argument-hint: "[list | search QUERY | add NAME | remove NAME | doctor] [--category CAT] [--tag T]"
allowed-tools: Bash
---

Browse the Artisyn skill catalog (aggregated across every installed
`artisyn.skill_providers` provider — `artisyn-catalog-schema`,
`artisyn-skill-sdk`, `artisyn-skill-library`, and any third-party providers),
then materialise the ones you want into `<workspace>/.claude/skills/<name>/`
so Claude Code can auto-activate them.

## Subcommands

- `list` *(default)* — show every available skill, with `[installed]` markers.
- `search <query>` — keyword filter across name/description/tags.
- `add <name>` — copy the named skill's `SKILL.md` (+ `references/`) into `.claude/skills/<name>/`.
- `remove <name>` — delete the materialised copy. The source in `.venv/...` is untouched.
- `doctor` — **non-destructive** migration report: recommended skills not yet installed, deprecated/renamed installed skills (with their replacement), and local/customized skills that will never be auto-overwritten. Changes nothing.

Filters available on `list` / `search`:

- `--category <name>` — e.g. `documentation`, `workspace`, `knowledge`.
- `--tag <name>` *(repeatable)* — AND-combined tag filter.

## When to use

- `list` when you don't know which skill name you need.
- `search` when you know the topic but not the skill name.
- `add` after picking a skill from `list`/`search`. The skill becomes
  auto-activatable on its next Claude Code restart.
- `remove` to slim down `.claude/skills/` if you're not using a previously-installed skill.
- `doctor` after a platform update — to see what's new/recommended, what's deprecated, and what's safely customized, before deciding what to `add`.

## Execute

```bash
artisyn-workspace skills $ARGUMENTS
```

After the run, report the table the CLI printed. When the user `add`s a
skill, also note its destination under `.claude/skills/<name>/` and tell
them to restart Claude Code so the new skill is picked up on next session.
