# Agentic Enhancement: Evidence & Living Methodology

## Overview

After every implementation cycle, document learnings and update the methodology. The methodology serves as institutional memory across sessions — it's the requirements document for all future implementations in the same domain.

## When to Apply

You MUST run this after validation (post-Step 8, pre-Step 9) or as part of Step 9.

## Steps

### 1. Write Learnings Document

Create `{project_name}/implementation/learnings-{group_or_feature}.md` containing:

**Constraints:**
- You MUST include: summary table (stories, files, tests, time), key findings, bugs found, patterns reused
- You MUST include the compliance audit results
- You MUST include open items for the team
- You MUST distinguish between pre-existing bugs found vs bugs in new code

### 2. Update Methodology

If `{project_name}/methodology.md` exists, update it. If not, create it.

**Constraints:**
- You MUST add new gotchas discovered during this cycle (numbered, with source attribution)
- You MUST add new patterns discovered (with "do this / don't do this" examples)
- You MUST update effort estimates (estimated vs actual) for calibration
- You MUST NOT remove existing gotchas because they represent accumulated institutional knowledge
- You SHOULD organize gotchas by source (which group/feature discovered them)

### 3. Update Implementation Summary

If an implementation summary exists, update cumulative stats.

**Constraints:**
- You MUST update story counts, test counts, total effort
- You MUST update the "what's remaining" section
- You SHOULD include a progress table showing all groups/features and their status

## Methodology Document Structure

```markdown
# Implementation Methodology

## Mandatory Steps Per Cycle
### Phase 0: [Pre-implementation checks]
### Phase 1: [Design]
### Phase 2: [Implementation]
### Phase 3: [Testing]
### Phase 4: [Evidence]

## Known Gotchas
| # | Gotcha | Impact | How to Catch | Source |
|---|--------|--------|-------------|--------|
| 1 | ... | ... | ... | Group A |

## Existing Patterns
| Operation | Pattern | Don't Do |
|-----------|---------|----------|
| ... | ... | ... |

## Test Infrastructure
| Layer | Tool | What It Tests |
|-------|------|---------------|

## File Modification Checklist
- [ ] Item 1
- [ ] Item 2
```

## Constraints

- You MUST create learnings for every implementation cycle because they feed into the next cycle's design
- You MUST update methodology after every cycle because accumulated gotchas prevent repeating mistakes
- The methodology document MUST be treated as a requirements document — future implementations MUST follow it
- You SHOULD present methodology updates to the user: "Added {N} new gotchas, {M} new patterns to methodology"
