# Anthropic Orchestration Checklist

Fourteen rubric items used in Phase 2 of the skill. Each item has a **rule**, a **why**, an **evidence source** (what to look at in the agent file), and a **proposed-fix template** the skill uses to construct diffs.

Severity guidance:
- `critical` — orchestration is broken or will mis-route; the agent won't reliably be invoked or will exceed its scope.
- `warn` — the agent works but leaks tokens, confuses the orchestrator, or invites misuse.
- `info` — style or polish.

---

## 1. Role -> Scope -> NOT-for/Handoff shape in `description`

**Rule.** The first sentence of `description` states the role. A middle clause states the scope (repo prefix, domain, tech stack). A closing clause states what the agent is **NOT** for and where to hand off.

**Why.** The `description` is the only text the orchestrator sees when picking an agent. An unfocused description causes mis-routing, which burns orchestrator tokens and specialist tokens on the wrong task.

**Evidence.** Frontmatter `description:` line.

**Severity when violated.** `critical` if scope is missing or contradictory; `warn` if the handoff clause is absent but scope is clear.

**Proposed-fix template.**
```
---
-description: "<current text>"
+description: "<role sentence>. <scope clause — repos/domains/stack>. NOT for <negative scope>; use <target agent> for that."
---
```

---

## 2. Explicit trigger-phrase hints in `description`

**Rule.** The description contains at least one imperative phrase the user would naturally type ("Use for 'implement X'", "Answers questions on...", "Consult for ...").

**Why.** Claude Code picks agents partly by description-vs-user-prompt semantic match. Descriptions without trigger verbs lose to agents that have them.

**Evidence.** Frontmatter `description:` line; search for quoted example phrases or an "Use for / Consult for / Answers" clause.

**Severity.** `warn`.

**Proposed-fix template.** Inject one clause such as `Use for '<verb phrase>', '<verb phrase>'.` near the end of the role sentence.

---

## 3. Negative constraint ("NOT for X")

**Rule.** Description contains an explicit `NOT for ...` clause pointing at another agent.

**Why.** Prevents adjacent-agent mis-routing (e.g. business analyst vs. domain expert, orchestrator vs. specialist). Without it, the orchestrator collapses distinct roles.

**Evidence.** Frontmatter `description:` line.

**Severity.** `critical` if two agents have overlapping scope and neither says NOT-for the other; `warn` otherwise.

**Proposed-fix template.** Append `NOT for <overlap scope> — use <other agent>.`

---

## 4. Orchestrator top-level invocation constraint

**Rule.** Any agent whose tools include `Agent` or `use_subagent` has an **Invocation constraint** section in its body explaining that it must be invoked from the top-level session and must refuse orchestration if invoked as a sub-agent.

**Why.** Claude Code does not reliably allow nested delegation. Without the constraint, a sub-agent invocation of the orchestrator silently fails or does the work partially.

**Evidence.** Body section heading (look for "Invocation", "Nest", "Top-level").

**Severity.** `critical`.

**Proposed-fix template.** Add a section:
```markdown
## Invocation constraint

You orchestrate via the `Agent` tool — this only works when you run as the **top-level session**.
If you were invoked as a sub-agent, stop orchestrating, return a message directing the caller to the specialist, and do not attempt the work yourself.
```

---

## 5. Scope Boundary (single-area confinement for code/domain specialists)

**Rule.** Every specialist whose responsibility maps to a single repo or a single bounded area (a sub-directory, a microservice, a UI module) has a **Scope Boundary** section that names the single path prefix it may read and forbids reads into other areas.

**Why.** Without a scope boundary, specialists grep across the whole workspace — wasting tokens and producing noisy answers.

**Evidence.** Body heading `## Scope Boundary` or equivalent; look for a concrete path prefix.

**Severity.** `critical` for agents that clearly own one area; `info` for orchestrators or workspace-wide reference agents.

**Proposed-fix template.** Add a section:
```markdown
## Scope Boundary

You operate only inside `<path-prefix>/`. Do not read, grep, or glob outside this prefix.
If a cross-area answer is needed, return a pointer and stop — the orchestrator will delegate to the other specialist.
```

---

## 6. Knowledge-First Protocol

**Rule.** Every specialist that touches source code has a **Knowledge-First Protocol** (or similarly named) section instructing it to consult documented knowledge before grepping source. A typical order: project KB -> `PATTERNS.md` -> `KNOW.md` -> source code. Grep/glob into source is the *last* resort.

**Why.** KB and index reads are ~10x cheaper than full-repo grep. Skipping the cascade is the single biggest cause of wasted tokens in code specialists.

**Evidence.** Body heading `## Knowledge-First Protocol`, `## Code Navigation`, or equivalent; verify the cascade order.

**Severity.** `warn` if present but out of order; `critical` if absent and a KB root exists in the workspace; `warn` if absent and no KB root was detected in Phase 1.

**Proposed-fix template.** Adapt the heading names to the workspace's actual KB paths (detected in Phase 1). Generic shape:
```markdown
## Knowledge-First Protocol

Before touching source code, consult in order:
1. <project KB root> — domain and glossary.
2. <per-repo patterns file, if the workspace maintains one> — known non-obvious patterns.
3. <per-repo knowledge index, if the workspace maintains one> — function/class index.
4. Source — only if steps 1-3 did not answer the question.
```

---

## 7. Pattern Recording Obligation

**Rule.** Every code specialist has a **Pattern Recording** section stating that when a non-obvious code pattern is discovered during a task, it **must** be appended to the repo's patterns index before returning results.

**Why.** Without this, every specialist rediscovers the same patterns. With it, the KB self-improves.

