# workspace-workshop — External Integrations

Every system this product talks to. Agents check here before assuming an integration is
custom-built or a vendor-provided dependency.

## Configured MCP integrations

- **GitHub** — `https://github.com`

## Other integrations

_TODO: add entries for systems not wired through MCP (databases, queues, vendor APIs).
For each: purpose, protocol, owning team, runbook link._

## Integration boundary conventions

- **Inbound** vs **outbound** call sites stay in dedicated modules — never reach into
  third-party SDKs from business logic.
- **PII / PCI scope** is documented per integration and propagated to compliance.
