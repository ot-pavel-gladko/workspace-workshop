#!/usr/bin/env bash
# Shared helpers for artisyn-workspace-runner.
#   - entrypoint.sh : one-shot manual dispatch
# This file is sourced, not executed; callers own `set -e` policy.

SRC=/artisyn/workspace-src   # read-only bind mount of the host workspace
DST=/artisyn/workspace        # writable working copy (container-local)
SRC_HOST=/artisyn/src-host    # read-only bind mount of the host sibling ../src tree
SSH_HOST=/artisyn/ssh-host    # read-only bind mount of the host ~/.ssh (keys + config)
CODE_DIR=/artisyn/code-repo   # parent of the container's own per-repo clones (persistent volume)
CODE_RO_DIR=/artisyn/code-readonly  # read-only reference copies of non-git src folders

log() { echo "[runner] $*"; }
banner() { echo "[runner] ============================================================"; }

# ---------------------------------------------------------------------------
# sync_workspace
# Rsync the read-only host workspace mount into a writable in-container tree.
# Excludes macOS/.venv/node_modules/cache artefacts that are useless in Linux.
# ---------------------------------------------------------------------------
sync_workspace() {
  log "syncing workspace ($SRC -> $DST) ..."
  mkdir -p "$DST"
  rsync -a --delete \
    --exclude '.git/' \
    --exclude '.venv/' \
    --exclude 'node_modules/' \
    --exclude '__pycache__/' \
    --exclude '*.pyc' \
    --exclude '.artisyn/cache/' \
    --exclude '.aila/cache/' \
    "$SRC"/ "$DST"/
  cd "$DST"
}

# ---------------------------------------------------------------------------
# sync_specs
# Cheap in-loop re-sync: rsync specs/ from the read-only host mount ($SRC)
# into the writable in-container copy ($DST/specs/) so story edits on the
# host are visible to the next tracker_ready_keys call without a container
# restart (BUG-0042).
#
# Scoped to specs/ only — fast and non-destructive.  The host source ($SRC)
# is NEVER written; only $DST/specs is updated.
# ---------------------------------------------------------------------------
sync_specs() {
  [ -d "$SRC/specs" ] || return 0   # nothing to sync if host has no specs/
  mkdir -p "$DST/specs"
  rsync -a --delete \
    --exclude '__pycache__/' \
    --exclude '*.pyc' \
    "$SRC/specs/" "$DST/specs/"
}

# ---------------------------------------------------------------------------
# require_claude_auth
# Abort if no model auth is available.
# ---------------------------------------------------------------------------
require_claude_auth() {
  if [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] && [ -z "${ANTHROPIC_API_KEY:-}" ]; then
    log "ERROR: no CLAUDE_CODE_OAUTH_TOKEN or ANTHROPIC_API_KEY set." >&2
    log "       Run 'claude setup-token' on the host (activation URL + code)" >&2
    log "       and put the token in runner/.env as CLAUDE_CODE_OAUTH_TOKEN." >&2
    exit 3
  fi
}

# ---------------------------------------------------------------------------
# discover_lead_agent
# Return (stdout) the name of the workspace's configured lead agent.
# Heuristic: the agent file whose name contains "lead" in .claude/agents/.
# Falls back to the first agent in the directory. Exits 5 if no agents exist.
# ---------------------------------------------------------------------------
discover_lead_agent() {
  local agents_dir="$DST/.claude/agents"
  if [ ! -d "$agents_dir" ]; then
    log "ERROR: no .claude/agents/ directory found in the workspace." >&2
    log "       Ensure the workspace has at least one lead agent." >&2
    exit 5
  fi

  # Prefer an agent file whose basename contains "lead".
  local lead_file
  lead_file=$(find "$agents_dir" -maxdepth 1 -name "*lead*" -name "*.md" | sort | head -1)
  if [ -z "$lead_file" ]; then
    # Fall back to the first .md in the directory.
    lead_file=$(find "$agents_dir" -maxdepth 1 -name "*.md" | sort | head -1)
  fi
  if [ -z "$lead_file" ]; then
    log "ERROR: no agent .md files found in $agents_dir." >&2
    exit 5
  fi

  basename "$lead_file" .md
}

