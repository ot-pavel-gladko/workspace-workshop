---
name: generic-sdlc
description: |
  Guides users through structured software development lifecycle from idea to implementation using Prompt-Driven Design (PDD) process. Systematically progresses from rough idea to detailed design with implementation plan. Creates project structure with organized artifacts, conducts requirements clarification through guided questions, performs technology and library research, develops comprehensive design documentation, and generates implementation plans. Provides iterative checkpoints for research, design, and planning validation. Manages project artifacts including requirements documentation, research findings, detailed designs, and implementation plans. Integrates with PIR documentation and template creation processes.
  
  Use when starting new projects from initial concepts, converting requirements to designs, following structured development processes, or organizing project documentation. 
  
  Triggers: "Start SDLC process for", "Design feature", "Requirements to design", "PDD process", "Create project structure", "Development lifecycle", "Design system".

license: Proprietary - DataArt Core IP. Cannot copy, modify, or use without DataArt permission.
metadata:
  category: sdlc-process
  level: "101"
  author: dataart-aila
  version: "1.1.0"
  last_updated: "2026-03-17"
  tags: [sdlc, requirements-analysis, system-design, project-structure, implementation-planning, prompt-driven-design, documentation, agentic, knowledge-discovery, compliance-audit, living-methodology]
---

# Generic SDLC

Guide users through structured software development lifecycle from idea to implementation using Prompt-Driven Design (PDD) process.

## Quick Start

**What it does:** Systematic progression from rough idea to detailed design with implementation plan

**When to use:**
- "Start SDLC process for [idea]"
- "Design [feature/system]"
- "Requirements to design"
- "PDD process"

**Inputs:**
- Project idea/description
- User responses to clarification questions
- Research sources
- Design preferences

**Outputs:**
- Project structure with artifacts
- Requirements documentation
- Research findings
- Detailed design document
- Implementation plan (optional)
- Summary and PIR

**Process:** 9 steps with 3 validated gates (research, design, planning)

---

## Core Workflow

The SDLC process consists of 9 core steps with checkpoints:

### Step 1: Create Project Structure

See [01_create_project_structure.md](references/01_create_project_structure.md)

Set up directory structure for project artifacts:
- Project folders (`{project_name}/`)
- Context files (`requirements/context/`)
- Artifacts directory (`requirements/artifacts/`)
- Research, design, implementation folders

### Step 2: Initial Process Planning

See [02_initial_process_planning.md](references/02_initial_process_planning.md)

Determine approach and sequence:
- Ask user preference for starting point
- Explain iterative nature
- Set expectations

### Step 3: Requirements Clarification

See [03_requirements_clarification.md](references/03_requirements_clarification.md)

Refine initial idea through guided questions:
- Ask ONE question at a time
- Document answers in `{project_name}/clarification.md`
- Build thorough specification

### Step 4: Research Relevant Information

See [04_research_relevant_information.md](references/04_research_relevant_information.md)

Research technologies, libraries, existing code:
- Discover available tools
- Create research plan with user
- Execute research
- Document findings in `{project_name}/research/`

### Step 5: Research Iteration Checkpoint

See [05_research_iteration_checkpoint.md](references/05_research_iteration_checkpoint.md)

Decide if more clarification/research needed:
- Summarize current state
- Ask user to decide next step
- Loop back if needed

### Step 6: Create Detailed Design

See [06_create_detailed_design.md](references/06_create_detailed_design.md)

Develop comprehensive design document:
- Review design sections with user
- Create design plan
- Generate design with options
- Save to `{project_name}/design/detailed-design.md`

### Step 7: Design Iteration Checkpoint

See [07_design_iteration_checkpoint.md](references/07_design_iteration_checkpoint.md)

Decide if design refinement needed:
- Summarize design state
- Ask user to decide next step
- Loop back if needed

### Step 8: Develop Implementation Plan (Optional)

See [08_develop_implementation_plan.md](references/08_develop_implementation_plan.md)

Create structured implementation plan:
- Ask user: "Create implementation plan or proceed to PIR?"
- If plan: Create with checklist, sequence steps
- If Jira: Ask user to create tasks
- If other: Ask user what they want to plan

### Step 9: Planning Checkpoint & PIR

See [09_planning_iteration_checkpoint.md](references/09_planning_iteration_checkpoint.md)

Final validation and documentation:
- Validate plan feasibility (if created)
- Create summary at `{project_name}/summary.md`
- Ask user for approval
- **Execute PIR:** Create post-implementation review documenting the design process

### Validated Gate Pattern (Enhanced from PDD)

