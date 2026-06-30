# Token-Gain Heuristic

Formula, worked examples, and the procedure for discovering split candidates from the current workspace. The skill only proposes a new agent if the **>=2x token-gain gate** clears with explicit numbers.

## Inputs

Per existing agent, collect:

| Symbol | Source | Fallback |
|---|---|---|
| `parent_body_tokens` | `wc -w` on the agent `.md` x 1.33 (words->tokens approximation) | — |
| `invocations_total` | Count lines in the workspace's agent-usage log directory whose first field matches the agent name | `10` per agent (conservative synthetic baseline) |
| `sub_domain_share` | Fraction of those invocations whose prompt or response mentions the candidate sub-domain (grep on logs) | `0.3` (assume ~30% of a fat agent's traffic concerns the candidate domain) |

Per proposed new agent, estimate:

| Symbol | Typical range | Derivation |
|---|---|---|
| `new_agent_body_tokens` | 800-1500 | Minimal viable agent: description + Scope Boundary + Knowledge-First Protocol + Pattern Recording. Measured from lean agents observed across Artisyn-managed workspaces. |
| `parent_delegation_tokens` | 80-150 per call | Tokens the parent now spends saying "this question is about X — route to `<new-agent>`". |

## Formula

For each candidate split:

```
baseline_cost       = parent_body_tokens * invocations_total * sub_domain_share
post_split_cost     = (new_agent_body_tokens * invocations_total * sub_domain_share)
                    + (parent_delegation_tokens * invocations_total * sub_domain_share)
saved_tokens_total  = baseline_cost - post_split_cost
gate_ratio          = saved_tokens_total / post_split_cost
```

**Propose the new agent only if `gate_ratio >= 2.0`.** Show numerator and denominator in the report. Do not round up.

## Worked example — a hypothetical domain-expert split

Measured:
- `parent_body_tokens` = 5200 (domain expert body is large; covers all business rules)
- `invocations_total` = 40 over the telemetry window
- `sub_domain_share` = 0.55 (majority of expert queries are about one sub-topic per grep of logs)
- `new_agent_body_tokens` = 1100 (focused agent: just the sub-topic's rules)
- `parent_delegation_tokens` = 120

Compute:
```
baseline_cost      = 5200 * 40 * 0.55 = 114,400
post_split_cost    = (1100 * 40 * 0.55) + (120 * 40 * 0.55) = 24,200 + 2,640 = 26,840
saved_tokens_total = 114,400 - 26,840 = 87,560
gate_ratio         = 87,560 / 26,840 = 3.26
```

**3.26 >= 2.0 -> propose.** Report shows the numbers.

## Worked example — a rejected split

Candidate: split a testing specialist into two per-feature testing agents.

- `parent_body_tokens` = 2200
- `invocations_total` = 30
- `sub_domain_share` for feature A = 0.35
- `new_agent_body_tokens` = 1400
- `parent_delegation_tokens` = 100

```
baseline_cost      = 2200 * 30 * 0.35 = 23,100
post_split_cost    = (1400 * 30 * 0.35) + (100 * 30 * 0.35) = 14,700 + 1,050 = 15,750
saved_tokens_total = 23,100 - 15,750 = 7,350
gate_ratio         = 7,350 / 15,750 = 0.47
```

**0.47 < 2.0 -> reject.** Report does not propose the split; it may still flag the parent as a "watch-list" item if traffic grows.

## Discovering candidates from the current workspace

The skill does **not** prescribe a fixed candidate list. Instead, Phase 4 walks the workspace to find them:

1. **Fat agent bodies.** Every agent whose `.md` body exceeds 400 lines (flagged by rubric item 9) is a parent candidate.
2. **Multi-responsibility descriptions.** Every agent whose description lists three or more distinct nouns/scopes (e.g. "handles A, B, and C") is a parent candidate.
3. **Sub-domain extraction.** For each parent candidate, read its body section headings. Group adjacent sections that share a topic noun ("feature-area-A", "subsystem-B", "integration-X", "UI screens", "deployment", ...). Each group is a sub-domain candidate.
4. **Telemetry-grounded filtering (when telemetry is present).** Grep the agent-usage logs for each candidate sub-domain's keywords. If the share of invocations mentioning the keywords is < 0.1, drop the candidate — too small to justify a split.
5. **Apply the gate formula above** to each surviving candidate.

## What if telemetry is absent

Fallback:
- Use `invocations_total = 10` (synthetic floor).
- Use `sub_domain_share = 0.3` (conservative).
- Mark the proposal in the report as **heuristic-only, not telemetry-grounded**.

With these defaults, the gate clears only when `parent_body_tokens >= ~3.2 x new_agent_body_tokens`. In practice: a ~4000+ token parent is required to justify a split without real telemetry.

## Why >=2x and not >=1.1x

A 10% savings rarely justifies the overhead of:
- Another agent to maintain.
- Another entry in `routing.md` and (when Artisyn-managed) `workspace.py`.
- Another failure mode at handoff.
- Orchestrator tokens spent deciding *which* agent to call.

>=2x means the split is obvious and durable even if the heuristic is 30% off. This is deliberately conservative.

## Edge case — two candidates target the same parent

If two candidate splits both clear the gate against the same parent, the skill proposes **both** but flags a dependency: applying either split first will change the parent's body size, reducing the gain of the other. The report orders them by descending `saved_tokens_total` and adds a note: *"Apply in this order; recompute the gate for the second split after applying the first."*
