# Agentic Enhancement: Context Refresh Protocol

## Overview

In long-running SDLC sessions (hours), the agent's active memory of initial agreements, constraints, and methodology fades as context grows. This protocol ensures the agent re-grounds itself at every phase transition.

## When to Apply

You MUST execute a context refresh:
- At the START of every numbered step (Steps 1-9)
- When resuming after a user break or session restart
- When context window usage exceeds ~50%
- After any subagent delegation (to re-sync with main thread)

## Context Refresh Steps

### 1. Re-read Skill Knowledge

```
Load and review the current step's SOP file from references/
Identify the MUST constraints for this step
```

### 2. Re-read Methodology (if exists)

```
Check for {project_name}/methodology.md or equivalent
Load accumulated gotchas and patterns
These are REQUIREMENTS for the current step
```

### 3. Re-read the Plan

```
Check for {project_name}/implementation/plan.md
Identify: which step are we on? What's complete? What's next?
```

### 4. Self-Reflect and Summarize

Present to user (briefly):
```
"Context refresh: We are in Step {N} ({step_name}).
 Methodology has {X} gotchas to follow.
 Plan: {Y} steps total, {Z} complete.
 Key constraints for this step: {top 3 from SOP}"
```

## Constraints

- You MUST NOT skip context refresh because in long sessions, initial agreements get pushed out of active memory and the agent starts making decisions that contradict earlier agreements
- You SHOULD keep the refresh summary brief (3-5 lines) to avoid wasting context on meta-discussion
- You MUST re-read methodology constraints before any implementation step because methodology is the accumulated institutional knowledge from previous iterations
- You MUST re-read the plan before any implementation step because the plan tracks what's done and what's next
- If methodology or plan files don't exist yet (early in the process), You SHOULD note this and proceed
