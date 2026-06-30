# Workshop: Configure an Artisyn Delivery Workspace — Knowledge Base & Jira-enabled Agents (BA + Design)

**Level:** 01-intermediate
**Duration:** ~35 minutes (≈15 + 15 + 5 across the three sessions; agents do most of the work and the Code KB step is pre-built — see Step 3. Varies with agent/model latency.)
**Prerequisites:** A freshly bootstrapped Artisyn Delivery Workspace (post `aila-workspace bootstrap`), with at least one repo discovered under `../src`.
**Date:** 2026-06-16

---

## Overview

You start from an **initial** (bootstrapped-but-empty) workspace and finish with a
**fully configured** one: all three knowledge-base layers authored, a new
Business Analyst agent wired in, that BA connected to Jira over MCP, and the
setup self-test passing.

The workshop mirrors a real configuration session. It is driven by the
`artisyn-workspace status` checklist — every session advances it — and uses the
catalog extraction skills (`extract-project-kb`, `extract-code-kb`,
`extract-domain-kb`) rather than freehand authoring.

**Learning Outcomes:**
- Author the three KB layers (project-kb, code-kb, domain-kb) and an INDEX, keeping each on the correct side of the client-IP / DataArt-IP boundary.
- Add a specialist agent (the Design agent) the supported way (prompt → `workspace.py` → regenerate), and validate the init-provided BA is wired to the KB — not by hand-editing `.claude/agents/`.
- Scope an MCP server's tools **per role** — BA authors Jira issues; the lead drives workflow statuses (read + transition).
- Wire an MCP server (Jira) and scope its tools to a single agent.
- Run the workspace self-test, diagnose the common wiring failures, and mark the setup phases complete.

---

## Prerequisites

**Required:**
- A bootstrapped workspace: `workspace.py`, `.claude/agents/`, `.mcp.json`, `workspace-profile.yaml`, and a `.venv` with the Artisyn packages installed.
- At least one repo checked out under `../src` and listed in the profile.
- `artisyn-workspace status` runs and shows Group 1 (CLI & bootstrap) complete.

**Recommended:**
- Familiarity with the target repo's stack.
- Access to whatever Jira instance you will connect (network/VPN + ability to mint a Personal Access Token).

