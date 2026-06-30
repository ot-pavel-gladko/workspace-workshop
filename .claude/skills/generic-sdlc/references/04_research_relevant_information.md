# SOP_STEP: Research Relevant Information

step_name: research_relevant_information

## Overview

Conduct research on relevant technologies, libraries, or existing code that could inform the design, while collaborating with the user for guidance.

## Constraints

- Research MUST be descriptive and evidence-based, not prescriptive
- You MUST document findings neutrally without advocating for specific solutions
- You MUST explicitly capture unknowns, assumptions, and information gaps
- You SHOULD document multiple approaches or perspectives when found
- You MUST present trade-offs neutrally for later decision-making in the design phase
- You MUST NOT make design decisions during research phase
- **CONTEXT REFRESH:** You MUST re-read [agentic_context_refresh.md](agentic_context_refresh.md) protocol at the start of this step to restore awareness of skill constraints and project state
- **KNOWLEDGE SOURCES:** You MUST follow the [agentic_knowledge_sources.md](agentic_knowledge_sources.md) checklist to discover ALL available knowledge sources before planning research. This includes human knowledge (email, messages, meetings, Confluence), external knowledge (open source, publications), internal workspace resources (subagents, KNOW.md), agentic catalog (skills, agents), and project infrastructure (Jira, Figma, schemas, templates)
- **CODE KNOWLEDGE:** If code intelligence (KNOW.md files) is missing or insufficient for the target area, You MUST follow the [agentic_code_knowledge_extraction.md](agentic_code_knowledge_extraction.md) subflow to extract structured code knowledge before proceeding with research
- **TEMPLATE AUDIT:** If the implementation produces rendered output (HTML, PDF, email), You MUST grep template files for variable names BEFORE naming any data model fields. Template variable names are the contract — DTO/model fields MUST match them exactly
- **SUBAGENT RESEARCH:** If specialized subagents are available (discovered via `use_subagent ListAgents`), You MUST delegate domain-specific research to them in parallel. You MUST pass explicit codebase paths and relevant context to subagents
- **BINARY CONTENT:** You MUST NOT inline base64 content (images, attachments) in the conversation because it blows up context. Save to disk and reference by path instead
- You MUST discover and list available tools for research, assessment, and discovery
- You MUST present discovered tools to the user with brief descriptions of what each tool does
- You MUST ask the user which tools they want you to use for research
- You MUST respect user's tool selection throughout the research process
- You MUST discover and list user-provided input files from:
  - {project_name}/requirements/context/ (project context and guidelines)
  - {project_name}/requirements/artifacts/ (data samples, specifications, documentation)
- You MUST present discovered input files to the user
- You MUST ask the user which files are relevant for research
- You MUST incorporate relevant user-provided files into the research plan
- You MUST create {project_name}/research/research-plan.md to document the research plan
- You MUST identify areas where research is needed based on the requirements
- You MUST propose an initial research plan that includes:
  - Topics to investigate (what to research)
  - Tools to use for each topic (how to research)
  - User-provided files to review (context and artifacts)
  - Specific actions to take (searches, file reads, queries, etc.)
  - Areas where user knowledge should be consulted
- You MUST present the initial research plan to the user
- You MUST ask the user for input on the research plan through interactive clarification
- You MUST ask ONLY ONE clarification question at a time about the research plan
- You MUST NOT list multiple questions for the user to answer at once because this overwhelms users
- You MUST follow this exact process for each clarification question:
  1. Formulate a single question about the research plan
  2. Append the question to {project_name}/research/research-plan.md
  3. Present the question to the user in the conversation
  4. Wait for the user's complete response, which may require brief back-and-forth dialogue across multiple turns
  5. Once you have their complete response, append the user's answer to {project_name}/research/research-plan.md
  6. Only then proceed to formulating the next question
- You SHOULD ask clarifying questions about:
  - Which topics are most important or should be prioritized?
  - Which tools should be used for specific research areas?
  - Are there specific resources (files, websites, documentation) to focus on?
  - Should any topics be added or removed from the plan?
  - Areas where the user has existing knowledge to contribute
- You MUST incorporate user suggestions into the research plan
- You MUST update research-plan.md with all user input and decisions
- You MUST confirm the final research plan with user before executing research
- You MUST NOT proceed with research execution without explicit user approval of the plan
- You MUST inform the user before using each tool during research
- You MUST explain what you're searching for and why before each research action
- You MUST allow user to redirect or stop research at any point
- You MUST document research findings in separate markdown files in the {project_name}/research/ directory
- You SHOULD organize research by topic (e.g., {project_name}/research/existing-code.md, {project_name}/research/technologies.md)
- You MUST include mermaid diagrams when documenting system architectures, data flows, or component relationships in research
- You MUST include links to relevant references and sources when research is based on external materials (websites, documentation, articles, etc.)
- You MUST periodically check with the user during the research process (these check-ins may involve brief dialogue to clarify feedback) to:
  - Share preliminary findings
  - Ask for feedback and additional guidance
  - Confirm if the research direction remains valuable
- You MUST summarize key findings that will inform the design
- You SHOULD cite sources and include relevant links in research documents
- You MUST ask the user if the research is sufficient before proceeding to the next step
- You MUST offer to return to requirements clarification if research uncovers new questions or considerations
- You MUST NOT automatically return to requirements clarification after research without explicit user direction because this could disrupt the user's intended workflow
- You MUST wait for the user to decide the next step after completing research

## Troubleshooting

### Tool Access Limitations
If you cannot access needed information with available tools:
- You MUST document what information is missing in research-plan.md
- You MUST inform the user about the limitation
- You SHOULD suggest alternative tools or approaches
- You MAY ask the user to provide the information directly or suggest other tools
- You SHOULD continue with available information rather than blocking progress

### Research Plan Clarification Stalls
If the research planning clarification process is not making progress:
- You SHOULD summarize what has been established so far
- You MAY suggest moving forward with the current plan and adjusting later
- You SHOULD identify specific gaps that need user input
- You MAY provide examples or options to help the user make decisions
