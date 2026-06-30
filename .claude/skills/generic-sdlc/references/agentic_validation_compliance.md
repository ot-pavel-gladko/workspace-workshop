# Agentic Enhancement: Validation & Compliance Audit

## Overview

Post-implementation validation using subagents and structured compliance rules. This catches bugs that unit tests and manual review miss — particularly contract mismatches, type safety violations, and integration gaps.

## When to Apply

You MUST run this after implementation (Step 8) and before final checkpoint (Step 9).

## Validation Layers

### Layer 1: Compile/Build Check

**Constraints:**
- You MUST run the project's compile/build command after every file change
- You MUST fix all compile errors before proceeding
- You MUST NOT accumulate changes across multiple files without compiling because errors compound and become harder to diagnose

### Layer 2: Existing Test Suite

**Constraints:**
- You MUST run the existing test suite after implementation
- You MUST verify zero regressions
- If tests fail, You MUST fix before proceeding

### Layer 3: New Test Suites

**Constraints:**
- You MUST write local test suites after implementation — this is not optional because untested code is unverified code
- You MUST derive test scenarios from THREE sources:
  1. **Requirements/ACs** — every acceptance criterion should have at least one test that proves it works
  2. **Code logic** — read the implemented code and identify edge cases, boundary conditions, error paths, and integration points that the requirements didn't explicitly mention
  3. **Failure patterns** — consider what historically breaks in similar code: persistence after save, downstream effects of state changes, boundary values, empty/null inputs, concurrent modifications
- You MUST write as many tests as practical to maximize coverage:
  - Unit tests for individual functions/methods (logic correctness)
  - Integration tests for component contracts (e.g., template + payload → rendered output, API request → response)
  - Compile/type checks as the baseline safety net
- **TEST SCENARIO DERIVATION TECHNIQUES** (borrowed from QA best practices):
  - **Positive scenarios**: Verify each AC works as specified with valid inputs
  - **Negative scenarios**: Verify proper error handling for invalid inputs, missing data, unauthorized access
  - **Boundary values**: Test at limits (0, 1, max, max+1, empty string, null)
  - **Persistence verification**: After save/create, reload and verify data persisted correctly
  - **Downstream effects**: When state changes, verify cascading effects (e.g., price recalculation after cost change, status propagation)
  - **Smoke test**: If feature has >5 fields/paths, write one E2E test that exercises the full happy path
  - **Multiple perspectives**: Consider different user roles, commercial models, or input variants
- You MUST run all tests locally and ensure they pass
- You SHOULD aim for tests that can run without external dependencies (no Docker, no live services) where possible because fast local tests enable rapid iteration
- You MUST NOT consider implementation complete until tests pass

### Layer 3.5: Document Code While Session Has Context

**Constraints:**
- You SHOULD add documentation strings (JSDoc, docstrings, comments) to key functions/methods implemented during this session because the agent currently understands the logic deeply — this understanding will be lost when the session ends
- You SHOULD run `aila-meta --document` (if available) after adding documentation to capture the knowledge in KNOW.md files for future sessions and subagents
- This is especially valuable for complex logic, non-obvious design decisions, and workarounds because future developers (human or AI) will not have the implementation context

### Layer 4: Subagent Compliance Audit

Send a code expert subagent to review the implementation against these rules:

| # | Rule | What to Check |
|---|------|--------------|
| 1 | No unsafe type casts | Search for `as any` on domain objects |
| 2 | No placeholder values | Search for fake UUIDs, TODO URLs, hardcoded test data in production code |
| 3 | No method duplication (DRY) | Compare new methods against existing ones for >60% similarity |
| 4 | Output names match contracts | DTO/model field names match template variables, API contracts, schema fields |
| 5 | Uses existing patterns | New code follows established patterns (formatting, error handling, naming) |
| 6 | Return types match conventions | New methods follow existing return type patterns |
| 7 | Integration complete | All routing, wiring, configuration updated (not just core logic) |
| 8 | Data queries match types | If types were updated, queries were updated too (and vice versa) |

**Constraints:**
- You MUST run the compliance audit via subagent with explicit rules
- You MUST report PASS/FAIL per rule with specific evidence (line numbers, code snippets)
- If any rule FAILs, You MUST fix before proceeding
- You SHOULD adapt rules to the specific codebase (the 8 above are a starting template)

### Layer 5: Visual/Contract Comparison

If the implementation produces visual output (PDF, HTML, email):

**Constraints:**
- You SHOULD create a side-by-side comparison table: design spec element → implementation field → renders correctly?
- You SHOULD flag gaps between spec and implementation
- You MUST document any intentional deviations with rationale

## Compliance Checklist

| # | Check | Status |
|---|-------|--------|
| 1 | Compile/build passes | ☐ |
| 2 | Existing tests pass (zero regressions) | ☐ |
| 3 | New test suites written (from requirements + code + failure patterns) and passing | ☐ |
| 4 | Code documented while session has context (JSDoc/docstrings on key functions) | ☐ |
| 5 | Subagent compliance audit: all rules PASS | ☐ |
| 6 | Visual/contract comparison documented | ☐ |

## Constraints

- You MUST NOT skip the compliance audit because it catches bugs that tests miss (e.g., field name mismatches, integration gaps, type safety violations)
- You MUST present the compliance checklist to the user with results
- You MUST fix all FAIL items before marking implementation as complete