**Setup:**
- Activate the venv: `source .venv/bin/activate`
- Confirm `pyright` (or your language's LSP) and `uvx` are on PATH.
- Run `artisyn-workspace status` once and note the **NEXT** call-out — you will re-run it after every session to watch progress.

---

## Conventions & placeholders

This workshop is run by many people against **different** workspaces and repos.
Nothing below is hard-coded to one environment — wherever you see a `<…>`
placeholder, substitute your own value. Derive them like this:

| Placeholder | Meaning | How to find yours |
|---|---|---|
| `<WS>` | Your workspace's agent name prefix | The `name=` prefix of the agents in `workspace.py` / `.claude/agents/*.md` (e.g. if your lead is `acme-lead`, then `<WS>` = `acme`). |
| `<repo>` | The repository directory name | The folder name under `../src/` (also the `name:` under `repos:` in `workspace-profile.yaml`). |
| `<your PAT>` / `<your email/username>` | Your Jira credentials | A Personal Access Token you mint, plus your Jira login. |

> **Fixed for this org:** the Jira instance is **`https://support.dataart.com`**
> (Atlassian Data Center) for every user of this workshop — it is *not* a
> placeholder. Only your PAT and username differ. (SSL verification is off because
> it is an internal Data Center host.)
| `python3.x` | Your venv's Python version | `ls .venv/lib/` — substitute the actual `python3.NN` folder. |

> Run every command **from your workspace root** (the directory containing
> `workspace.py`). All paths in this workshop are relative to it, so they work
> regardless of where your workspace lives on disk or what it is named.

---

## How this workshop runs

This is a **guided, hands-on** workshop — not a script to paste straight through.
Whoever facilitates it (a person, or the `workshop-executor` skill) runs each step
like this:

1. **Explain the *why* first.** Every step opens with a **Why this matters** block —
   read it before touching any command. If the *why* isn't clear, stop and ask;
   running steps without understanding them is exactly how a workspace ends up
   subtly misconfigured.
2. **The learner does the hands-on, not the facilitator.** The facilitator guides,
   verifies, and unblocks — it does **not** run the commands for the learner. You
   type them and paste back what you see.
3. **Stop at every Checkpoint.** Each step ends with a checkpoint and a short
   confirm/reflect prompt. Don't advance until the expected result matches and you
   can answer the prompt.
4. **Ask "why" anytime.** If a command or a choice isn't clear, ask before running it.
5. **Sessions run consecutively — never in parallel.** Finish a session in full (all
   its steps *and* checkpoints) before starting the next. The order is a hard
   dependency, not a suggestion: Session 2's agent wires to the KB authored in
   Session 1, and Session 3 validates the output of both. Steps within a session are
   likewise sequential.

> **Facilitator note (incl. `workshop-executor`):** present each step's
> **Why this matters** and **Checkpoint** verbatim, pause for the learner to act,
> and confirm the checkpoint together before continuing. Never complete a step for
> the learner.

> **Working tips (keep these handy):**
> - Keep a **second terminal** open and re-run `artisyn-workspace status` there to
>   watch progress advance after every step — it's read-only and safe to run anytime.
> - Press **Ctrl+O** to expand tool output / follow a dispatched sub-agent's progress
>   while it runs.
> - You can **stop at any checkpoint and resume the same session** later with
>   `claude --resume <session-id>` (see Step 9) — progress is saved on disk regardless.

---

## Workshop Structure

### Session 1: Project Knowledge Base (~15 min)

**Objectives:**
- Author the project-kb (client-IP) layer from a real source.
- Author the DevOps runbook docs.
- Build the code-kb navigation index with `extract-code-kb`.
- Author the vendor-general domain-kb layer.
- Author `steering-docs/INDEX.md`.

**Content:**
1. The three-layer KB model and its ownership boundary (project-kb & code-kb = client IP; domain-kb = reusable DataArt IP).
2. Choosing a KB source when there are no docs/Confluence: extract from the repo.
3. The `extract-*-kb` skills and the "authored" heuristic the status check uses.

**Hands-on Lab:** Step 0 (pre-flight: precondition gate + baseline) + Detailed Steps 1–5 below.

**Resources:**
- Skill: `extract-project-kb` — project-kb from docs/Confluence/repo
- Skill: `extract-code-kb` — hierarchical, LLM-driven module map
- Skill: `extract-domain-kb` — the reusable domain layer

**Validation:**
- [ ] `artisyn-workspace status` shows Group 2 (Domain knowledge) = 4/4.
- [ ] `steering-docs/INDEX.md` present and links all three layers.

---

### Session 2: Agents Configuration — specialists + Jira (~15 min)

**Objectives:**
- **Validate** the **Business Analyst** agent (created at workspace init) and ensure
  it's wired to the KB; **add** a new **Design/wireframe** agent via `workspace.py`.
- Wire Jira as an MCP server and scope its tools **per role**: the **BA authors**
  issues (create/edit/transition); the **lead drives** workflow statuses
  (read + transition) — author vs. driver.
- Provide the secret and verify the connection.

**Content:**
1. Agents are generated artifacts: edit `workspace.py` + `prompts/`, never `.claude/agents/*.md`.
2. Tool tiers and KB `resources` lists; resources are **read on demand** (Code Navigation Protocol), not auto-injected.
3. Per-role tool scoping: the same MCP server, different tool subsets per agent (least privilege).
4. MCP wiring: `.mcp.json` server block + per-agent tool catalogues + `.env` secret.

**Hands-on Lab:** Detailed Steps 6–9 below.

**Validation:**
- [ ] `python3 workspace.py validate --agent claude` passes.
- [ ] **7 agents** on disk; the BA (from init) is wired to the KB, and the design agent is added.
- [ ] BA lists the full `jira_*` author set; the **lead** lists Jira **read + transition** only (no create/edit).
- [ ] Jira auth probe returns HTTP 200.

---

### Session 3: Validate & complete the workspace (~5 min)

> **Out of scope:** the **pilot task** (phase 15 — walking a real ticket
> end-to-end) is *not* part of this workshop. The workshop finishes at **14/15**;
> the pilot is a follow-up engagement activity (see Next Steps).

**Objectives:**
- Run the workspace self-test and fix the common wiring gaps.
- Mark the setup phases complete (`workspace_setup_completed`, `selftest_passed`).

**Content:**
1. The 8 self-test checks and what each proves.
2. The two failures you will most likely hit (missing `skill_catalog.json`; stale code-kb resource paths) and their fixes.

**Hands-on Lab:** Detailed Steps 10–11 + the **Acceptance Check** (in the Validation section) below.

**Validation:**
- [ ] `WORKSPACE_SELFTEST passes` marked.
- [ ] `artisyn-workspace status` shows **14/15** (pilot task intentionally left).

---

## Detailed Steps

### Orientation — what this is and why (present this FIRST)

> **Facilitator (incl. `workshop-executor`): present this orientation to the learner
> verbatim and get a "ready?" before running Step 0 / Pre-flight. Do not jump into the gate.**

👋 **Welcome — here's what you're about to do and why.**

**What this workshop teaches.** You'll **configure an Artisyn Delivery Workspace**
so its AI agents can actually help with your project — turning a freshly
bootstrapped, empty workspace into one that *knows your product and code* and has
the *specialists* to act on it. By the end, the agents stop guessing and start
reasoning from real, grounded knowledge.

**The shape (3 sessions):**
```
   ┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐
   │ 1. KNOWLEDGE BASE│──▶│ 2. AGENTS        │──▶│ 3. VALIDATE      │
   │ project / code / │   │ add BA + Design  │   │ self-test, fix   │
   │ domain + INDEX   │   │ + wire Jira      │   │ gaps, mark done  │
   └──────────────────┘   └──────────────────┘   └──────────────────┘
```
1. **Knowledge Base** — author the three KB layers (project, code, domain) + an INDEX so every agent can ground its answers.
2. **Agents** — validate the init-provided **Business Analyst**, add a **Design** agent, and wire **Jira** over MCP, scoped per role.
3. **Validate** — run the self-test, fix the common wiring gaps, and mark setup complete.

**How it runs.** Hands-on and **why-first**: every step opens with *why it matters*,
**you** run the commands (the facilitator guides and verifies), and you confirm a
checkpoint before moving on. Sessions are **consecutive** — finish one before the
next — and you can **stop at any checkpoint and resume later** (progress is saved on
disk).

**What you'll end with.** A configured workspace at **14/15** setup phases — KB
authored, **7 agents** (incl. the design agent and a Jira-driving lead), self-test
passing. That's the exact foundation the **`implement-feature-agentic-adlc`**
workshop builds on to deliver a real feature.

**Ready to begin?** (yes/no) → on **yes**, continue to Step 0 (Pre-flight).

---

> ## ▶ Session 1 — Project Knowledge Base
> **What you'll achieve:** by the end of this session your workspace has all three
> KB layers (project, code, domain) plus an INDEX — so every agent can *ground* its
> answers in real product and code knowledge instead of guessing. (Starts with a
> pre-flight gate + baseline.)
> **Sequencing:** this is the **first of three consecutive sessions**. Complete it
> fully — every step and checkpoint — before starting Session 2. Do **not** run
> sessions in parallel.

### Step 0: Pre-flight — gate, then capture a baseline (do this BEFORE Session 1)

**Goal:** First **refuse to run** unless you are inside a properly bootstrapped
workspace; then record the *initial* state so that, at the end, you can prove
every change was made **during** the workshop (not pre-existing).

**Why this matters:** Two different failure modes, two guards. The *gate* stops you
wasting an hour configuring the wrong directory or an un-bootstrapped folder. The
*baseline* is what later lets you **prove** the workshop produced each change — with
a pristine before-snapshot, "it worked" becomes a diff you can point at, not a
claim. Skip this and you can never cleanly separate the workshop's work from
whatever was there already.

#### 0a. Precondition gate — STOP unless this is a bootstrapped workspace

Run this from the directory you believe is your workspace root. It must print
`GO ✅`; if it prints `STOP ⛔`, do **not** start the workshop — fix the flagged
item first.

```bash
[ -d .venv ] && source .venv/bin/activate 2>/dev/null
ok=1; chk(){ if eval "$2" >/dev/null 2>&1; then echo "  ✓ $1"; else echo "  ✗ $1"; ok=0; fi; }

echo "=== Preconditions: am I inside a bootstrapped Artisyn workspace? ==="
chk "workspace.py present (you are at the workspace root)" "test -f workspace.py"
chk "workspace-profile.yaml present"                       "test -f workspace-profile.yaml"
chk ".claude/agents/ has agent files"                      "ls .claude/agents/*.md"
chk ".mcp.json present"                                    "test -f .mcp.json"
chk ".venv present"                                        "test -d .venv"
chk "artisyn-workspace CLI on PATH"                        "command -v artisyn-workspace"
chk "artisyn_catalog_schema importable (venv active)"      "python3 -c 'import artisyn_catalog_schema'"
chk "Group 1 (CLI & bootstrap) complete"                   "artisyn-workspace status | grep -qE 'CLI & bootstrap.*\(6/6\)'"
chk "at least one repo discovered under ../src"            "ls -d ../src/*/ 2>/dev/null | grep -q ."

echo ""
if [ "$ok" = 1 ]; then
  echo "GO ✅  Bootstrapped workspace detected — continue to 0b (baseline)."
else
  echo "STOP ⛔  This is not a ready workspace. Do NOT run the workshop here:"
  echo "   • Wrong directory?      cd into the folder that contains workspace.py"
  echo "   • venv not active?      source .venv/bin/activate"
  echo "   • Not bootstrapped yet? run 'aila-workspace bootstrap' first, then retry"
fi
```

**Checkpoint:** ✅ The gate prints `GO ✅` (all 9 checks pass).

#### 0b. Capture a baseline

**Instructions** (run from your workspace root):
1. Snapshot the status checklist and the files the workshop will touch:
   ```bash
   artisyn-workspace status | tee .workshop-baseline-status.txt

   find steering-docs .claude/agents .mcp.json workspace.py workspace-profile.yaml prompts \
        -type f 2>/dev/null -exec sha256sum {} \; | sort > .workshop-baseline-manifest.txt
   echo "baselined $(wc -l < .workshop-baseline-manifest.txt) files"
   ```
2. **Assert the baseline is actually pristine** — the workshop only proves
   something if you start unconfigured. This should print `OK`:
   ```bash
   artisyn-workspace status | grep -q "Project KB authored  — 0/" \
     && echo "OK: starting from an unconfigured workspace" \
     || echo "WARNING: KB already partly authored — baseline is NOT pristine; the diff will understate the workshop's work"
   ```
3. Keep both `.workshop-baseline-*` files untouched until the Acceptance Check.

**Expected Result:**
```
baselined <N> files
OK: starting from an unconfigured workspace
```

**Checkpoint:** ✅ `.workshop-baseline-manifest.txt` and `.workshop-baseline-status.txt` exist; baseline confirmed pristine.

---

### Step 1: Author the Project KB

**Goal:** Fill `steering-docs/project-kb/` with client-specific knowledge.

**Why this matters:** Every agent answers business and architecture questions from
the project-kb. While these files are empty stubs, the lead and BA are flying blind
on *what the product is and why it exists* — they'll guess or hallucinate. This is
the foundation layer the rest of the workspace reasons from, so it goes first.

**Pause & check:** Before you start — where will your project knowledge come from
(repo, a docs folder, Confluence)? Decide the source now; the rest of the step branches on it.

**Instructions:**
1. Invoke the skill: `/extract-project-kb`.
2. Pick the **source**. If there is no docs folder and Confluence is disabled
   (`atlassian.enabled: false` in `workspace-profile.yaml`), extract from the
   repo under `../src` — for a template-as-product workspace the repo *is* the
   product.
3. Author all six files: `PROJECT_GOALS.md`, `DOMAINS.md`, `FEATURES.md`,
   `INTEGRATIONS.md`, `GLOSSARY.md`, `TECH_ARCHITECTURE.md`. Ground every fact in
   the actual code (run explorers over backend and frontend rather than guessing).

**Expected Result:**
```
artisyn-workspace status  →  Project KB authored — 5/5 authored
```

**Troubleshooting:**
- *Status shows "4/5 authored" after writing all files* → a file tripped the
  "authored" heuristic (must be **>30 lines AND ≤4 placeholder markers**). Remove
  `TODO`/`<placeholder>`/"to be replaced" filler; replace stub tables with prose.
- *Tempted to invent business goals* → don't. Record only what the source supports; leave genuine unknowns (stakeholder names, dates) as the *only* placeholders.

**Checkpoint:** ✅ Project KB = 5/5 authored.

---

### Step 2: Author the DevOps docs

**Goal:** Fill `steering-docs/project-kb/devops/` with CI/CD & deploy runbooks.

**Why this matters:** Delivery questions ("how do we ship this?", "what's the
branching model?", "what order do migrations run?") are the first to come up and
the easiest to get wrong from memory. Capturing them once, verified against the
repo, gives the devops agent (and humans) one trusted runbook instead of tribal
knowledge scattered across people's heads.

**Instructions:**

> **Note — this is the one KB step with no skill.** Unlike Steps 1, 3, and 4
> (`extract-project-kb` / `extract-code-kb` / `extract-domain-kb`), there is **no
> `extract-devops` skill**. Instead you hand the **responsible agent (the DevOps
> agent) a template** — the five filenames below plus the "verify against the repo"
> constraint — and it authors them. The pattern is *delegate-with-a-template*, not
> *invoke-a-skill*.

1. Delegate to the DevOps agent (it has Bash + repo access): ask it to author
   `BRANCHING.md`, `CICD.md`, `DEPLOYMENT.md`, `ENVIRONMENTS.md`, `PATTERNS.md`.
2. Require it to **verify against the repo** (`.github/workflows/`, `compose*.yml`,
   `deployment.md`, `CONTRIBUTING.md`) — no guesses — and to keep each file
   >30 lines with ≤4 placeholders.

**Expected Result:**
```
artisyn-workspace status  →  DevOps docs authored — 5/5 files present
```

**Checkpoint:** ✅ DevOps docs = 5/5.

---

### Step 3: Build the Code KB (`extract-code-kb`)

**Goal:** A navigable module map under `steering-docs/code-kb/<repo>/`.

**Why this matters:** Without a module map, an agent answering a code question
greps blindly across the whole repo and burns its context window. `MODULES.md`
lets it route to the right module in a single read, then open just that module's
KB — this is the navigation layer that makes code questions fast *and* accurate
instead of slow and lossy.

**Understand what `extract-code-kb` does** (the real skill — a 3-stage map-reduce):
1. **Stage 1 (Haiku, parallel, ~one call per ~20 files):** summarize every source
   file into `_index/files.jsonl` (path, sha256, summary, exports, deps, framework hints).
2. **Stage 2 (Sonnet, ~one call per module):** cluster files into 7–12 modules and
   write one `modules/{name}/KB.md` each (Purpose / Public Interface / Internal
   Structure / Dependencies / Conventions / Files).
3. **Stage 3 (Opus, one call):** synthesize `MODULES.md` — module map, relationship
   diagram, entry points, repo-wide conventions.

For this repo that's **~100 agent calls** — minutes of work and real token cost.

> ⏩ **Workshop shortcut — we emulate this step.** Because every participant uses the
> **same repo** (`full-stack-fastapi-template`), its Code KB is **pre-generated and
> shipped with this workshop**. You drop in a *real, complete* KB (the exact output
> the skill produces) without the ~100-call wait. In a real engagement you'd run
> `/extract-code-kb` against your own repo — try that later; the steps above are
> what it does.

**Hands-on — (a) drop in the Code KB** (run from the workspace root — you can run
this straight from the prompt with the `!` prefix):
```bash
cp -r workshops/configure-workspace-kb-and-agents/assets/code-kb/full-stack-fastapi-template \
      steering-docs/code-kb/
```
> If you completed Step 2, `steering-docs/code-kb/` already exists (the devops docs
> live under it), so no `mkdir` is needed. If you somehow skipped ahead, create it
> first with `mkdir -p steering-docs/code-kb`.

**Hands-on — (b) wire the Code KB to the agents.** Files on disk aren't enough —
the agents have to be *pointed* at `MODULES.md`. A freshly bootstrapped workspace
often still references a stale/legacy path (e.g. `python/KNOW.md`), so wire it
explicitly now. In `workspace.py`:

1. Define the resource constant near the other KB lists (`PROJECT_KB`, `DOMAIN_KB`):
   ```python
   CODE_KB = ["file://steering-docs/code-kb/full-stack-fastapi-template/MODULES.md"]
   ```
2. Add `*CODE_KB` to the **lead** and **full-stack code** agents' `resources=`, and
   **delete any stale `python/KNOW.md` / legacy code-kb paths** the bootstrap left.
3. Regenerate + validate:
   ```bash
   python3 workspace.py generate --agent claude
   python3 workspace.py validate --agent claude
   ```

> **Why wire it now:** agents consume the KB by **reading `MODULES.md` on demand**
> (the Code Navigation Protocol baked into their prompt). If the resource path is
> wrong, the files exist but **no agent ever finds them** — and the failure is
> silent until someone asks a code question. Wiring here makes it proactive; Step 6
> reuses this same `CODE_KB` for the BA + design agents, and Step 10's self-test
> confirms it end to end.

**Expected Result:**
```bash
artisyn-workspace status            # → Code KB built per repo — 1/1 repo(s) documented
find steering-docs/code-kb/full-stack-fastapi-template -type f | wc -l   # → 11
grep -l "code-kb/full-stack-fastapi-template/MODULES.md" .claude/agents/*-lead.md   # lead is wired
```

**Troubleshooting:**
- *Bundle not found* → the workshop folder lives at `workshops/configure-workspace-kb-and-agents/` in the workspace; run the `cp` from the **workspace root** (where `workspace.py` is).
- *`status` still shows 0/1* → confirm `steering-docs/code-kb/full-stack-fastapi-template/MODULES.md` exists after the copy.
- *`generate` fails with `CODE_KB` not defined* → you added `*CODE_KB` to an agent before defining the constant; add the `CODE_KB = [...]` line (b.1) first.
- *Agent later says "I have no code-kb"* → its `resources=` still point at a stale path; that's this wiring — define `CODE_KB`, repoint the lead + full-stack agents, regenerate.
- *Using a different repo?* → the shortcut is repo-specific; for any other repo, run the real `/extract-code-kb` instead of copying (and wire `CODE_KB` to that repo's `MODULES.md`).

**Note on the cache:** `_index/files.jsonl` holds sha256 hashes from the repo at
the time the bundle was generated. If your checkout is a different commit the
incremental-refresh cache is stale, but the KB is fully accurate for navigation —
and the workshop doesn't refresh.

**Checkpoint:** ✅ 11 files present (`MODULES.md` + 9 `modules/*/KB.md` + `_index/files.jsonl`); `status` shows Code KB 1/1; **the lead and full-stack agents reference `MODULES.md`** (no stale `python/KNOW.md`).

---

### Step 4: Author the Domain KB (vendor-general)

**Goal:** Fill `steering-docs/domain-kb/` with **reusable, project-agnostic** know-how.

**Why this matters:** This is the one layer that *outlives* the engagement — vendor
quirks and patterns that accelerate the **next** project. Keeping it strictly
project-agnostic (no client names, no repo code) is what lets it travel between
engagements without leaking client IP. Get the boundary right here and it becomes
reusable DataArt IP; get it wrong and it's just duplicated project-kb.

**Instructions:**
1. **Invoke the skill: `/extract-domain-kb`** — this is a skill-driven step (don't
   dispatch the domain agent directly). The skill reads `project-kb/INTEGRATIONS.md`
   + `DOMAINS.md` as the relevance filter and drives the three output files.
2. Author `GLOSSARY.md` (industry-neutral terms), `VENDORS.md` (per-vendor
   protocol facts + gotchas), `PATTERNS.md` (non-obvious reusable findings in the
   file's Where/What/Detail/Source/Discovered format).
3. **Boundary rule:** NO project/client names, NO repo code, NO secrets/PII. Write
   about the *technologies* (PostgreSQL, JWT, SMTP, Traefik/ACME, Docker Compose,
   GitHub Actions), not "our project uses X".

**Expected Result:**
```
artisyn-workspace status  →  Domain KB authored — 3/3 authored  →  Group 2 = 4/4
```

**Troubleshooting:**
- *Unsure where a fact belongs* → client-specific → `project-kb`; reusable vendor
  fact → `domain-kb`. Run `/review-domain-kb` to have the steward check for leaked
  client specifics before any handoff.

**Checkpoint:** ✅ Domain KB = 3/3.

---

### Step 5: Author `steering-docs/INDEX.md`

**Goal:** One human-readable entry point linking all three layers.

**Why this matters:** Three KB layers are only useful if an agent or human knows
*which one to consult*. INDEX.md is the single entry point that encodes the
boundary rule — business → project-kb, reusable → domain-kb, where-in-code →
code-kb — so nobody has to guess where a piece of knowledge lives (or where new
knowledge should go).

> **"But the agents navigate via `resources=`, not this file — isn't it redundant?"**
> Fair point: agents *do* reach the KB through their `resources=` lists, not via
> INDEX.md. But this file is **still required** for two concrete reasons — it's a
> tracked **status-gate phase** (`artisyn-workspace status` checks for it) and an
> **agent-orientation self-test check** (Step 10) — and it's the human's map for
> *where new knowledge belongs*. It's a deliberate step, not redundant.

**Instructions:**
1. Write `INDEX.md` with a section per layer (project-kb / domain-kb / code-kb),
   the boundary rule, and how agents consume the KB via their `resources=` lists.

**Expected Result:**
```
artisyn-workspace status  →  INDEX.md authored
```

**Checkpoint:** ✅ Group 3 item "INDEX.md authored" is green.

---

> ## ▶ Session 2 — Agents Configuration (specialists + Jira)
> **What you'll achieve:** a workspace whose specialists are ready — the **Business
> Analyst** (created at init) validated and wired to the KB so it reads/writes Jira
> against grounded context, plus a new **Design** agent for on-brand wireframes — with
> Jira scoped per role (BA authors, lead drives statuses).
> **Sequencing:** **Session 1 must be complete first** — the BA and design agents wire
> directly to the project-kb, domain-kb, and code-kb you set up there, so they have
> nothing to ground against until those exist. Run after Session 1, never alongside it.

### Step 6: Validate the BA, add the Design agent

**Goal:** Confirm the **Business Analyst** agent (created at workspace init) exists
and is **wired to the knowledge base**; then add a new **Design** agent for
wireframes — the supported way.

**Why this matters:** A workspace's value is its specialists. The **BA** (turns
vague requests into testable work) ships with the workspace at init — but "exists"
≠ "wired"; it's only useful if its `resources=` actually point at the KB it should
reason from (same lesson as the Code KB step). The **design** agent (on-brand
wireframes before any code) is **not** created at init, so you add it. Adding agents
the **supported way** (`workspace.py` + a `prompts/` file → regenerate) matters
because `.claude/agents/*.md` are generated — hand-edit them and your work is lost on
the next `generate`.

#### 6a. Validate the BA (created at init) — confirm it's KB-connected

1. Confirm it exists:
   ```bash
   ls .claude/agents/*-ba.md            # the BA agent from init
   ```
2. Confirm it's **wired to all three KB layers**. Its `Agent(...)` `resources=` in
   `workspace.py` should be `[*PROJECT_KB, *DOMAIN_KB, *CODE_KB]`. Quick check:
   ```bash
   grep -c "project-kb\|domain-kb\|code-kb" .claude/agents/*-ba.md   # expect refs to all three
   ```
3. **If a KB layer is missing** from the BA's `resources=`, add it in `workspace.py`
   (`resources=[*PROJECT_KB, *DOMAIN_KB, *CODE_KB]`) and regenerate. (A bootstrap may
   wire project/domain but not `CODE_KB` — you defined `CODE_KB` in Step 3, so add it
   here too.)

> If your bootstrap did **not** include a BA, create it the same way you'll create
> the design agent below (flip `agents.include_ba: true`, add the `Agent(...)` block,
> `resources=[*PROJECT_KB, *DOMAIN_KB, *CODE_KB]`).

#### 6b. Add the Design agent (the supported way)

1. **Write the prompt** `prompts/design-expert.md` — role = produce a **single
   self-contained clickable HTML wireframe**; *ground it in the real styles* by
   reading `frontend/src/index.css`, the Tailwind config, and
   `frontend/src/components/ui/` (shadcn primitives); boundaries (prototype, not
   production React).
2. **Add a `TOOLS_DESIGN = TOOLS_EDIT + GITHUB_RW_TOOLS`** composite (it Writes the
   HTML and commits the approved wireframe to the feature branch).
3. **Register the prompt and add the agent:**
   ```python
   Prompt(name='design-expert.md', description='Design / wireframe expert: clickable HTML mockups grounded in the project UI stack and styles'),
   # …
   Agent(
       name='<WS>-design',
       description='Design / wireframe agent … clickable HTML mockups grounded in project-kb + the real UI stack; prototypes, not production code.',
       prompt=W.prompt_ref('design-expert.md'),
       tools=TOOLS_DESIGN, allowedTools=TOOLS_DESIGN,
       resources=[*PROJECT_KB, *CODE_KB],
       model='sonnet',
   ),
   ```
4. **Flip** `agents.include_design: true` in `workspace-profile.yaml`.
5. **Regenerate + validate:**
   ```bash
   python3 workspace.py generate --agent claude
   python3 workspace.py validate --agent claude
   ```

**Expected Result:**
```
BA present & wired to project-kb + domain-kb + code-kb
.claude/agents/<WS>-design.md created · CLAUDE.md & delegation.md now say "7 agents"
Validation: NN/NN checks passed
```

**Troubleshooting:**
- *Edited `.claude/agents/*.md` directly* → those are generated; your edit is lost on the next `generate`. Always edit `workspace.py` + `prompts/`.
- *BA exists but answers without product/code context* → it's not KB-wired; add the missing `*PROJECT_KB`/`*DOMAIN_KB`/`*CODE_KB` to its `resources=` (6a.3) and regenerate.
- *`CODE_KB` not defined* → you should have defined it in Step 3; add `CODE_KB = ["file://steering-docs/code-kb/<repo>/MODULES.md"]` near the other KB lists.
- *"Should the design agent be a skill or a prompt instead?"* → per the **`skills-vs-agents-vs-prompts`** best practice: a **specialized role with its own scoped tool access** → **Custom Agent**; an on-demand *workflow* → Skill; a reusable *template* → Prompt. Design is a role with scoped tools → an **Agent**.
- *Tempted to invent the `Agent(...)` structure from scratch?* → don't. The **`ai-agent-template-first-configuration`** best practice says **reuse the existing pattern** (copy the BA's `Agent(...)` block + a `prompts/*.md`), then after `generate` **scan for leftover placeholders**.

**Checkpoint:** ✅ BA present and wired to all three KB layers; design agent created; **7 agents** on disk; validation passes. Can you say *why* the design agent is an Agent rather than a skill or prompt?

---

### Step 7: Wire Jira as an MCP server

**Goal:** Add the `atlassian-da-jira` MCP server (Data Center via `uvx mcp-atlassian`).

**Why this matters:** An agent that can read and write your tracker closes the loop
from *analysis* to *tracked work* — the BA can pull a ticket and create the stories
it decomposes. Wiring Jira as a named MCP server (rather than ad-hoc scripting)
gives every Jira operation a stable tool name and keeps `.mcp.json` and the agent's
tool list in sync.

**Instructions:**
1. Read the canonical definition for the exact server block + tool names:
   `artisyn_catalog_schema/bootstrap/mcp_servers/atlassian.py` (in the venv).
2. Add the server to `.mcp.json`:
   ```json
   "atlassian-da-jira": {
     "type": "stdio",
     "command": "uvx",
     "args": ["mcp-atlassian", "--env-file", ".env"],
     "env": { "JIRA_URL": "https://support.dataart.com", "JIRA_SSL_VERIFY": "false" }
   }
   ```
3. Flip the profile: `mcp.atlassian.enabled: true`, `jira_enabled: true`
   (leave `confluence_enabled: false` for Jira-only).

**Expected Result:**
```
python3 -c "import json;print(list(json.load(open('.mcp.json'))['mcpServers']))"
→ ['github', 'atlassian-da-jira']
uvx mcp-atlassian --help   # resolves
```

> **Note (from PIR `mcp-flow-documentation`):** MCP operations are driven by a
> **unified config** — the server **key** in `.mcp.json` (`atlassian-da-jira`) must
> exactly match the prefix of the tool names you grant the agent
> (`mcp__atlassian-da-jira__*`). A mismatch is the most common reason an agent
> "has the tools" but every call fails to route.

**Checkpoint:** ✅ `atlassian-da-jira` present in `.mcp.json`; `uvx mcp-atlassian` runs.

---

### Step 8: Scope the Jira tools per role (BA authors, lead drives)

**Goal:** Give the **BA** the full author tool set, and the **lead** a read +
transition subset — the same MCP server, two different scopes.

**Why this matters:** Tools are granted **per agent** on purpose (least privilege).
But "who does what in Jira" splits cleanly by role: the **BA authors** content
(create/edit/link issues, write requirements), while the **lead drives** the
*pipeline* — it moves stories through statuses (In Progress → In Review) as it
orchestrates implementation. So the BA gets create/edit/transition; the lead gets
**read + transition only** (no create/edit). The code and devops agents get **no**
Jira at all. This author-vs-driver split is what lets the orchestrator advance
workflow state without round-tripping to the BA, while keeping issue *creation* in
one place.

**Instructions:**
1. In `workspace.py`, add the tool catalogues (copy the names from `atlassian.py`):
   - `JIRA_RW_TOOLS` (get/search/comment/update/transitions/links/watchers) +
     `JIRA_BA_EXTRA_TOOLS` (`jira_create_issue`, `jira_batch_create_issues`,
     `jira_link_to_epic`, sprint/board tools); then
     `JIRA_BA_TOOLS = JIRA_RW_TOOLS + JIRA_BA_EXTRA_TOOLS`.
   - `JIRA_LEAD_TOOLS = [jira_get_issue, jira_search, jira_get_transitions, jira_transition_issue]`
     — read + transition, **no** create/edit.
2. Scope them:
   - BA agent tools → `TOOLS_DOC + JIRA_BA_TOOLS`.
   - Lead agent tools → `TOOLS_LEAD_FULL + JIRA_LEAD_TOOLS` (add `JIRA_LEAD_TOOLS`
     to the lead's composite).
3. Add a "Jira (via MCP)" section to `prompts/ba-expert.md` (search-before-create,
   link-to-epic, transitions, confirm-before-writing).
4. Regenerate + validate.

**Expected Result:**
```
grep -o "mcp__atlassian-da-jira__[a-z_]*" .claude/agents/<WS>-ba.md   | sort -u | wc -l   → 25
grep -o "mcp__atlassian-da-jira__[a-z_]*" .claude/agents/<WS>-lead.md | sort -u | wc -l   → 4
# and the lead must NOT have jira_create_issue / jira_update_issue
Validation: NN/NN checks passed
```

**Troubleshooting:**
- *MCP wildcards* (`mcp__server__*`) aren't reliable for sub-agents — enumerate every tool name (the catalogue does this).
- *Lead "can't change a status" mid-orchestration* → confirm `JIRA_LEAD_TOOLS` made it onto the lead's composite; the lead transitions, the BA creates.
- *Should code/devops get Jira too?* → no. They touch GitHub; only the BA (author) and lead (driver) touch Jira.

**Checkpoint:** ✅ BA carries 25 `jira_*` tools; the lead carries exactly 4 (read + transition, no create/edit); validation passes.

---

### Step 9: Provide the secret and verify the connection

**Goal:** Authenticate to Jira and load the server.

**Why this matters:** Configuration without a working credential is a silent
dead-end — the tools exist but every call fails. Running a real auth probe *before*
you rely on it turns "should work" into "does work." And the restart isn't
optional: Claude Code only launches MCP servers at startup, so a running session
will never see a server you just added.

**Instructions** — this step is genuinely yours: it involves your personal
credential, which the facilitator won't handle. Do these four in order.

**1. Mint a Jira Personal Access Token** at:
`https://support.dataart.com/secure/ViewProfile.jspa?selectedTab=com.atlassian.pats.pats-plugin:jira-user-personal-access-tokens`

**2. Add it to `.env`** (git-ignored), and mirror the **keys only** (no values) into `.env.example`:

```
JIRA_PERSONAL_TOKEN=<your PAT>
JIRA_USERNAME=<your email/username>
```

> **`JIRA_USERNAME` is usually optional on Data Center.** PAT auth here uses the
> `Authorization: Bearer <token>` header alone, so the PAT by itself authenticates
> (the probe in step 3 works without a username). Add `JIRA_USERNAME` only if a
> specific tool call needs it — don't treat it as mandatory.

**3. Probe connectivity** (respects the Data Center self-signed cert). Copy-paste this whole block — it's a one-liner, no heredoc:

```bash
set -a; source .env; set +a
python3 -c "import os,ssl,urllib.request,json; ctx=ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE; req=urllib.request.Request('https://support.dataart.com/rest/api/2/myself', headers={'Authorization':'Bearer '+os.environ['JIRA_PERSONAL_TOKEN'],'Accept':'application/json'}); print(json.loads(urllib.request.urlopen(req,timeout=12,context=ctx).read())['displayName'])"
```

**4. Restart Claude Code** so it launches the new MCP server (servers start at launch; a running session won't pick up `.mcp.json` edits). Then confirm with `/mcp`.

> **Don't lose your place when you restart.** Claude Code only picks up `.mcp.json`
> changes at launch, so this restart is required — but you can resume the *same*
> session (full workshop context intact) instead of starting over:
> ```bash
> claude --resume <session-id>
> ```
> Find `<session-id>` in the `claude --resume` picker (most recent session), or note
> it before you quit. Progress is on disk regardless, but resuming keeps the
> conversation so the facilitator continues from this checkpoint.

**Expected Result:**
```
<your display name>           # probe authenticated (HTTP 200)
/mcp  →  atlassian-da-jira: connected
```

**Troubleshooting:**
- *NETWORK unreachable* → `support.dataart.com` is internal (Data Center); connect to the DataArt corporate network/VPN.
- *HTTP 401/403* → bad or expired PAT, or insufficient permissions.
- *Tools still absent after editing `.env`* → you must **restart** Claude Code.

**Checkpoint:** ✅ Probe returns your name; `/mcp` shows `atlassian-da-jira` connected.

---

> ## ▶ Session 3 — Validate & complete the workspace
> **What you'll achieve:** proof the whole thing works — the self-test passes, the
> setup phases are marked, and a manifest diff shows exactly what the workshop changed.
> **Sequencing:** **run last.** This session validates the output of Sessions 1 and 2,
> so both must be complete before you start. Never run it in parallel with the others.

### Step 10: Run the self-test and fix the common gaps

**Goal:** Prove agents, KB, skills, and LSP all wire together.

**Why this matters:** Files existing on disk ≠ agents actually using them. The
self-test catches exactly the failures that look fine statically but break on a
real task — stale resource paths, a missing skill-catalog cache, or resources that
are *read on demand* rather than auto-injected. Better to find these now, in a
controlled check, than mid-delivery.

**Instructions:**
1. Walk the 8 checks in `WORKSPACE_SELFTEST.md`. Deterministic ones first:
   - SDK diagnostics: `python3 -c "from artisyn_skill_sdk import aila_self_diagnostics as d; print(d()['providers']['count'])"` (>0).
   - `.claude/skill_catalog.json` present & non-empty.
   - LSP: `command -v pyright`.
2. Live checks: ask the lead agent to summarize the architecture *following its
   Code Navigation Protocol* (i.e. allow it to read `MODULES.md`).

**Expected Result:** All 8 checks pass; lead returns an accurate, KB-cited summary.

**Troubleshooting (the two you will most likely hit):**
- *`skill_catalog.json` missing* → generate it:
  `python3 -m artisyn_skill_sdk.hooks.claude_refresh`.
- *Lead/code agent "has no code-kb"* → its `resources=` may point at stale paths
  (e.g. legacy `python/KNOW.md`). Repoint to
  `steering-docs/code-kb/<repo>/MODULES.md` (define a `CODE_KB` constant, add it to
  the lead and code agents), regenerate.
- *Agent says context "not loaded"* → resources are **read on demand**, not
  injected. Test by letting the agent read its KB files, not by forbidding reads.
- *Leftover `TODO` in a generated agent* → fix the source `prompts/*.md`, regenerate.
- *Diagnostics report 0 providers / far fewer skills than expected* → this is a
  documented recurring failure (PIR **`skill-discovery-debugging`**: skills "vanished"
  after a restart because the discovery layer silently returned an empty list). Check
  `aila_self_diagnostics()` shows **providers > 0** *first* — a healthy provider with a
  stale cache is fixed by the `claude_refresh` hook above; missing *files* are rarely
  the real cause. (Same lesson explains why a freshly *published* resource needs its
  `META.yaml`/cache to be discoverable, not just its content file on disk.)

**Checkpoint:** ✅ 8/8 self-test checks pass.

---

### Step 11: Mark the setup phases complete

**Goal:** Close out the setup checklist (everything except the out-of-scope pilot).

**Why this matters:** The status markers are the workspace's durable record that
setup is genuinely complete and validated. Marking them lets the next person — or
you, weeks later — *trust* the state instead of re-auditing everything from scratch.

**Instructions:**
1. Mark the state markers:
   ```bash
   artisyn-workspace status mark workspace_setup_completed
   artisyn-workspace status mark selftest_passed
   ```

> **Out of scope:** the pilot task (`pilot_task_delivered`) is intentionally
> **not** performed here — it belongs to the first real delivery ticket, not to
> workspace setup. See Next Steps for how to run it later.

**Expected Result:**
```
artisyn-workspace status  →  14/15 (pilot task intentionally left)
```

**Checkpoint:** ✅ Validation group green.

---

## Validation

**Completion Criteria:**
- [ ] Group 2 (Domain knowledge) = 4/4 — project-kb, devops, domain-kb authored; repos reachable.
- [ ] Group 3 (Code & agents) = 3/3 — code-kb built, workspace-setup review marked, INDEX.md authored.
- [ ] Two new agents exist (BA + design), listed in `CLAUDE.md`/`delegation.md`; the BA carries the full Jira author set and the lead carries Jira read + transition (no create/edit).
- [ ] `atlassian-da-jira` MCP server connects and the BA can call `jira_*` tools.
- [ ] `WORKSPACE_SELFTEST passes` marked.

**Success Indicators:**
- `artisyn-workspace status` shows 14/15 (the pilot task, phase 15, is out of scope of this workshop).
- `python3 workspace.py validate --agent claude` passes.
- The lead agent answers architecture questions by navigating the KB.

### Acceptance Check (run at the very end, from your workspace root)

This produces one pass/fail verdict **and** proves provenance against the
Step 0 baseline. It assumes you captured `.workshop-baseline-manifest.txt` first.

**1. Provenance — what the workshop changed vs. the baseline:**
```bash
find steering-docs .claude/agents .mcp.json workspace.py workspace-profile.yaml prompts \
     -type f 2>/dev/null -exec sha256sum {} \; | sort > .workshop-final-manifest.txt

echo "=== files ADDED or CHANGED during the workshop ==="
comm -13 .workshop-baseline-manifest.txt .workshop-final-manifest.txt | sed 's/^[0-9a-f]* */  /'
echo "=== files that did NOT change (should be near-empty deltas only) ==="
echo "changed/added: $(comm -13 .workshop-baseline-manifest.txt .workshop-final-manifest.txt | wc -l) files"
```
`comm -13` lists only `(hash, path)` pairs present in the final snapshot but **not**
the baseline — i.e. exactly the files this workshop created or modified. If a file
you expected (e.g. a `project-kb/*.md`) is **absent** from this list, the workshop
did not actually change it.

**2. Outcome — objective end-state gates (each should pass):**
```bash
artisyn-workspace status | grep -E "Project KB|DevOps docs|Domain KB|Code KB|INDEX.md|complete"
python3 workspace.py validate --agent claude | tail -1
echo "agents: $(ls .claude/agents/*.md | wc -l) (expect 7)"
echo "BA jira tools: $(grep -o 'mcp__atlassian-da-jira__[a-z_]*' .claude/agents/<WS>-ba.md | sort -u | wc -l) (expect 25)"
echo "lead jira tools: $(grep -o 'mcp__atlassian-da-jira__[a-z_]*' .claude/agents/<WS>-lead.md | sort -u | wc -l) (expect 4: read + transition)"
echo "design agent present: $([ -f .claude/agents/<WS>-design.md ] && echo yes || echo NO)"
python3 -c "import json; assert 'atlassian-da-jira' in json.load(open('.mcp.json'))['mcpServers']; print('mcp server: present')"
```

**3. Functional smoke tests (config present ≠ working):**
- Ask the **lead** agent an architecture question → it should answer by reading
  `MODULES.md` (cites the code-kb), proving the KB is reachable.
- After restarting Claude Code, ask the **BA** to run a `jira_search` → proves the
  MCP path works end-to-end.

**Verdict:** the workshop succeeded if (1) every expected KB/agent/MCP file appears
in the changed-files list, (2) all outcome gates pass, and (3) both smoke tests
return real results. Provenance is guaranteed because the baseline was captured on
a pristine workspace (Step 0) — anything in the diff was produced here.

> Cleanup (optional): once verified, delete the snapshots —
> `rm -f .workshop-baseline-manifest.txt .workshop-baseline-status.txt .workshop-final-manifest.txt`.

---

## Resources

**Skills Used:**
- `extract-project-kb` — author the project-kb layer.
- `extract-code-kb` — build the hierarchical code-kb.
- `extract-domain-kb` / `review-domain-kb` — author and govern the domain-kb layer.
- `aila-catalog-sdk` — discover skills/resources and run diagnostics.

**Documentation:**
- `artisyn-workspace status` — the 15-phase checklist driving the workshop.
- `WORKSPACE_SELFTEST.md` — the 8 connectivity checks.
- `artisyn_catalog_schema/bootstrap/mcp_servers/atlassian.py` — canonical Jira MCP definition.

**Tools:**
- `python3 workspace.py generate|validate --agent claude`
- `uvx mcp-atlassian` (Jira/Confluence MCP server)
- `pyright` (Python LSP)

**Support:**
- Common issues are inlined per step (Troubleshooting blocks). The highest-value
  ones: the "authored" heuristic, stale code-kb resource paths, resources being
  read-on-demand, and MCP servers needing a restart.

---

## Next Steps

**After completing this workshop:**
- **Pilot task (out of scope here — phase 15):** run a real ticket end-to-end (lead → BA → code specialist), then `artisyn-workspace status mark pilot_task_delivered` to reach 15/15. This is the first delivery activity, not part of workspace setup.
- Add further specialists (QA, security) the same way (Step 6 pattern).
- Enable Confluence (same `mcp-atlassian` server family) if the BA needs to read/write spec pages.
- Refresh the code-kb after major code changes (`extract-code-kb` Stage 1 is cached by file hash).

---

## References

**This workshop was created from a real configuration session and the following:**

**Skills:**
- `extract-project-kb`, `extract-code-kb`, `extract-domain-kb`, `review-domain-kb` — the KB authoring workflows.
- `workshop-assistant` — workshop structure/template; `workshop-executor` — interactive facilitation model.

**Best Practices:**
- `bootstrap-first` — *applied to Step 0:* stand the workspace's own infrastructure (KB + agents) up **before** using it for delivery; the precondition gate enforces "bootstrapped first."
- `skills-vs-agents-vs-prompts` — *applied to Step 6:* the decision tree (role + scoped tools → Custom Agent) that justifies the BA being an Agent rather than a skill/prompt.
- `ai-agent-template-first-configuration` — *applied to Steps 1 & 6:* reuse existing templates/patterns over generating from scratch, then validate for leftover placeholders (the "authored" heuristic).

**PIRs (lessons applied):**
- `2026-02-22-skill-discovery-debugging` — *applied to Step 10:* discovery can silently return an empty list; check provider count before blaming missing files. Also explains why a published resource needs its `META.yaml`/cache, not just its content file.
- `2026-02-28-mcp-flow-documentation` — *applied to Step 7:* unified config means the `.mcp.json` server key must match the granted tool-name prefixes.

**Other Artifacts:**
- `artisyn_catalog_schema/bootstrap/mcp_servers/atlassian.py` — Jira server block, env vars, and the `JIRA_RW_TOOLS` / `JIRA_BA_EXTRA_TOOLS` catalogues.
- `WORKSPACE_SELFTEST.md` — the validation checks.

**Generated:** 2026-06-16