At each checkpoint (Steps 5, 7, 9), the agent:
1. **Validates understanding** — checks completeness against requirements/research/design
2. **Presents validation summary** — "X/Y requirements covered, Z gaps identified"
3. **Offers structured options** — proceed / iterate / add sources / refine
4. **Documents gate decision** — approved / conditional / needs refinement + conditions + open items
5. **Records in checkpoint file** — persistent record of decisions for audit trail

This ensures the user stays in control while the agent proactively validates completeness.

---

## Agentic Enhancements (v1.1)

The following enhancements extend the core workflow with agentic best practices discovered through real-world implementation. They activate automatically when the workspace has the right infrastructure (subagents, KNOW.md, Jira, etc.).

### Knowledge Source Discovery
See [agentic_knowledge_sources.md](references/agentic_knowledge_sources.md)

Before research, systematically discover ALL available knowledge sources across 5 categories: human knowledge (email, messages, meetings, Confluence), external knowledge (open source, publications), internal workspace resources (subagents, KNOW.md), agentic catalog (skills, agents), and project infrastructure (Jira, Figma, schemas, templates). Integrated into Step 4.

### Code Knowledge Extraction
See [agentic_code_knowledge_extraction.md](references/agentic_code_knowledge_extraction.md)

When KNOW.md files are missing or insufficient, guide the user through extracting structured code intelligence using `aila-meta`. Includes iterative documentation enhancement for undocumented code. Triggered during Step 4 when code knowledge gaps are detected.

### Context Refresh Protocol
See [agentic_context_refresh.md](references/agentic_context_refresh.md)

In long-running sessions (hours), re-read skill knowledge, methodology, and plan at every step transition to prevent "forgetting" initial agreements. Applied at the start of every step.

### Validation & Compliance Audit
See [agentic_validation_compliance.md](references/agentic_validation_compliance.md)

Post-implementation compliance check via subagents against 8 mandatory rules (type safety, DRY, contract compliance, integration completeness, etc.). Integrated into Step 9.

### Evidence & Living Methodology
See [agentic_evidence_methodology.md](references/agentic_evidence_methodology.md)

After every implementation cycle, document learnings and update the methodology. The methodology serves as institutional memory across sessions — accumulated gotchas and patterns become requirements for future implementations. Integrated into Step 9.

---

## Usage

### Start SDLC Process
```
User: "Start SDLC process for [project idea]"
AI: Executes Step 1 (Create Project Structure)
```

### Continue from Checkpoint
```
User: "Continue SDLC from design checkpoint"
AI: Resumes from Step 7 (Design Iteration Checkpoint)
```

### Skip to Specific Step
```
User: "Jump to implementation planning"
AI: Loads Step 8 (checks prerequisites)
```

---

## Project Structure

```
{project_name}/
├── rough-idea.md             # Initial idea
├── clarification.md          # Requirements Q&A
├── requirements/
│   ├── context/              # Project context (in memory)
│   └── artifacts/            # Data samples, specs (on demand)
├── research/
│   ├── research-plan.md      # Research plan
│   ├── topic1.md             # Research findings
│   └── topic2.md
├── design/
│   └── detailed-design.md    # Complete design
├── implementation/
│   └── plan.md              # Implementation plan (optional)
└── summary.md               # Final summary
```

---

## Execution Pattern

**For each step:**
1. Load step file from references/
2. Follow step instructions
3. Save artifacts to project directory
4. Proceed to next step or checkpoint

**At checkpoints:**
1. Summarize current state
2. Ask user: "Continue, iterate, or skip?"
3. Branch based on user decision

**At final checkpoint:**
1. Validate all artifacts
2. Create summary document
3. Execute PIR skill to document process
4. Ask user for final approval

---

## Customization

**Implementation Planning Options:**

1. **Structured Plan** - Use step 8 to create detailed plan
2. **Jira Tasks** - User creates tasks in Jira manually
3. **Other Tool** - User plans in their preferred tool
4. **Skip** - Proceed directly to PIR

---

## Integration with Other Skills

**PIR Creation:**
- At end of process, use [post-implementation-review](../post-implementation-review/SKILL.md)
- Document: requirements, research, design, decisions

**Template Usage:**
- If design involves templates, use [template-creation-validation](../template-creation-validation/SKILL.md)

---

## Benefits

1. **Structured Approach** - Systematic progression from idea to plan
2. **Iterative** - Checkpoints allow refinement
3. **Documented** - All artifacts saved for reference
4. **Flexible** - Skip or customize steps as needed
5. **Integrated** - Works with other skills (PIR, templates)

---

## Notes

**No Agent Orchestration:**
- This skill is for direct Kiro CLI usage
- No specialized agents required
- User drives the process with AI guidance

**Minimal Overhead:**
- Only create artifacts that add value
- Skip deliverables (use PIR instead)
- Implementation plan optional

**Focus on Design:**
- Core value is requirements → research → design
- Implementation planning flexible based on user needs