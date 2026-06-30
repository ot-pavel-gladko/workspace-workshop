# Implement a Feature with the Agentic Development Lifecycle (ADLC)

> 🚧 **UNDER CONSTRUCTION — preview only, not yet runnable.** This describes what the
> workshop *will* cover and the feature it will build; the hands-on steps are still
> being authored. Run the prerequisite `configure-workspace-kb-and-agents` workshop
> in the meantime.

*(Planned)* Hands-on workshop where you deliver one product feature end-to-end with a
team of agents, playing the **human at every decision gate** yourself. **Design-first:**

- **Session 1 — Design:** scaffold a unique epic + feature branch, generate a
  clickable wireframe (design agent), and approve it as **Product Owner** (unbounded
  reject loop).
- **Session 2 — Requirements:** the **BA** authors BE/FE/Wireframe stories from the
  approved design; you review them as **BA reviewer** and set Ready for Sprint.
- **Session 3 — Implementation:** the **lead** orchestrates the **code** agent to
  build the feature, push to the branch, and open a PR; you review it as **Tech-lead**.

Demonstrates multi-agent orchestration across agents with different tool scopes (the
lead bridges Jira ↔ GitHub), a persistent `.adlc/feature.json` manifest for
stop/resume, and per-run isolation (unique epic-key branch + `run-<id>` labels) so
many participants share one Jira/repo safely. Sample feature: **time tracking**.

Level 02 (advanced) · ~2.5–3h (resumable) · **Prerequisite:** the
`configure-workspace-kb-and-agents` workshop (a configured workspace with 7 agents incl.
the design agent and the lead's Jira access). Completing this workshop is the 15/15
pilot task.
