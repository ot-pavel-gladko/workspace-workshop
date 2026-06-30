# syntax=docker/dockerfile:1
#
# artisyn-workspace-runner — container image that runs an Artisyn workspace's
# configured lead agent headlessly. The top-level `claude -p` session adopts
# the lead persona (injected via --append-system-prompt) and delegates to
# whichever specialist subagents the work needs.
#
# Base is node:24 because Claude Code ships as an npm package. We add:
#   - git    : the implementer branches/commits in the target code repo clone
#   - rsync  : entrypoint copies the read-only workspace mount into a writable
#              tree so the container can modify agents/settings without touching
#              the host workspace
#   - uv/uvx : hooks (.claude/hooks/*.py) and workspace scripts run via
#              `uv run`; MCP servers run via `uvx`
#   - python3: fallback interpreter for hooks
#
# Image is credential-free and internally publishable: no secrets baked in.
# All tokens are injected at run time via env / .env file.
#
# Rollback: `docker compose down` + `docker image rm artisyn-workspace-runner`
# removes it entirely. Nothing here touches the host workspace.
FROM node:24-bookworm

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      git rsync curl ca-certificates python3 openssh-client \
 && rm -rf /var/lib/apt/lists/*

# uv — provides `uv run` (hooks, workspace scripts) and `uvx` (MCP servers).
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
 && ln -sf /root/.local/bin/uv  /usr/local/bin/uv \
 && ln -sf /root/.local/bin/uvx /usr/local/bin/uvx
ENV PATH="/root/.local/bin:${PATH}"

# Claude Code CLI.
RUN npm install -g @anthropic-ai/claude-code

# UI sidecar venv — built at IMAGE-BUILD time (deterministic; no runtime network
# install, which is flaky behind VPNs/proxies). ui-entrypoint.sh reuses this venv.
# The headless artisyn-lead/artisyn-watch services simply never touch it (the
# image is shared by design; the UI dependency lives in the compose "ui" profile).
# Copied separately so this layer caches unless requirements.txt changes.
COPY ui/requirements.txt /artisyn/ui-requirements.txt
RUN uv venv /artisyn/ui-venv \
 && uv pip install --python /artisyn/ui-venv/bin/python -r /artisyn/ui-requirements.txt

COPY lib.sh /usr/local/bin/lib.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
# watch.sh: long-running poll loop for --watch mode (STORY-0007b).
COPY watch.sh /usr/local/bin/watch.sh
# specs_tracker.py: local specs/ story backend for watch mode (TRACKER_TYPE=specs, ADR-0009).
COPY specs_tracker.py /usr/local/bin/specs_tracker.py
# model-prices.json: per-model token pricing for dispatch cost capture (STORY-0048 H3).
COPY model-prices.json /usr/local/bin/model-prices.json
# ui-entrypoint.sh: starts the Chainlit UI sidecar (STORY-0008, opt-in profile "ui").
COPY ui-entrypoint.sh /usr/local/bin/ui-entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/watch.sh /usr/local/bin/ui-entrypoint.sh /usr/local/bin/specs_tracker.py

# Working directory matches the writable workspace copy set by entrypoint.sh.
WORKDIR /artisyn/workspace
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
