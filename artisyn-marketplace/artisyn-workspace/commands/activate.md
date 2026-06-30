---
description: Hydrate an already-cloned Artisyn Delivery Workspace on this machine (.venv + settings.local.json)
argument-hint: "[version] [--offline-bundle PATH]"
allowed-tools: Bash
---

Hydrate an Artisyn Delivery Workspace that was cloned from git. Use this when the
workspace files (`workspace.py`, `artisyn-marketplace/`, `workspace-profile.yaml`)
are already present in the current directory but `.venv/` and/or
`.claude/settings.local.json` are missing — the typical "new team member's
first run" case.

For a greenfield install (no workspace yet) use `/artisyn-workspace:install`.

## One-time recommended setup (skip PAT prompts forever)

If you'll use Artisyn in more than one workspace, write your Confluence PAT
into `~/.artisyn/settings.json` **once** — every workspace then activates
without prompting:

```bash
mkdir -p ~/.artisyn
cat > ~/.artisyn/settings.json <<EOF
{
  "ARTISYN_CONFLUENCE_TOKEN": "<your-pat-here>",
  "ARTISYN_CONFLUENCE_URL": "https://conf.dataart.com",
  "ARTISYN_CONFLUENCE_SPACE": "SRD"
}
EOF
chmod 600 ~/.artisyn/settings.json
```

This file is on your machine only (never in git) and read by the Artisyn
CLI before any prompt fires. (Legacy `~/.aila/settings.json` with `AILA_CONFLUENCE_TOKEN` is also read as a fallback through 1.6.x.)

## Scope (intentionally narrow)

`activate` touches **only**:

- `.venv/` — creates it if missing; installs the Artisyn wheels.
- `.claude/settings.local.json` — merges in the Artisyn env block (PAT,
  Confluence URL, space) and a minimal permissions allow-list seed.
  Preserves any existing keys.

`activate` does **not** touch: `workspace.py`, `.claude/agents/*`,
`prompts/`, `steering-docs/`, `artisyn-marketplace/`, or anything else.
Hand-added agents and hand-edited prompts are safe.

If you want a full regeneration (rare — only needed after the Artisyn
template evolved and you want to opt in to structural-file refresh),
run `artisyn-workspace bootstrap` separately. Note that bootstrap
regenerates `workspace.py` from `workspace-profile.yaml` and may
remove hand-added `Agent(...)` declarations not captured by the
profile.

## What this does

1. Verifies the current directory looks like an existing workspace.
2. Installs `uv` if it's not on PATH yet.
3. Resolves the Confluence PAT (env → existing `settings.local.json` → asks
   you to paste it via a prompt).
4. Bootstraps the user-global `artisyn-workspace` CLI from Confluence if needed.
5. Runs `artisyn-workspace activate $ARGUMENTS`, which:
   - creates `.venv` and installs the Artisyn wheels into it,
   - merges the Artisyn env block + a minimal permissions seed into
     `.claude/settings.local.json` (preserves existing keys).

Re-running is safe (idempotent).

## Execute

### Step 0 — Verify we're in an existing workspace

```bash
if [ ! -f workspace.py ] || { [ ! -d artisyn-marketplace ] && [ ! -d aila-marketplace ]; } || [ ! -f workspace-profile.yaml ]; then
  echo "ERROR: $(pwd) does not look like an existing Artisyn Delivery Workspace."
  echo "       Expected: workspace.py + artisyn-marketplace/ (or legacy aila-marketplace/) + workspace-profile.yaml"
  echo "       For greenfield setup, run /artisyn-workspace:install instead."
  exit 1
fi
echo "OK: workspace markers present."
```

If this exits non-zero, stop and report the message to the user — do not
run the remaining steps.

### Step 1 — Ensure `uv` is on PATH

```bash
if ! command -v uv >/dev/null 2>&1; then
  echo "==> uv not found; installing via the official installer..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
fi
uv --version
```

### Step 1.5 — Short-circuit if a vendored release is committed

If the operator has committed `.artisyn/cache/` (the v0.12.0+ autonomy feature;
pre-rebrand workspaces used `.aila/cache/`), the CLI installs wheels from there
and never needs a PAT. Detect that case up front so the PAT chain in Step 2
stays out of the way for PAT-less teammates:

```bash
VENDOR_PRESENT=
VENDOR_DIR=
for d in .artisyn/cache .aila/cache; do
  if [ -f "$d/skill_manifest.json" ] && ls "$d"/*.whl >/dev/null 2>&1; then
    VENDOR_PRESENT=1
    VENDOR_DIR="$d"
    echo "Vendored release found at $d/ — skipping PAT resolution."
    break
  fi
done
```

When `VENDOR_PRESENT=1`, Step 2 (PAT) is skipped entirely. A corrupt vendor
(checksum mismatch) is still caught by the CLI itself, which fails loudly
rather than silently falling back to Confluence.

### Step 2 — Resolve the Confluence PAT (skipped when vendor is present)

