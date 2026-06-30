# SOP_STEP: Develop Implementation Plan

step_name: develop_implementation_plan

## Overview

Create a structured implementation plan with a series of steps for implementing the design.

## Constraints

- **CONTEXT REFRESH:** You MUST re-read [agentic_context_refresh.md](agentic_context_refresh.md) protocol at the start of this step
- **METHODOLOGY:** If a methodology document exists, You MUST load it and ensure the plan follows all accumulated patterns and avoids all known gotchas
- **PATTERN-BASED GROUPING:** If multiple work items exist, You SHOULD group them by implementation pattern (not business feature). Implement the simplest pattern first to establish methodology, then each subsequent group benefits from accumulated learnings
- **COMPILE-CHECK CADENCE:** You MUST include compile/build checks after every file change in the plan, not just at the end
- **VALIDATION STEP:** You MUST include a post-implementation validation step in the plan that follows [agentic_validation_compliance.md](agentic_validation_compliance.md)
- **EVIDENCE STEP:** You MUST include an evidence/learnings step in the plan that follows [agentic_evidence_methodology.md](agentic_evidence_methodology.md)
- You MUST create an implementation plan at {project_dir}/implementation/plan.md
- You MUST include a checklist at the beginning of the plan.md file to track implementation progress
- You MUST format the implementation plan as a numbered series of detailed steps
- You MUST ensure each step results in working, demoable functionality that provides value
- You MUST sequence steps so that core end-to-end functionality is available as early as possible
- You MUST break down the implementation into a series of discrete, manageable steps
- You MUST ensure each step builds incrementally on previous steps
- You MUST prioritize incremental progress and early validation
- You MUST ensure no big jumps in complexity at any stage
- You MUST ensure each step integrates with previous work (no hanging or orphaned code)
- Each step in the plan MUST be written as a clear implementation objective
- Each step MUST begin with "Step N:" where N is the sequential number
- You MUST ensure each step includes:
  - A clear objective
  - General implementation guidance (dimension-specific details from skill)
  - Test requirements: what tests to write and what they validate
  - How it integrates with previous work
  - Demo description (explicit description of working functionality that can be demonstrated)
- You MUST NOT include excessive implementation details that are already covered in the design document because this creates redundancy and potential inconsistencies
- You MUST assume that all context documents (requirements, design, research) will be available during implementation
- **TESTING MANDATE:** You MUST include a dedicated testing step in the plan that requires:
  - Writing local test suites that validate the implemented code against requirements
  - Deriving test scenarios from BOTH the code logic AND the original requirements/ACs
  - Running all tests locally and ensuring they pass before marking implementation complete
  - Test types to consider: unit tests (logic), integration tests (contracts/templates), compile checks (type safety)
- **SUBAGENT VALIDATION DURING IMPLEMENTATION:** If subagents are available, the plan MUST include steps where a code expert subagent reviews the implementation against the design and requirements. This catches bugs that the implementer misses due to context blindness
- You SHOULD prioritize test-driven development where appropriate
- You MUST ensure the plan covers all aspects of the design
- You SHOULD sequence steps to validate core functionality early
- You MUST ensure the checklist items correspond directly to the steps in the implementation plan
