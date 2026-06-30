# Permissions Baseline

Expected shape of `.claude/settings.json` for a Claude Code workspace. The skill compares the current file to this baseline and flags deviations. Paths listed here are patterns — adapt to the workspace's actual top-level directories detected in Phase 1 of the skill.

## Principles

1. **Path-scoped allow beats blanket allow.** `Read(docs/**)` is auditable; `Read(**)` is not. Every `allow` entry for `Read`, `Write`, `Edit`, `Grep`, `Glob` must name a directory prefix under the workspace root.
2. **Bash is allowed only for commands we actually need.** Maintain an explicit per-command allowlist; do not allow `Bash(*)`.
3. **Deny list covers destructive and exfiltrating patterns.** These are defense-in-depth — the `PreToolUse(Bash)` hook (see `bash-guard.md`) is the primary guard; `deny` is the fallback.
4. **Telemetry, if the workspace has it, is non-negotiable.** If an agent-usage hook is present, it feeds the token-gain heuristic in Phase 4; removing it blinds that phase.
5. **Skill-refresh hook must remain.** `PostToolUse` on `Write(*.claude/skills/*)` running `skill_sdk_aila.hooks.claude_refresh` is what makes skills (including this one) discoverable after edit, for Artisyn-managed workspaces.

## Allow — expected prefixes

Read, Glob, Grep, Write, Edit entries should cover (and only cover) the workspace's actual top-level directories. Typical examples:
- `.claude/**`
- Documentation roots (`docs/**`, `steering-docs/**`, `kb/**`)
- Source roots (`src/**`, `external-links/**`, or the per-repo prefix this workspace uses)
- Reporting/output roots (`reporting/**`, `.claude/reports/**`)
- Test roots (`tests/**`, `qa/**`, `e2e/**`)

The skill detects the workspace's actual top-level directories by `Glob`-ing one level deep at the workspace root and matching them against existing `allow` entries. Flag any allow entry targeting a path outside the detected set as `warn`. Flag any wildcard (`Read(**)`, `Write(**)`) as `critical`.

## Allow — Bash (expected categories)

Group the current Bash allowlist into these buckets when auditing. Missing buckets for operations the workspace demonstrably performs (evidence: build/test commands in README or CI config) are `warn`.

| Bucket | Examples | Required? |
|---|---|---|
| Git read-only | `git status *`, `git log *`, `git diff *` | Yes |
| Git write | `git add *`, `git checkout *`, `git pull *`, `git clone *` | Yes — needed for branch/commit flow |
| Workspace/meta tooling | `python3 workspace.py *`, `python3 -m skill_sdk_aila.*`, `aila-workspace *`, `aila-meta *` | Only when Artisyn-managed |
| Build toolchain | `mvn *`, `npm *`, `npx *`, `gradle *`, `cargo *`, `go *` — whichever the project uses | Yes if the project builds |
| Tooling introspection | `*--version`, `which *`, `uname *` | Yes |
| Python venvs | `.venv/bin/python3 *`, `pip install *`, `pip show *` | Only when the project uses Python venvs |
| Shell primitives | `ls *`, `test *`, `mkdir *`, `wc *` | Yes |
| Broad shell patterns | `find *`, `for *`, `grep *`, `cat *` | **Flag `info`** — these duplicate dedicated tools (Glob, Grep, Read) and encourage Bash when native tools should be used. Candidate for removal if the user wants tighter surface. |

## Ask — recommended pattern

Operations with larger blast radius but legitimate use belong in `ask`, not `allow`. Typical recommendation:

```json
"ask": [
  "Bash(git push *)",
  "Bash(git commit *)",
  "Bash(gh pr create *)",
  "Bash(gh pr merge *)"
]
```

When the workspace is Artisyn-managed, add:

```json
  "Bash(python3 workspace.py generate *)"
```

Rationale: `git push` and `gh pr create` are visible to others; `workspace.py generate` can destroy hand-tuned `.md` files in Artisyn-managed workspaces. The `ask` tier forces a per-invocation confirmation without blocking outright.

## Deny — expected minimum

```json
"deny": [
  "Bash(rm -rf *)",
  "Bash(git push --force *)",
  "Bash(git reset --hard *)"
]
```

**Recommendation:** add the following to the deny list regardless of the `PreToolUse` hook, because `deny` is read before any hook runs:

```json
  "Bash(curl *| *sh*)",
  "Bash(wget *| *sh*)",
  "Bash(* > ~/.ssh/authorized_keys*)",
  "Bash(* >> ~/.ssh/authorized_keys*)",
  "Bash(chmod 777 *)"
```

## Hooks — expected set

Which hooks the workspace *should* have depends on what the workspace opts into. The skill audits against actually-installed hooks plus the recommended additions below.

### PostToolUse (recommended when Artisyn-managed)

- `Write(*.claude/skills/*)` -> `python -m skill_sdk_aila.hooks.claude_refresh` — skill discovery refresh. Required for Artisyn-managed workspaces; flag `critical` if missing in those.
- `Agent` -> agent-usage telemetry script (whatever path the workspace chose), `timeout: 10`. Optional; required only if Phase 4 of the audit should be telemetry-grounded.

### SubagentStop and Stop (recommended when telemetry is used)

Same telemetry command as the `PostToolUse(Agent)` hook, `timeout: 10`. Required for the token-gain telemetry that Phase 4 consumes.

### PreToolUse (recommend adding if missing)

See `bash-guard.md` for the full script. The matcher and activation snippet to drop in:

```json
"PreToolUse": [
  {
    "matcher": "Bash",
    "hooks": [
      {
        "type": "command",
        "command": "python3 \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/bash-guard.py",
        "timeout": 5
      }
    ]
  }
]
```

When absent from the current settings, the skill flags `warn` (not `critical` — deny list provides partial coverage).

## Flag summary the skill emits

| Condition | Severity | Proposed fix |
|---|---|---|
| Any allow entry outside the detected set of workspace top-level directories | `warn` | Move under an allowed prefix or remove. |
| Wildcard Read/Write/Glob/Grep entry | `critical` | Replace with explicit prefix. |
| `Bash(find *)` / `Bash(cat *)` / `Bash(grep *)` / `Bash(for *)` present | `info` | Consider removing; prefer Glob/Grep/Read. |
| `ask` list empty or missing `git push *` / `gh pr *` | `warn` | Add them. |
| `deny` missing any of the destructive patterns above | `warn` | Add them. |
| `PostToolUse(Write *.claude/skills/*)` missing (Artisyn-managed workspaces only) | `critical` | Restore; skill discovery breaks without it. |
| `PreToolUse(Bash)` missing | `warn` | Add per `bash-guard.md`. |
| Any hook with `timeout` > 30 | `warn` | Tighten. Slow hooks block tool calls. |
