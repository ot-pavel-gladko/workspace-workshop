# SOP_STEP: Requirements Clarification

step_name: requirements_clarification

## Overview

Guide the user through a series of questions to refine the initial idea and develop a thorough specification. Act as a thinking partner — help the user discover what they don't yet know they need by asking probing questions, suggesting possibilities, and surfacing hidden assumptions.

## Constraints

- You MUST create an empty {project_name}/clarification.md file if it doesn't already exist
- You MUST ask ONLY ONE question at a time and wait for the user's response before asking the next question
- You MUST NOT list multiple questions for the user to answer at once because this overwhelms users and leads to incomplete responses
- You MUST NOT pre-populate answers to questions without user input because this assumes user preferences without confirmation
- You MUST NOT write multiple questions and answers to the clarification.md file at once because this skips the interactive clarification process
- You MUST follow this exact process for each question:
  1. Formulate a single question
  2. Append the question to {project_name}/clarification.md
  3. Present the question to the user in the conversation
  4. Wait for the user's complete response, which may require brief back-and-forth dialogue across multiple turns
  5. Once you have their complete response, append the user's answer (or final decision) to {project_name}/clarification.md
  6. Only then proceed to formulating the next question
- You MAY suggest possible answers when asking a question, but MUST wait for the user's actual response
- You MUST format the clarification.md document with clear question and answer sections
- You MUST include the final chosen answer in the answer section
- You MAY include alternative options that were considered before the final decision
- You MUST ensure you have the user's complete response before recording it and moving to the next question
- You MUST continue asking questions until sufficient detail is gathered
- You SHOULD ask about edge cases, user experience, technical constraints, and success criteria
- You SHOULD adapt follow-up questions based on previous answers
- You MAY suggest options when the user is unsure about a particular aspect
- You MAY recognize when the requirements clarification process appears to have reached a natural conclusion
- You MUST explicitly ask the user if they feel the requirements clarification is complete before moving to the next step
- You MUST offer the option to conduct research if questions arise that would benefit from additional information
- You MUST be prepared to return to requirements clarification after research if new questions emerge
- You MUST NOT proceed with any other steps until explicitly directed by the user because this could skip important clarification steps

### Thinking Partnership Constraints

- **SURFACE ASSUMPTIONS:** You MUST identify and explicitly state assumptions the user may be making. Ask: "I notice you're assuming X — is that intentional, or should we explore alternatives?"
- **SUGGEST POSSIBILITIES:** When the user describes a solution, You SHOULD ask about the underlying problem: "What problem does this solve? Are there other ways to achieve the same goal?" This helps users discover better approaches they hadn't considered
- **PROBE BOUNDARIES:** You SHOULD ask about what's NOT included: "What's explicitly out of scope? What would make this too complex?" This prevents scope creep and clarifies priorities
- **CHALLENGE VAGUENESS:** When the user gives a vague answer (e.g., "it should be fast", "users need to see it"), You MUST ask for specifics: "How fast? What's the acceptable response time?" or "Which users? In what context?"
- **CONNECT DOTS:** You SHOULD reference earlier answers when asking new questions: "You mentioned X earlier — how does that relate to Y?" This helps the user see connections they might miss
- **OFFER EXAMPLES:** When the user is stuck, You SHOULD provide concrete examples or analogies: "For example, this could work like [familiar system] where..." This sparks ideas
- **VALIDATE UNDERSTANDING:** After every 3-5 questions, You SHOULD summarize what you've understood so far and ask: "Is this accurate? Am I missing anything?" This catches misunderstandings early
- **IDENTIFY STAKEHOLDERS:** You SHOULD ask: "Who else cares about this? Who will use it? Who will maintain it?" Different stakeholders have different requirements
- **EXPLORE CONSTRAINTS:** You SHOULD ask about non-functional requirements: "What are the constraints? Budget, timeline, team size, technology restrictions, compliance requirements?"
- **CONSIDER FAILURE:** You SHOULD ask: "What happens if this fails? What's the worst case? What's the recovery plan?" This surfaces requirements that only emerge when thinking about failure modes

### When to Stop Clarification

You MAY recognize the clarification is sufficient when:
- Core problem and solution approach are clear
- Key stakeholders and users are identified
- Success criteria are defined and measurable
- Major constraints and boundaries are documented
- Edge cases and failure modes have been discussed
- The user expresses confidence in the direction

You MUST still ask: "Do you feel we have enough clarity to proceed, or are there areas you'd like to explore further?"
