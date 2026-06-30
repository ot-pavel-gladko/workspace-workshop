# SOP_STEP: Planning Iteration Checkpoint

step_name: planning_iteration_checkpoint

## Overview

Determine if planning refinement is needed before proceeding to implementation, validate readiness, and get approval. This is the final gate before execution.

## Constraints

- **CONTEXT REFRESH:** You MUST re-read [agentic_context_refresh.md](agentic_context_refresh.md) protocol at the start of this step
- You MUST summarize the implementation plan and readiness for implementation
- **READINESS VALIDATION:** You MUST validate before presenting options:
  - Is the implementation plan feasible and realistic?
  - Are all dependencies identified and sequenced?
  - Is the work breakdown complete and implementable?
  - Does the plan include validation steps (compile checks, tests)?
  - Does the plan include evidence/learnings steps?
  - If a methodology doc exists, does the plan follow its patterns?
- You MUST present the validation summary: "Plan: {X} steps. Dependencies: {resolved/pending}. Validation steps: {included/missing}. Methodology compliance: {yes/gaps}."
- You MUST explicitly ask the user if they want to:
  - **Approve and proceed** to implementation
  - **Conditional approval** — proceed with noted conditions
  - **Refine plan** — adjust steps, sequencing, or scope
  - **Return to design** — if design gaps identified during planning
- **GATE DECISION:** You MUST document the decision in {project_name}/implementation/planning-checkpoint.md:
  - Decision: approved / conditional / needs refinement
  - Conditions: any caveats (e.g., "proceed but revisit X after step 3")
  - Risks: identified risks and mitigations
  - Open items: unresolved questions carried into implementation
- **POST-IMPLEMENTATION:** If implementation has been executed, You MUST run the validation and compliance audit from [agentic_validation_compliance.md](agentic_validation_compliance.md) before final approval
- **EVIDENCE:** You MUST create learnings and update methodology following [agentic_evidence_methodology.md](agentic_evidence_methodology.md)
- You MUST create a summary document at {project_dir}/summary.md listing:
  - All artifacts created during the process
  - Brief overview of design and implementation plan
  - Gate decisions made at each checkpoint
  - Next steps for implementation
  - Any areas that need further refinement
- You SHOULD highlight any risks or open issues that need attention during implementation
- You SHOULD confirm resource availability for implementation
- You SHOULD present the summary to the user in the conversation
- You MAY suggest additional preparation steps before implementation if needed
- You MUST NOT proceed to implementation without explicit approval
- You MUST offer to return to planning or design if gaps are identified

---