The whole block is guarded with `if [ -n "$VENDOR_PRESENT" ]; then echo … ;
else <PAT chain> ; fi`. When `VENDOR_PRESENT=1` the PAT chain is skipped
and the bash block exits without touching env vars or settings files.

Otherwise:

Run this single bash block. It probes existing sources in order, and if
nothing has a PAT it opens a **native OS password dialog** so the token
never enters the Claude chat transcript or the Bash-tool stdout log:

```bash
if [ -n "$VENDOR_PRESENT" ]; then
  echo "PAT: not needed (vendored release at ${VENDOR_DIR:-.artisyn/cache}/)"
else
# --- 1. existing env vars ------------------------------------------------
PAT="${ARTISYN_CONFLUENCE_TOKEN:-${AILA_CONFLUENCE_TOKEN:-${CONFLUENCE_PERSONAL_TOKEN:-}}}"
SOURCE="env"

# --- 2. workspace-local settings.local.json ------------------------------
if [ -z "$PAT" ] && [ -f .claude/settings.local.json ]; then
  PAT=$(python3 -c 'import json; d=json.load(open(".claude/settings.local.json")); e=(d.get("env") or {}); print(e.get("ARTISYN_CONFLUENCE_TOKEN") or e.get("AILA_CONFLUENCE_TOKEN") or "")' 2>/dev/null || true)
  [ -n "$PAT" ] && SOURCE=".claude/settings.local.json"
fi

# --- 3. user-global ~/.artisyn/settings.json (legacy ~/.aila/ also checked) -----
if [ -z "$PAT" ] && [ -f "$HOME/.artisyn/settings.json" ]; then
  PAT=$(python3 -c "import json,os; d=json.load(open(os.path.expanduser('~/.artisyn/settings.json'))); print(d.get('ARTISYN_CONFLUENCE_TOKEN') or d.get('AILA_CONFLUENCE_TOKEN') or d.get('CONFLUENCE_PERSONAL_TOKEN') or '')" 2>/dev/null || true)
  [ -n "$PAT" ] && SOURCE="~/.artisyn/settings.json"
fi
if [ -z "$PAT" ] && [ -f "$HOME/.aila/settings.json" ]; then
  PAT=$(python3 -c "import json,os; d=json.load(open(os.path.expanduser('~/.aila/settings.json'))); print(d.get('AILA_CONFLUENCE_TOKEN') or d.get('CONFLUENCE_PERSONAL_TOKEN') or '')" 2>/dev/null || true)
  [ -n "$PAT" ] && SOURCE="~/.aila/settings.json"
fi

# --- 4. native OS password dialog ---------------------------------------
# The PAT comes back via dialog stdout into the PAT variable. We never
# echo it. The next step exports it for the CLI silently.
if [ -z "$PAT" ]; then
  echo "==> Confluence PAT not found in env or settings files."
  echo "    Opening a secure dialog so the token stays off the chat transcript..."
  case "$(uname -s)" in
    Darwin)
      PAT=$(osascript -e 'tell application "System Events" to display dialog "Enter your Confluence Personal Access Token.\n\nGenerate one at https://conf.dataart.com/plugins/personalaccesstokens/usertokens.action\n\nThe PAT will be written to .claude/settings.local.json (gitignored)." default answer "" with hidden answer with title "Artisyn Delivery Workspace activate"' -e 'text returned of result' 2>/dev/null) || PAT=""
      ;;
    Linux)
      if command -v zenity >/dev/null 2>&1; then
        PAT=$(zenity --password --title="Artisyn Delivery Workspace activate" 2>/dev/null) || PAT=""
      elif command -v kdialog >/dev/null 2>&1; then
        PAT=$(kdialog --password "Enter your Confluence Personal Access Token" --title "Artisyn Delivery Workspace activate" 2>/dev/null) || PAT=""
      else
        echo "ERROR: no GUI password dialog available on this Linux (install zenity or kdialog)." >&2
        echo "       Workaround: write the PAT into ~/.artisyn/settings.json (see the one-time setup at the top of /artisyn-workspace:activate)." >&2
        exit 1
      fi
      ;;
    CYGWIN*|MINGW*|MSYS*)
      PAT=$(powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "
        Add-Type -AssemblyName System.Windows.Forms
        \$f = New-Object Windows.Forms.Form
        \$f.Text = 'Artisyn Delivery Workspace activate'
        \$f.Width = 520; \$f.Height = 180; \$f.StartPosition = 'CenterScreen'
        \$l = New-Object Windows.Forms.Label
        \$l.Text = 'Enter your Confluence Personal Access Token'
        \$l.AutoSize = \$true; \$l.Top = 12; \$l.Left = 12
        \$f.Controls.Add(\$l)
        \$tb = New-Object Windows.Forms.TextBox
        \$tb.UseSystemPasswordChar = \$true
        \$tb.Width = 480; \$tb.Top = 40; \$tb.Left = 12
        \$f.Controls.Add(\$tb)
        \$ok = New-Object Windows.Forms.Button
        \$ok.Text = 'OK'; \$ok.Top = 80; \$ok.Left = 220
        \$ok.Add_Click({ \$f.DialogResult = 'OK'; \$f.Close() })
        \$f.Controls.Add(\$ok)
        \$f.AcceptButton = \$ok
        [void]\$f.ShowDialog()
        \$tb.Text
      " 2>/dev/null) || PAT=""
      ;;
    *)
      echo "ERROR: unrecognized OS '$(uname -s)' — no password dialog available." >&2
      echo "       Workaround: write the PAT into ~/.artisyn/settings.json (see the one-time setup at the top of /artisyn-workspace:activate)." >&2
      exit 1
      ;;
  esac
  # Strip any trailing newline / carriage return from the dialog output.
  PAT="${PAT%$'\n'}"
  PAT="${PAT%$'\r'}"
  if [ -n "$PAT" ]; then
    SOURCE="OS dialog"
  fi
fi

# --- 5. export silently for the CLI -------------------------------------
if [ -n "$PAT" ]; then
  export ARTISYN_CONFLUENCE_TOKEN="$PAT"
  echo "PAT: captured from $SOURCE"   # source tag only; no token value
else
  echo "ERROR: no PAT available; activate cannot continue." >&2
  echo "       Generate one at https://conf.dataart.com/plugins/personalaccesstokens/usertokens.action" >&2
  exit 1
fi
fi  # end: if [ -n "$VENDOR_PRESENT" ] ... else
```

