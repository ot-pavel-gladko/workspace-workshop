# SOP_STEP: Research Iteration Checkpoint

step_name: research_iteration_checkpoint

## Overview

Determine if further requirements clarification or research is needed before proceeding to design. Validate understanding completeness and document the gate decision.

## Constraints

- **CONTEXT REFRESH:** You MUST re-read [agentic_context_refresh.md](agentic_context_refresh.md) protocol at the start of this step
- You MUST summarize the current state of requirements and research to help the user make an informed decision
- **UNDERSTANDING VALIDATION:** You MUST verify completeness before presenting options:
  - Are all key requirements documented in clarification.md?
  - Are there unanswered questions or open items from research?
  - Are there knowledge source gaps (sources identified but not yet consulted)?
  - Are there contradictions between requirements and research findings?
- You MUST present the validation summary: "Requirements: {X} items documented. Research: {Y} topics covered. Gaps: {list or 'none identified'}."
- You MUST explicitly ask the user if they want to:
  - **Proceed** to creating the detailed design
  - **Iterate requirements** — return to requirements clarification based on research findings
  - **Iterate research** — conduct additional research based on requirements
  - **Add knowledge sources** — consult additional sources identified but not yet used
- You MUST support iterating between requirements clarification and research as many times as needed
- You MUST ensure that both the requirements and research are sufficiently complete before proceeding to design
- **GATE DECISION:** You MUST document the decision in {project_name}/research/research-checkpoint.md:
  - Decision: proceed / iterate requirements / iterate research
  - Conditions: any caveats or items to address during design
  - Open items: unresolved questions carried forward
- You MUST NOT proceed to the design step without explicit user confirmation because this could skip important refinement steps

---
