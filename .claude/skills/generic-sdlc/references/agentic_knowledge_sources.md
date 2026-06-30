# Agentic Enhancement: Knowledge Source Discovery

## Overview

Before any research execution, systematically discover ALL available knowledge sources. This checklist ensures no valuable information source is overlooked. Present findings to the user and collaboratively decide which sources to use.

## Knowledge Source Checklist

You MUST check each category and present findings to the user.

### A. Human Knowledge (Off-Grid / User-Uploaded)

| Source | How to Check | Status |
|--------|-------------|--------|
| Email threads | Ask user: "Do you have relevant email threads to share?" | ☐ |
| Team messages (Slack/Teams) | Ask user: "Any relevant team chat threads?" | ☐ |
| Meeting transcripts | Ask user: "Any meeting notes or transcripts?" | ☐ |
| Confluence pages | `confluence_search` for project/feature keywords | ☐ |
| Presentations/documents | Ask user: "Any slide decks or documents?" | ☐ |
| Images/diagrams | Ask user: "Any architecture diagrams, whiteboard photos, Figma screenshots?" | ☐ |
| Stakeholder conversations | Ask user: "Any verbal decisions not captured in writing?" | ☐ |

### B. External Knowledge (Don't Reinvent)

| Source | How to Check | Status |
|--------|-------------|--------|
| Open source solutions | `web_search` for similar implementations | ☐ |
| Technical publications | `web_search` for best practices in the domain | ☐ |
| Library/framework docs | `web_search`/`web_fetch` for relevant API docs | ☐ |
| Community solutions | `web_search` for Stack Overflow, GitHub issues | ☐ |
| Vendor documentation | `web_fetch` for integration specs | ☐ |

### C. Internal Workspace Resources

| Source | How to Check | Status |
|--------|-------------|--------|
| Available subagents | `use_subagent ListAgents` | ☐ |
| KNOW.md files (code intelligence) | `glob **/KNOW.md` in workspace | ☐ |
| Previous methodology docs | `glob **/methodology.md` | ☐ |
| Previous learnings | `glob **/learnings*.md` | ☐ |
| Workspace steering docs | Check `.kiro/steering/` | ☐ |

### D. Agentic Catalog

| Source | How to Check | Status |
|--------|-------------|--------|
| Available skills | `aila_list_skills()` if SDK available | ☐ |
| Skill resources | `aila_get_skill(name)` for relevant skills | ☐ |
| Agent catalog | Check for agent configs | ☐ |

### E. Project Infrastructure

| Source | How to Check | Status |
|--------|-------------|--------|
| Jira stories/ACs | `jira_search` or `jira_get_issue` | ☐ |
| Jira comments (stakeholder decisions) | `jira_get_issue` with comment_limit | ☐ |
| Figma/design assets | Check Jira attachments, Figma URLs in descriptions | ☐ |
| Confluence docs | `confluence_search` for project docs | ☐ |
| QA tools (e.g., test management systems) | Check for existing test cases | ☐ |
| Git history | `git log` for recent changes in relevant area | ☐ |
| Database schemas | `glob **/*.prisma` or `glob **/schema.*` | ☐ |
| Template/contract files | `glob **/*.template.*` or `glob **/*.hbs` | ☐ |
| CI/CD configs | Check pipeline configs for constraints | ☐ |

## Self-Discovery Protocol

You SHOULD proactively run these checks before asking the user:

```
1. use_subagent ListAgents              → Available domain experts
2. glob **/KNOW.md                      → Code intelligence coverage
3. glob **/methodology.md               → Accumulated learnings
4. glob **/learnings*.md                → Previous implementation findings
5. jira_get_all_projects (if available) → Jira access
6. confluence_search (if available)     → Confluence access
7. glob **/*.prisma                     → Database schemas
8. glob **/*.template.*                 → Template contracts
```

Present findings: "I discovered {N} subagents, {M} KNOW.md files, Jira access to {projects}, Confluence access, {K} schema files, {L} templates. Here's what I recommend we use for research..."

## Constraints

- You MUST present the checklist to the user during research planning
- You MUST NOT skip the self-discovery protocol because it reveals sources the user may not know about
- You MUST document which sources were used and which were skipped (with reason) in the research plan
- You SHOULD suggest sources the user may not have considered
- You MUST save discovered sources to `{project_name}/research/knowledge-sources.md`
