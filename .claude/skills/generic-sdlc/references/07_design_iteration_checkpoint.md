# SOP_STEP: Design Iteration Checkpoint

step_name: design_iteration_checkpoint

## Overview

Determine if design refinement is needed before proceeding to implementation planning. Validate that the design addresses all requirements and that the user's understanding is confirmed.

## Constraints

- **CONTEXT REFRESH:** You MUST re-read [agentic_context_refresh.md](agentic_context_refresh.md) protocol at the start of this step
- You MUST summarize the current state of the design document to help the user make an informed decision
- **UNDERSTANDING VALIDATION:** You MUST verify design completeness:
  - Does the design address every requirement from clarification.md?
  - Are all research findings incorporated or explicitly deferred?
  - If design options exist, has the user selected one?
  - Are there assumptions that need user confirmation?
  - If a methodology doc exists, does the design follow its patterns and avoid its gotchas?
- You MUST present the validation summary: "Design covers {X}/{Y} requirements. Options: {selected/pending}. Assumptions: {list or 'none'}."
- You MUST explicitly ask the user if they want to:
  - **Proceed** to implementation planning
  - **Refine design** — add/modify sections
  - **Iterate requirements** — return to requirements clarification based on design gaps
  - **Iterate research** — conduct additional research based on design questions
  - **Review options** — revisit design options (if multiple approaches exist)
- You MUST support iterating between design, requirements clarification, and research as many times as needed
- **GATE DECISION:** You MUST document the decision in {project_name}/design/design-checkpoint.md:
  - Decision: proceed / refine / iterate requirements / iterate research
  - Selected option: (if applicable) with rationale
  - Conditions: any caveats or items to address during planning
  - Deferred items: research findings or requirements intentionally deferred
- You MUST NOT proceed to the implementation planning step without explicit user confirmation because this could skip important design refinement

---
