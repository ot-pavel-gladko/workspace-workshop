# workspace-workshop — Tech Architecture

Runtime topology, data flow, deployment shape. Source-of-truth for cross-repo questions.

## Runtime topology

_TODO_

_TODO: diagram (ASCII or link to Miro/Confluence) showing services, queues, datastores,
and how requests flow between them._

## Repos

_TODO: one entry per repo in `repos.txt` — language, role, primary owners. The
generated `.claude/agents/*.md` files give agents per-repo context; this is the
human-readable overview._

## Deployment shape

- **Environments**: dev, staging, prod (TODO — confirm)
- **CI/CD**: TODO
- **Infra**: TODO (cloud provider, IaC tool)

## Cross-cutting

- **Observability** — TODO (logs, metrics, traces, dashboards)
- **Secrets** — TODO (vault, rotation policy)
- **Migrations** — TODO (schema-change ordering, blue/green)
