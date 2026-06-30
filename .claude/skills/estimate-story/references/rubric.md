# Rubric — 5 dimensions, 1–5 each

Score each dimension independently. The score is **about the Story**,
not about who implements it.

---

## 1. Scope

How many *user-observable capabilities* the Story adds or changes.

| Score | Meaning |
|---|---|
| 1 | Tweak to an existing capability (rename, threshold change, copy edit). |
| 2 | One new sub-capability inside an existing capability area (e.g., add "complete" to task statuses). |
| 3 | One new user-observable capability (e.g., "the daily brief lists stale projects"). |
| 4 | Two new related capabilities shipped together (acceptance criteria covers both; splitting would create artificial dependency). |
| 5 | Three or more user-observable capabilities. **Usually a SPLIT candidate**; if you score this, justify why splitting hurts. |

**Test:** If you can write the Story's acceptance criteria as 2–3
black-box behaviours, you're at 2–3. If you need more than 5 bullets to
cover the acceptance criteria, you're at 5 (and probably need to split).

---

## 2. Module-touch breadth

How many code modules (or repo-level surfaces — CI, deployment manifests,
container definitions) the work touches. Use the workspace's code KB —
typically `steering-docs/code-kb/<repo>/MODULES.md` — as the reference.

| Score | Meaning |
|---|---|
| 1 | One module, no cross-cutting concerns. |
| 2 | Two modules, with a defined hand-off. |
| 3 | Three modules. |
| 4 | Four modules, OR three modules + a cross-cutting concern (logging, infrastructure, scheduler, CI). |
| 5 | Five or more modules touched. SPLIT candidate. |

**Note:** "touched" means *changed*. A module that's *only read from*
doesn't count if nothing changes there.

**Note:** A new module being created counts as 1 module-touch for the
new module + N for every existing module that imports the new module's
public surface.

---

## 3. Schema / contract impact

How much the Story changes the **shape** of persisted data or public
function signatures. This dimension proxies *reversibility cost*.

| Score | Meaning |
|---|---|
| 1 | No schema change; no public-signature change. |
| 2 | New optional field on an existing table, OR new optional argument on an existing function. Backward compatible. |
| 3 | New table or relationship; no migration of existing rows needed. |
| 4 | Schema change requiring a data migration (backfill, default values for existing rows). |
| 5 | Breaking schema change (drops a column, renames a column, changes a column type with data loss possible) **or** a load-bearing public-signature change (every caller must adapt). |

**Test:** Imagine reverting the Story 1 month after it ships. How
expensive is the revert? Score 1 = trivial git revert. Score 5 = data
migration + caller fan-out.

**Note:** First-time addition of a vector column (with a chosen
dimension) is score 4 — switching dimensions later is a full re-embed.

---

## 4. Uncertainty

How much *unknown* there is at Story-write time. Proxy for
estimation-risk.

| Score | Meaning |
|---|---|
| 1 | Patterned. Existing P-NNN / DP-NNN cover the approach end-to-end. |
| 2 | Pattern-adjacent. Approach is known but with one judgement call (e.g., picking between two options of a documented pattern). |
| 3 | Partially explored. We've read vendor docs / KB but haven't validated end-to-end. |
| 4 | Research required. New vendor surface, new pattern candidate, or an empirical test is needed to make the design real. |
| 5 | Research-heavy. Multiple unknowns, no comparable prior work in the workspace KB. The Story may need a *spike* sub-story before main implementation. |

**Note:** Uncertainty drops as patterns accumulate. Re-estimating older
Stories under more KB is legitimate.

---

## 5. Integration risk

How exposed the Story is to *failure surfaces beyond your control* —
vendor APIs, OAuth flows, rate limits, network, infrastructure.

| Score | Meaning |
|---|---|
| 1 | Internal-only. No vendor calls, no external network, no infra changes. |
| 2 | One internal infrastructure crossing (existing client, existing infra). |
| 3 | One vendor surface in read-only mode. |
| 4 | One vendor surface with write or auth side-effects (OAuth flow, outbound writes). |
| 5 | Multiple vendors, OR one vendor + admin-consent / scope-change requirement, OR a new infra component (new container, new scheduled job). |

**Note:** Integration risk is *not* the same as schema/contract impact.
A Story can be schema-light (score 1) but vendor-heavy (score 5).

---

## Aggregation

Sum the five scores. Bucket per the table in `SKILL.md` Step 4. Edge
calls (e.g., a sum of 13 or 14) go in the rationale.