# ---------------------------------------------------------------------------
# setup_ssh
# Make the host's SSH identity usable inside the container. The host ~/.ssh is
# bind-mounted READ-ONLY at $SSH_HOST; copy it to a writable $HOME/.ssh (so we
# can append to known_hosts) and fix permissions OpenSSH requires. No keys are
# baked into the image — they arrive only at run time via the mount.
# ---------------------------------------------------------------------------
setup_ssh() {
  if [ ! -d "$SSH_HOST" ]; then
    log "no host SSH mount at $SSH_HOST; SSH remotes will fail unless GIT_TOKEN/HTTPS is used."
    return 0
  fi
  log "preparing SSH identity from $SSH_HOST -> $HOME/.ssh ..."
  mkdir -p "$HOME/.ssh"
  cp -a "$SSH_HOST"/. "$HOME/.ssh"/ 2>/dev/null || true
  chmod 700 "$HOME/.ssh" 2>/dev/null || true
  chmod 600 "$HOME"/.ssh/* 2>/dev/null || true
  chmod 644 "$HOME"/.ssh/*.pub 2>/dev/null || true
  [ -f "$HOME/.ssh/known_hosts" ] && chmod 644 "$HOME/.ssh/known_hosts"
}

# ---------------------------------------------------------------------------
# ssh_remote_host <git-remote-url>
# Echo the hostname from an SSH remote URL (git@host:path or ssh://git@host/...).
# Echoes nothing for non-SSH URLs.
# ---------------------------------------------------------------------------
ssh_remote_host() {
  local url="$1"
  case "$url" in
    ssh://*) echo "$url" | sed -E 's#^ssh://([^@/]*@)?([^/:]+).*#\2#' ;;
    *@*:*)   echo "$url" | sed -E 's#^[^@]*@([^:]+):.*#\1#' ;;
    *)       echo "" ;;
  esac
}

# ---------------------------------------------------------------------------
# ensure_known_host <hostname>
# Append the host's public key to $HOME/.ssh/known_hosts if absent, so headless
# SSH clones don't hang on the interactive host-key prompt. Idempotent.
# ---------------------------------------------------------------------------
ensure_known_host() {
  local host="$1"
  [ -z "$host" ] && return 0
  mkdir -p "$HOME/.ssh"; touch "$HOME/.ssh/known_hosts"
  if ! ssh-keygen -F "$host" -f "$HOME/.ssh/known_hosts" >/dev/null 2>&1; then
    log "scanning host key for $host ..."
    ssh-keyscan -H "$host" >> "$HOME/.ssh/known_hosts" 2>/dev/null \
      || log "WARN: ssh-keyscan $host failed; clone of repos on $host may fail." >&2
  fi
}

# ---------------------------------------------------------------------------
# _clone_or_update <name> <remote-url> <base-branch>
# Clone (first run) or hard-reset to origin/<base> (later runs) one repo into
# $CODE_DIR/<name>, then set push options so `git push` auto-opens an MR against
# <base>. SSH host keys are scanned on demand; HTTPS URLs may carry a GIT_TOKEN.
# Never touches the host working copy.
#
# BUG-0061: GIT_TOKEN is NEVER embedded in the remote URL or written to
# .git/config.  The token is supplied per-invocation via
#   git -c http.extraHeader="Authorization: Bearer $GIT_TOKEN" ...
# so the on-disk remote.origin.url stays token-free and credential-free.
# ---------------------------------------------------------------------------
_clone_or_update() {
  local name="$1" url="$2" base="$3"
  local dest="$CODE_DIR/$name"

  # Build per-invocation git auth flags (BUG-0061).
  # For SSH remotes: rely on the SSH identity mounted at $SSH_HOST (set up by
  # setup_ssh).  No token injection needed or safe.
  # For HTTPS remotes with GIT_TOKEN: supply the Bearer token via
  # http.extraHeader per git call — the token MUST NOT appear in the remote URL.
  local _git_auth_flags=()
  case "$url" in
    git@*|ssh://*)
      ensure_known_host "$(ssh_remote_host "$url")"
      ;;
    https://*)
      if [ -n "${GIT_TOKEN:-}" ]; then
        _git_auth_flags=( -c "http.extraHeader=Authorization: Bearer ${GIT_TOKEN}" )
      fi
      ;;
  esac

  git config --global --add safe.directory "$dest" 2>/dev/null || true

  if [ -d "$dest/.git" ]; then
    log "[$name] existing clone; fetching origin/$base ..."
    # Set the token-free URL on disk (BUG-0061: no credential in .git/config).
    git -C "$dest" remote set-url origin "$url"
    local fetch_ok=0
    if git "${_git_auth_flags[@]+"${_git_auth_flags[@]}"}" -C "$dest" fetch --prune origin \
        "+refs/heads/$base:refs/remotes/origin/$base" 2>&1; then
      fetch_ok=1
    fi

    # After the fetch, verify origin/$base actually resolved (it won't when the
    # existing clone had no +refs/heads/*:refs/remotes/origin/* refspec, or when
    # HEAD was unborn from a prior interrupted clone).
    local origin_ref_ok=0
    git -C "$dest" rev-parse --verify "origin/$base" >/dev/null 2>&1 && origin_ref_ok=1

    if [ "$origin_ref_ok" = "1" ]; then
      git -C "$dest" checkout -B "$base" "origin/$base"
      git -C "$dest" reset --hard "origin/$base"
      git -C "$dest" clean -fd
    else
      # origin/$base not resolvable — either fetch failed (remote unreachable)
      # or the clone is broken (missing refspec, unborn HEAD).  Attempt recovery
      # by wiping the broken clone and re-cloning fresh from origin.
      if [ "$fetch_ok" = "1" ]; then
        log "[$name] broken clone (origin/$base unresolvable after fetch); re-cloning fresh ..." >&2
        rm -rf "$dest"
        git config --global --add safe.directory "$dest" 2>/dev/null || true
        if ! git "${_git_auth_flags[@]+"${_git_auth_flags[@]}"}" clone --branch "$base" "$url" "$dest" 2>&1; then
          log "ERROR: [$name] re-clone after broken-clone recovery failed; skipping." >&2
          return 1
        fi
      else
        # Fetch failed AND origin/$base is unresolvable — remote is unreachable
        # and the local clone is broken.  Abort rather than falsely report ready.
        local head_sha
        head_sha="$(git -C "$dest" rev-parse --short HEAD 2>/dev/null || true)"
        if [ -z "$head_sha" ]; then
          log "ERROR: [$name] fetch failed and HEAD is unborn; skipping this repo." >&2
          return 1
        fi
        # HEAD is not unborn — there IS a usable cached commit; warn and proceed.
        log "WARN: [$name] fetch failed; using cached clone as-is (HEAD: $head_sha)." >&2
      fi
    fi
  else
    log "[$name] cloning branch '$base' ..."
    if ! git "${_git_auth_flags[@]+"${_git_auth_flags[@]}"}" clone --branch "$base" "$url" "$dest" 2>&1; then
      log "WARN: [$name] clone --branch $base failed; trying default-branch clone." >&2
      git "${_git_auth_flags[@]+"${_git_auth_flags[@]}"}" clone "$url" "$dest" 2>&1 \
        || { log "ERROR: [$name] clone failed; skipping this repo." >&2; return 1; }
      git -C "$dest" checkout "$base" 2>/dev/null || true
    fi
  fi

  # Per-repo push options: auto-open an MR against this repo's own base branch.
  # --unset-all first so re-runs on the persistent clone don't hit the
  # "cannot overwrite multiple values" error (the key is multi-valued).
  git -C "$dest" config --unset-all push.pushOption 2>/dev/null || true
  git -C "$dest" config --add push.pushOption "merge_request.create"
  git -C "$dest" config --add push.pushOption "merge_request.target=$base"
  git -C "$dest" config --add push.pushOption "merge_request.remove_source_branch"

  log "[$name] ready @ $(git -C "$dest" rev-parse --short HEAD 2>/dev/null) on $(git -C "$dest" rev-parse --abbrev-ref HEAD 2>/dev/null) (MR target: $base)"
}

# ---------------------------------------------------------------------------
# refresh_code_repos (BUG-0053)
# Before each dispatch: fetch origin and hard-reset the base branch of every
# git repo under $CODE_DIR to the latest remote state.  This ensures a new
# dispatch always branches off the current origin/<base>, not a stale local
# copy from a previous poll iteration.
#
# Non-fatal per-repo: one repo failing to fetch does not abort the dispatch.
# The per-repo base branch is stored in the git config (merge_request.target
# push option set by _clone_or_update); we read it back from there so we
# never need to re-parse the host src tree.
# ---------------------------------------------------------------------------
refresh_code_repos() {
  local code_dir="${CODE_DIR:-/artisyn/code-repo}"
  [ -d "$code_dir" ] || return 0

  for dest in "${code_dir}"/*/; do
    [ -d "${dest}/.git" ] || continue
    local name
    name="$(basename "$dest")"

    # Read the configured MR target (= base branch) written by _clone_or_update.
    local base
    base="$(git -C "$dest" config --get-all push.pushOption 2>/dev/null \
      | grep 'merge_request.target=' | head -1 | sed 's/merge_request.target=//')"
    [ -z "$base" ] && base="${TARGET_BASE_BRANCH:-main}"

    log "[$name] refreshing base: fetching origin/$base ..."
    # BUG-0061: supply GIT_TOKEN via http.extraHeader per-invocation; never
    # embed it in the remote URL or re-mutate .git/config here.
    local _refresh_auth_flags=()
    local _remote_url
    _remote_url="$(git -C "$dest" remote get-url origin 2>/dev/null || true)"
    case "$_remote_url" in
      https://*) [ -n "${GIT_TOKEN:-}" ] && \
        _refresh_auth_flags=( -c "http.extraHeader=Authorization: Bearer ${GIT_TOKEN}" ) ;;
    esac
    local fetch_ok=0
    if git "${_refresh_auth_flags[@]+"${_refresh_auth_flags[@]}"}" -C "$dest" fetch origin \
        "+refs/heads/${base}:refs/remotes/origin/${base}" 2>&1; then
      fetch_ok=1
    fi

    if [ "$fetch_ok" = "1" ] && git -C "$dest" rev-parse --verify "origin/$base" >/dev/null 2>&1; then
      git -C "$dest" checkout -B "$base" "origin/$base" 2>/dev/null || true
      git -C "$dest" reset --hard "origin/$base" 2>/dev/null || true
      git -C "$dest" clean -fd 2>/dev/null || true
      log "[$name] base refreshed @ $(git -C "$dest" rev-parse --short HEAD 2>/dev/null) (origin/$base)"
    else
      log "WARN: [$name] fetch failed or origin/$base unresolvable — dispatching off cached base" >&2
    fi
  done
}

