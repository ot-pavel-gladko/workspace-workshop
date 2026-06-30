# Bash Guard — PreToolUse Hook

Self-contained specification for a `PreToolUse(Bash)` hook that rejects a short list of destructive or exfiltrating shell patterns. Drop-in content for `.claude/hooks/bash-guard.py` and the activation snippet for `.claude/settings.json`.

## Why this exists

The `deny` list in `settings.json` is a blunt instrument — it matches the whole command string against glob patterns. A `PreToolUse` hook can parse the command, look inside pipelines, and reject patterns that `deny` can't express (e.g. "any `curl ... | sh`" regardless of arg order).

## Script — `.claude/hooks/bash-guard.py`

Place the following file at `.claude/hooks/bash-guard.py` and make it executable (`chmod +x`). It reads the tool-call payload from stdin per the Claude Code hook contract, inspects the `command` field, and exits non-zero to block the call.

```python
#!/usr/bin/env python3
"""PreToolUse(Bash) guard. Rejects destructive or exfiltrating shell patterns."""

import json
import re
import sys


BLOCK_PATTERNS = [
    # Destructive filesystem
    (re.compile(r"\brm\s+(-[a-zA-Z]*r[a-zA-Z]*f|--recursive\s+--force|-rf)\b.*\s(/|~|\$HOME|\*)", re.I),
     "rm -rf against root, home, or wildcard"),
    # Force push
    (re.compile(r"\bgit\s+push\s+.*--force\b"), "git push --force"),
    (re.compile(r"\bgit\s+push\s+.*-f\b"), "git push -f"),
    (re.compile(r"\bgit\s+reset\s+--hard\b"), "git reset --hard"),
    # Pipe-to-shell
    (re.compile(r"\b(curl|wget)\b[^|]*\|\s*(sh|bash|zsh|python3?)\b"), "pipe-to-shell"),
    # SSH authorized_keys tampering
    (re.compile(r">>?\s*~?/?\.ssh/authorized_keys"), "writing to authorized_keys"),
    # Overly-permissive chmod
    (re.compile(r"\bchmod\s+777\b"), "chmod 777"),
    # Shell init edits
    (re.compile(r">>?\s*~/\.(bashrc|zshrc|profile|bash_profile)\b"), "shell init file edit"),
    # Credential exfil
    (re.compile(r"cat\s+~?/?\.aws/credentials"), "reading AWS credentials"),
    (re.compile(r"cat\s+~?/?\.ssh/id_[a-zA-Z0-9_]+\b"), "reading SSH private key"),
]


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0  # pass through malformed payloads; downstream will fail cleanly

    command = (
        payload.get("tool_input", {}).get("command")
        or payload.get("input", {}).get("command")
        or ""
    )
    if not command:
        return 0

    for pattern, label in BLOCK_PATTERNS:
        if pattern.search(command):
            sys.stderr.write(
                f"bash-guard: blocked Bash command — matched pattern: {label}\n"
                f"command: {command[:200]}\n"
            )
            return 2  # non-zero signals block

    return 0


if __name__ == "__main__":
    sys.exit(main())
```

## Activation — `.claude/settings.json` snippet

Add this entry under `"hooks"` (alongside any existing `PostToolUse`, `SubagentStop`, `Stop`):

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

No other changes are required. The hook runs on every Bash call; it passes through in ~1ms when no pattern matches.

## What the skill does with this file

When Phase 3 of the audit detects that `.claude/settings.json` has no `PreToolUse(Bash)` entry, the skill's proposed fix in the report is:

1. A unified-diff block adding the JSON snippet above to `settings.json`.
2. A note to create `.claude/hooks/bash-guard.py` with the full script body (copy from this file — it is self-contained).
3. A Bash line the user can run after applying: `chmod +x .claude/hooks/bash-guard.py`.

No runtime dependency on any external workspace — the complete hook script is in this file.

## Verifying the hook

After the user applies the change, they can smoke-test with:

```bash
echo '{"tool_input":{"command":"rm -rf /"}}' | python3 .claude/hooks/bash-guard.py; echo "exit=$?"
# Expected: bash-guard: blocked ... ; exit=2
echo '{"tool_input":{"command":"ls -la"}}' | python3 .claude/hooks/bash-guard.py; echo "exit=$?"
# Expected: exit=0
```

## Deliberate non-coverage

The hook does **not** try to block:
- `curl` without a pipe-to-shell (legitimate API calls exist).
- `git commit --no-verify` (bypass-hooks is a distinct policy; handled elsewhere).
- Any deliberate sudo usage.
- Reading files in general — the deny list handles specific-path exfil; reading in general is allowed.

Expanding the pattern list belongs to a follow-up skill, not to this refinement skill.