**Evidence.** Body heading `## Pattern Recording` or mention of a patterns file in protocol text. Cross-reference with `.claude/rules/routing.md` if it describes a pattern-recording policy.

**Severity.** `warn`. If no patterns file exists anywhere in the workspace, degrade to `info` and propose creating the convention.

**Proposed-fix template.** Adapt the patterns path to the workspace. Generic shape:
```markdown
## Pattern Recording

When you discover a non-obvious pattern (one you had to grep/glob to find, not documented in the KB), append it to `<patterns-file-path>` before returning. A pattern is worth recording if a future agent would waste >1 query rediscovering it.
```

---

## 8. Write-tool discipline for read-only agents

**Rule.** Any agent whose role is read-only (domain expert, schema reference, catalog reader) declares **no** write tools (`fs_write`, `Write`, `Edit`, `NotebookEdit`). Its `tools` and `allowedTools` in `workspace.py` (when Artisyn-managed) match.

**Why.** A read-only agent with write access can silently corrupt KB files. The capability gap is the enforcement mechanism.

**Evidence.** Frontmatter `tools:` list; cross-check `workspace.py` `Agent(...).tools` and `.allowedTools`.

**Severity.** `critical` — easy to violate by habit; high blast radius.

**Proposed-fix template.** Remove `fs_write` / `Write` / `Edit` from the list in both `.md` and `workspace.py`. If the agent genuinely needs to update KB files, re-classify it as a **structured writer** in the body with a write-scope clause; do not leave it read-only in name only.

---

## 9. Body length proportional to scope

**Rule.** Agent bodies stay under **400 lines**. Agents that exceed this are candidates for either (a) content pruning or (b) splitting into sub-agents (hand off to Phase 4 for token-gain evaluation).

**Why.** Every agent body is loaded on every invocation. A 900-line body costs ~7 KB per call; a split often cuts that by 50%+.

**Evidence.** `wc -l` on the agent `.md` file.

**Severity.** `info` for 400-600 lines (flag for review); `warn` above 600 lines.

**Proposed-fix action.** Add a Phase 4 sub-domain candidate entry for this agent; do not emit a body diff in Phase 2 for this item.

---

## 10. Act-and-scope directive

**Rule.** The body contains an **Act and scope** section (or equivalent) telling the agent to act once it has enough, to recommend one option rather than survey all of them, and to do the simplest thing the task needs.

**Why.** Without it, agents over-ask for confirmation and over-engineer — both burn tokens and slow delivery.

**Evidence.** Body heading `## Act and scope` or a sentence pairing "act when you have enough" with "simplest thing".

**Severity.** `warn`.

**Proposed-fix template.**
```markdown
## Act and scope

When you have enough to act, act — don't stall for confirmation you don't need. When you
are genuinely weighing options, recommend one rather than listing them all. Do the simplest
thing the task needs; add no step, file, or abstraction the request didn't ask for.
```

---

## 11. Evidence directive

**Rule.** The body contains an **Evidence** section telling the agent to verify a finding against a tool result before stating it, and to flag anything unverified.

**Why.** Specialists that assert unverified claims propagate errors the orchestrator then trusts.

**Evidence.** Body heading `## Evidence` or a "verify before you state … say so if unverified" sentence.

**Severity.** `warn`.

**Proposed-fix template.**
```markdown
## Evidence

Before you state a finding, verify it against something real — a file you read, a command
you ran, a result you got back. If you could not verify it, say so plainly ("unverified — I
didn't find …") rather than phrasing a guess as fact.
```

---

## 12. Report — outcome-first

**Rule.** The body contains a **Report** section instructing the agent to open its reply with the outcome (answer/decision/what-changed), then the supporting detail.

**Why.** Outcome-first replies are scannable; the orchestrator and the user get the bottom line without parsing a narrative.

**Evidence.** Body heading `## Report` or an "lead with the outcome / bottom line first" sentence.

**Severity.** `warn`.

**Proposed-fix template.**
```markdown
## Report

Lead your reply with the outcome — the answer, the decision, or what changed — then the
supporting detail beneath it. The reader should get the bottom line in the first line or
two, not after a walkthrough of how you got there.
```

---

## 13. Reference — output-shape example (artifact-emitting agents)

**Rule.** Any agent that emits a structured artifact (a report, a ticket, a pipeline change, a findings table) carries a short concrete example of that output's shape.

**Why.** A worked example removes ambiguity about format far more cheaply than prose describing it.

**Evidence.** Body heading `## Output shape` / `## Reference` or an inline fenced example of the artifact. Read-only/advisory agents (e.g. a pure domain expert) are `NA`.

**Severity.** `info`.

**Proposed-fix template.** Add a short fenced example of the artifact the agent produces, sized to a few lines.

---

## 14. Memory format (pattern-recording agents)

**Rule.** Any agent that records patterns to a KB/index file states the memory discipline: one entry per pattern with a one-line summary, update don't duplicate, delete what proves wrong.

**Why.** Without it, pattern files accrue near-duplicates and stale entries and stop being trusted.

**Evidence.** The agent's recording-rule section. Agents that write no pattern/index file are `NA`.

**Severity.** `info` if a recording rule exists but lacks the discipline; `NA` if the agent records nothing.

**Proposed-fix template.** Insert into the agent's existing recording-rule section:
```markdown
One entry per pattern: a one-line summary plus the file's documented fields.
Update an existing entry rather than appending a near-duplicate, and delete one that
later proves wrong — the index earns trust only by staying accurate.
```

---

## Applying the rubric

For each agent in the workspace, record one row per rubric item — even `pass` rows — so the report can show "14/14 pass" confidently. The report template (`references/report-template.md`) includes a rubric-coverage matrix that expects this structure.