# ---------------------------------------------------------------------------
# _readonly_copy <name> <host-path>
# rsync a non-git src folder into $CODE_RO_DIR/<name> as a read-only reference
# (write bits stripped). The lead can read it for context but cannot push it.
# ---------------------------------------------------------------------------
_readonly_copy() {
  local name="$1" host_path="$2"
  local dest="$CODE_RO_DIR/$name"
  log "[$name] no git repo — copying read-only reference ..."
  mkdir -p "$dest"; chmod -R u+w "$dest" 2>/dev/null || true
  rsync -a --delete \
    --exclude '.git/' \
    --exclude '.venv/' \
    --exclude 'node_modules/' \
    --exclude '__pycache__/' \
    --exclude '*.pyc' \
    --exclude '.DS_Store' \
    "$host_path" "$dest"/
  chmod -R a-w "$dest" 2>/dev/null || true
  log "[$name] read-only reference @ $dest"
}

# ---------------------------------------------------------------------------
# prepare_code_repos
# Discover every immediate subfolder of the host ../src tree (mounted RO at
# $SRC_HOST) and prepare it for the lead:
#   - git repo  -> clone fresh into $CODE_DIR/<name> at the repo's OWN current
#                  branch; push auto-opens an MR against that branch.
#   - non-git   -> read-only reference copy under $CODE_RO_DIR/<name>.
# Falls back to a single TARGET_REPO_URL clone if no src folders are found.
# Never touches the host working copies (clones are fresh from origin).
# ---------------------------------------------------------------------------
prepare_code_repos() {
  banner
  setup_ssh
  git config --global user.name  "${GIT_AUTHOR_NAME:-Artisyn Agent}"
  git config --global user.email "${GIT_AUTHOR_EMAIL:-artisyn.agent@dataart.com}"
  mkdir -p "$CODE_DIR" "$CODE_RO_DIR"

  local found=0 path name base url
  if [ -d "$SRC_HOST" ]; then
    log "scanning host src tree ($SRC_HOST) for code folders ..."
    for path in "$SRC_HOST"/*/; do
      [ -d "$path" ] || continue
      name="$(basename "$path")"
      case "$name" in .*) continue ;; esac   # skip dotfolders
      found=$((found + 1))
      # Per-repo failures must NOT abort the run (callers may use `set -e`):
      # guard every clone/copy so one bad repo is logged and the rest proceed.
      if [ -d "$path/.git" ]; then
        url="$(git -C "$path" remote get-url origin 2>/dev/null || true)"
        base="$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
        [ "$base" = "HEAD" ] && base="${TARGET_BASE_BRANCH:-main}"   # detached -> fallback
        if [ -z "$url" ]; then
          log "WARN: [$name] has .git but no 'origin' remote; copying read-only instead." >&2
          _readonly_copy "$name" "$path" || log "WARN: [$name] read-only copy failed; continuing." >&2
        else
          _clone_or_update "$name" "$url" "$base" || log "WARN: [$name] clone/update failed; continuing." >&2
        fi
      else
        _readonly_copy "$name" "$path" || log "WARN: [$name] read-only copy failed; continuing." >&2
      fi
    done
  fi

  if [ "$found" -eq 0 ]; then
    if [ -n "${TARGET_REPO_URL:-}" ]; then
      log "no src folders discovered; falling back to single TARGET_REPO_URL mode."
      local fb_name fb_base
      fb_name="$(basename "${TARGET_REPO_URL%.git}")"
      fb_base="${TARGET_BASE_BRANCH:-main}"
      _clone_or_update "$fb_name" "$TARGET_REPO_URL" "$fb_base" || log "WARN: [$fb_name] clone/update failed; continuing." >&2
    else
      log "WARN: no code folders under $SRC_HOST and no TARGET_REPO_URL set." >&2
      log "       The lead will run without a prepared code repo (planning / read-only only)." >&2
    fi
  fi
  banner
}

# ---------------------------------------------------------------------------
# lead_persona <agent-name>
# Echo the lead persona body (frontmatter stripped) + runner framing to stdout.
# ---------------------------------------------------------------------------
lead_persona() {
  local agent_name="$1"
  local agent_file="$DST/.claude/agents/${agent_name}.md"

  if [ ! -f "$agent_file" ]; then
    log "ERROR: lead agent file not found: $agent_file" >&2
    exit 5
  fi

  # Strip YAML frontmatter (between the first pair of --- delimiters).
  local body
  body="$(awk 'NR==1 && /^---[[:space:]]*$/ {f=1; next} f==1 && /^---[[:space:]]*$/ {f=0; next} f==0 {print}' "$agent_file")"

  cat <<PERSONA
You are operating as ${agent_name}, the orchestrator and the single entry point for all
work in this workspace. You are the TOP-LEVEL session: never dispatch ${agent_name} as a
subagent. Follow the lead-orchestration runbook at
.claude/skills/lead-orchestration/SKILL.md (five-anchor implementer brief,
sequencing/ADR gate, cost-loop capture). Delegate to the appropriate specialist agents
via the Agent tool, based on what the work needs.

HEADLESS AUTONOMY (this is a non-interactive run — no operator is watching): act
fully autonomously. When you face a choice of approaches, pick the best one and
proceed — do NOT stop to ask "which approach would you prefer?" or wait for
confirmation; there is no one to answer and the session will simply exit with the
work unfinished. Drive the ticket all the way through: implement, run the tests, pass an ISOLATED
code review (dispatch a fresh code-review subagent and fix every Critical and High
finding before the PR), commit with a structured body, and push (which opens the MR). Only stop early if
you are genuinely blocked (e.g. missing credentials or an impossible requirement),
and in that case end with a clear "BLOCKED: <reason>" so the run is recorded as a
failure rather than a false success. Never leave implemented work uncommitted.

CODE REPOS (container runner specifics): every folder under the workspace's
sibling src/ tree has been prepared for you:
  - Git-backed repos are cloned FRESH (never the host working copy) into
    /artisyn/code-repo/<name>, checked out at that repo's own base branch. Make
    code changes there on a feature branch and push — an MR auto-opens per repo.
  - Non-git folders are copied READ-ONLY to /artisyn/code-readonly/<name> as
    reference material; never modify or try to push them.
Touch only the repo(s) the ticket actually requires. If a change spans multiple
repos, push each separately — one MR opens per pushed repo, each targeting that
repo's own base branch.

MERGE REQUEST OVERVIEW (container runner specifics): the implementer pushes from
the container's own code repo clone (/artisyn/code-repo/<name>) and the merge
request is auto-created by git push options. GitLab derives the MR TITLE from the
commit SUBJECT and the MR DESCRIPTION from the commit BODY. So brief the implementer
to write a STRUCTURED
COMMIT BODY that doubles as the MR overview, with these sections, above the
Co-Authored-By trailer:
  Summary: one line on what ships and why.
  Changes: 2-5 bullets of the concrete changes.
  Refs: <ticket-key>
  Test plan: how to verify (commands / expected output).
A bare commit body (only the trailer) produces an empty MR overview, which is not
acceptable. Keep the subject as <type>(<scope>): <ticket-key> <desc> with an accurate scope.

--- ${agent_name} role definition ---
${body}
PERSONA
}

# ---------------------------------------------------------------------------
# _install_git_safety_wrapper <dest-dir>
# Write a thin git shim into <dest-dir>/git that rejects config-injection flags
# before exec-ing the real git binary (BUG-0066 AC1 defence-in-depth).
#
# Injection vectors blocked:
#   git -c <key>=<val>           core.sshCommand / alias.x=!shell / protocol.ext
#   git --exec-path=<path>       arbitrary helper binary
#   git -c alias.x=!<shell>      shell alias invocation (same -c vector)
#
# Normal operations pass through unchanged:
#   git status / diff / log / add / commit / push / pull
#   git checkout / switch / branch / fetch / rebase / merge
#   git rev-parse / remote / show / stash / tag / config (read-only)
#   git -C <path> <subcommand>   path-local invocations
#
# Residual risk: git -C <path> -c <key>=<val> <sub> is ALSO blocked here even
# though Claude Code's allowedTools "Bash(git -C *)" pattern would admit the
# command at the CC level.  This wrapper is the OS-level backstop.
#
# Usage: call this function, then prepend <dest-dir> to PATH before invoking
# claude; clean up <dest-dir> after claude exits.
# ---------------------------------------------------------------------------
_install_git_safety_wrapper() {
  local dest="$1"
  local real_git
  real_git="$(command -v git)"
  # Write the shim.
  cat > "$dest/git" << WRAPPER_EOF
#!/usr/bin/env bash
# git safety shim — BUG-0066 injection guard.
# Rejects config-injection flags; passes everything else to real git.
_REAL_GIT="${real_git}"

_die() { echo "[git-wrapper] BLOCKED: \$*" >&2; exit 126; }

# Walk the argument list once; reject forbidden patterns wherever they appear.
# This covers both "git -c foo=bar status" and "git -C /p -c foo=bar status".
_prev=""
for _arg in "\$@"; do
  # -c <key>=<value>  or  --config-env  or  --exec-path=<path>  or  --exec-path
  case "\$_arg" in
    -c|--config-env)
      _die "config-injection flag '\${_arg}' is not permitted (BUG-0066)" ;;
    --exec-path|--exec-path=*)
      _die "exec-path override '\${_arg}' is not permitted (BUG-0066)" ;;
  esac
  # If previous arg was -c, this arg is the <key>=<value>; already blocked above
  # because we reject the -c token itself.  Extra guard for shell alias exec form:
  #   the value of a -c arg matching "alias.*=!.*" or "core.sshCommand" is caught
  #   by blocking -c outright.
  _prev="\$_arg"
done
unset _prev _arg

exec "\$_REAL_GIT" "\$@"
WRAPPER_EOF
  chmod 0755 "$dest/git"
}

# ---------------------------------------------------------------------------
# run_claude <agent-name> <dispatch-prompt>
# Run one headless lead dispatch. Returns claude's exit code.
# After return, sets globals: __dispatch_cost_usd, __dispatch_tokens,
# __dispatch_cost_label (STORY-0048 AC1-AC4).
# ---------------------------------------------------------------------------
run_claude() {
  local agent_name="$1"
  local dispatch="$2"
  local persona
  persona="$(lead_persona "$agent_name")"
  local flags=( -p "$dispatch"
    --append-system-prompt "$persona"
    --permission-mode "${CLAUDE_PERMISSION_MODE:-acceptEdits}"
    --output-format json )   # JSON for cost capture (STORY-0048); verbose output goes to stderr
  # The implementer writes to the per-repo clones under $CODE_DIR, which is OUTSIDE
  # the workspace cwd — make it an additional working dir so acceptEdits auto-accepts
  # edits there instead of prompting (headless can't answer prompts).
  flags+=( --add-dir "${CODE_DIR:-/artisyn/code-repo}" )
  # BUG-0066 AC1: narrow the allowedTools from the broad "Bash(git *)" wildcard to
  # explicit git subcommands.  This removes the config-injection surface at the
  # Claude Code permission layer: "git -c <key>=<val>" does not match any of the
  # patterns below (it would need "Bash(git -c *)") and is therefore denied outright.
  #
  # "Bash(git -C *)" is retained for path-local invocations ("git -C /path status").
  # That pattern still admits "git -C /path -c evil" at the CC layer, which is why
  # _install_git_safety_wrapper (below) provides a second OS-level backstop that
  # rejects -c/-exec-path regardless of where they appear in the argument list.
  #
  # History: BUG-0051 showed that a narrow add/commit/push-only list left the agent
  # unable to run git status/checkout so it built a subprocess git wrapper.  The list
  # below covers the full branch→commit→push→MR workflow without reopening BUG-0051.
  flags+=( --allowedTools \
    "Bash(git status *)" \
    "Bash(git diff *)" \
    "Bash(git log *)" \
    "Bash(git show *)" \
    "Bash(git add *)" \
    "Bash(git commit *)" \
    "Bash(git push *)" \
    "Bash(git pull *)" \
    "Bash(git fetch *)" \
    "Bash(git checkout *)" \
    "Bash(git switch *)" \
    "Bash(git branch *)" \
    "Bash(git rebase *)" \
    "Bash(git merge *)" \
    "Bash(git stash *)" \
    "Bash(git tag *)" \
    "Bash(git remote *)" \
    "Bash(git rev-parse *)" \
    "Bash(git config *)" \
    "Bash(git init *)" \
    "Bash(git clone *)" \
    "Bash(git -C *)" \
  )
  # BUG-0066 AC1 (defence-in-depth): install a thin git shim that blocks -c /
  # --exec-path injection flags at the OS level, covering the residual "git -C /p
  # -c evil" case that the per-subcommand allowlist cannot catch.  The shim is
  # placed first on PATH so the claude subprocess and everything it spawns see it.
  local _git_wrap_dir
  _git_wrap_dir="$(mktemp -d)"
  _install_git_safety_wrapper "$_git_wrap_dir"
  local _orig_path="$PATH"
  export PATH="$_git_wrap_dir:$PATH"

  # Include .mcp.json if it exists in the workspace.
  [ -f ".mcp.json" ] && flags+=( --mcp-config .mcp.json )
  [ "${RUNNER_VERBOSE:-1}" = "1" ] && flags+=( --verbose )

  # Capture the JSON result; verbose lines continue to reach the operator via stderr.
  # tee lets the JSON flow through to the caller's stdout (visible in container logs)
  # while also writing to the temp file for cost parsing.
  local _result_file
  _result_file="$(mktemp)"
  # No RETURN trap — use explicit cleanup below to avoid clobbering the caller's
  # RETURN trap (do_dispatch sets its own trap for before_snap / _cost_out_file).

  claude "${flags[@]}" | tee "${_result_file}"
  local _rc=${PIPESTATUS[0]}

  # Restore PATH and clean up wrapper dir before cost parsing.
  export PATH="$_orig_path"
  rm -rf "$_git_wrap_dir"

  # Parse cost regardless of exit code (best-effort, STORY-0048 AC5).
  _parse_dispatch_cost "${_result_file}"
  rm -f "${_result_file}"   # explicit cleanup (H2 fix: no RETURN trap)

  return "${_rc}"
}

# ---------------------------------------------------------------------------
# _parse_dispatch_cost <result-file>
# Parse cost/token data from a claude --output-format json result file.
# Sets globals:
#   __dispatch_cost_usd   — float string, or "" if unavailable
#   __dispatch_tokens     — integer string, or "" if unavailable
#   __dispatch_cost_label — display label (e.g. "~$0.05 (est., API-list) / 1500 tokens")
# Non-fatal: on any parse failure all globals are empty strings.
# ---------------------------------------------------------------------------
_parse_dispatch_cost() {
  local _result_file="$1"
  __dispatch_cost_usd=""
  __dispatch_tokens=""
  __dispatch_cost_label="unknown USD / unknown tokens"

  [ -f "${_result_file}" ] || return 0

  local _tracker="${SPECS_TRACKER_BIN:-/usr/local/bin/specs_tracker.py}"
  local _prices_arg=""
  local _runner_dir
  _runner_dir="$(dirname "${BASH_SOURCE[0]}")"
  local _default_prices="${_runner_dir}/model-prices.json"
  local _prices_file="${MODEL_PRICES_FILE:-${_default_prices}}"
  [ -f "${_prices_file}" ] && _prices_arg="--prices-file ${_prices_file}"

  local _parsed
  # shellcheck disable=SC2086
  _parsed="$(python3 "${_tracker}" parse-cost \
    --result-file "${_result_file}" \
    ${_prices_arg} 2>/dev/null)" || return 0

  # Extract fields from the JSON output using python3 (stdlib-only).
  __dispatch_cost_usd="$(printf '%s' "${_parsed}" | \
    python3 -c "import sys,json; d=json.loads(sys.stdin.read()); v=d.get('cost_usd'); print('' if v is None else v)" \
    2>/dev/null || true)"
  __dispatch_tokens="$(printf '%s' "${_parsed}" | \
    python3 -c "import sys,json; d=json.loads(sys.stdin.read()); v=d.get('tokens'); print('' if v is None else v)" \
    2>/dev/null || true)"
  __dispatch_cost_label="$(printf '%s' "${_parsed}" | \
    python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('label','unknown USD / unknown tokens'))" \
    2>/dev/null || true)"
}
