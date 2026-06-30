# SOP_STEP: Create Detailed Design

step_name: create_detailed_design

## Overview

Develop a comprehensive design document based on the requirements and research.

## Constraints

- You MUST review dimensional skill constraints with the user before creating the design document
- **CONTEXT REFRESH:** You MUST re-read [agentic_context_refresh.md](agentic_context_refresh.md) protocol at the start of this step
- **SUBAGENT VALIDATION:** If code expert subagents are available, You MUST send the design to at least one for validation against actual source code. Ask for: exact line numbers for changes, field name verification against contracts/templates, shared service constraints, pre-existing bugs in the area
- **METHODOLOGY CHECK:** If a methodology document exists from previous iterations, You MUST load and follow its gotchas and patterns. The methodology is a requirements document for this design
- **JIRA AC VALIDATION:** If Jira stories exist for the work items, You MUST validate the design against every acceptance criterion, not just the summary. Jira comments often contain stakeholder decisions that override original ACs
- You MUST present all design sections suggested by dimensional skill to the user
- You MUST ask the user to confirm which sections to include in the design document:
  - All sections (comprehensive design)
  - Priority sections only (focused design)
  - Custom selection (user chooses specific sections)
- You MUST ask the user to prioritize sections if they choose priority or custom selection
- You MUST explain that additional sections can be added later if needed
- You MUST create a design plan listing confirmed sections before starting document generation
- You MUST create a detailed design document at {project_dir}/design/detailed-design.md
- You MUST write the design as a standalone document that can be understood without reading other project files
- You MUST include the following core sections in the design document:
  - Overview
  - Detailed Requirements (consolidated from clarification.md)
  - Design Content (structure defined by dimensional skill and user selection)
  - Design Options (if multiple implementation approaches exist)
  - Appendices (dimension-specific findings and considerations)
- You MUST consolidate all requirements from the clarification.md file into the Detailed Requirements section
- You MUST include design options section when more than one implementation approach exists:
  - Limit to maximum three options
  - Document pros and cons for each option
  - Evaluate each option against requirements, constraints, and feasibility
  - Always recommend preferred option with clear rationale
  - Document why other options were not recommended
  - Highlight trade-offs made in the recommendation
- You MUST facilitate user discussion and input on design options if multiple approaches exist
- You MUST get explicit user approval for selected design option before finalizing design
- You MUST update design document with selected option and rationale after user approval
- You MUST include an appendix section that summarizes key findings from previous steps
- You SHOULD include diagrams or visual representations when appropriate using mermaid syntax
- You MUST ensure the design addresses all requirements identified during the clarification process
- You SHOULD highlight design decisions and their rationales, referencing research findings where applicable
- You SHOULD document assumptions and dependencies of selected design option
- You MAY suggest hybrid approaches combining elements from multiple options
- You MUST review the design with the user and iterate based on feedback
- You MUST explicitly ask the user if they are ready to proceed to next step
- You MUST NOT proceed to the next step without explicit user confirmation because this could skip important design refinement
- You MUST offer to return to requirements clarification or research if gaps are identified during design

## Troubleshooting

### Design Complexity
If the design becomes too complex or unwieldy:
- You SHOULD suggest breaking it down into smaller, more manageable components
- You SHOULD focus on core functionality first
- You MAY suggest a phased approach to implementation
- You SHOULD return to requirements clarification to prioritize features if needed