**Security contract:**
- The PAT value is never `echo`-ed, never inlined into a command, never
  written to a log file by this slash command. It lives only in the
  `PAT` shell variable and the exported `ARTISYN_CONFLUENCE_TOKEN` env var
  read by the CLI.
- The Bash-tool stdout that Claude sees only includes the `PAT:
  captured from <source>` line and the dialog-not-found error path.
- Do NOT use `AskUserQuestion` to ask for the PAT. The "Other" free-text
  answer goes into the conversation transcript and is the exact security
  hole this dialog flow exists to close.

### Step 3 — Ensure the `artisyn-workspace` CLI is reachable

Prefer the workspace's own venv binary if it exists (so we always run the
version the workspace was built with); otherwise fall back to the
user-global CLI; otherwise bootstrap it from Confluence:

```bash
# Prefer the workspace's own binary if it both exists AND actually runs.
# A broken .venv (e.g. macOS-duplicated site-packages, ABI mismatch) leaves
# an executable file behind that crashes on import — fall through to
# user-global rather than pin ourselves to a doomed binary.
# Try artisyn-workspace first (primary name since 1.4.0); fall back to
# aila-workspace for legacy installs still within the 1.6.x compat window.
ARTISYN_WS=""
if [ -x ".venv/bin/artisyn-workspace" ] && .venv/bin/artisyn-workspace --help >/dev/null 2>&1; then
  ARTISYN_WS="$(pwd)/.venv/bin/artisyn-workspace"
elif [ -x ".venv/bin/aila-workspace" ] && .venv/bin/aila-workspace --help >/dev/null 2>&1; then
  ARTISYN_WS="$(pwd)/.venv/bin/aila-workspace"
elif command -v artisyn-workspace >/dev/null 2>&1; then
  ARTISYN_WS="$(command -v artisyn-workspace)"
elif command -v aila-workspace >/dev/null 2>&1; then
  ARTISYN_WS="$(command -v aila-workspace)"
else
  echo "==> Bootstrapping artisyn-workspace from Confluence..."
  bash "${CLAUDE_PLUGIN_ROOT}/scripts/install-from-confluence.sh" --no-chain
  export PATH="$HOME/.local/bin:$PATH"
  ARTISYN_WS="$(command -v artisyn-workspace 2>/dev/null || command -v aila-workspace)"
fi
echo "CLI: $ARTISYN_WS"
```

### Step 4 — Hydrate the workspace

```bash
# Translate a bare positional version (e.g. `0.12.0`) into `--version 0.12.0`
# so the CLI's argparse picks it up. Tokens that already start with `-` or
# `--` are passed through untouched.
ARTISYN_ARGS="$ARGUMENTS"
case "$ARTISYN_ARGS" in
  "" | -*) ;;
  *) ARTISYN_ARGS="--version $ARTISYN_ARGS" ;;
esac
"$ARTISYN_WS" activate $ARTISYN_ARGS
```

After the run, report:

- the `=== Activate complete ===` summary block (workspace path, version),
- whether `.claude/settings.local.json` was merged or skipped,
- **a prominent reminder**: the user must **restart Claude Code** so
  the env block + permissions written to `.claude/settings.local.json`
  take effect. Without a restart, the freshly written PAT and
  permissions are invisible to the running session.

**Forbidden on success.** Do NOT suggest running `artisyn-workspace
bootstrap`, do NOT suggest `workspace.py generate --agent claude`,
do NOT hint at regenerating any structural file. `activate` is
deliberately narrow; if the user wanted regeneration they would
invoke bootstrap directly.

Re-running `/artisyn-workspace:activate` is always safe.
