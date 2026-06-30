# Domain Glossary

Industry-neutral, project-agnostic terminology for **full-stack web application
delivery** (web APIs, authentication, relational persistence, containerized
deployment). Vendor-general — no client or project specifics.

For project-specific terms (client systems, internal product names, proprietary
concepts), see `../project-kb/GLOSSARY.md`.

---

## Authentication & security

| Term | Meaning |
|---|---|
| **JWT (JSON Web Token)** | A signed, base64url-encoded token of three parts (header.payload.signature) carrying claims (e.g. `sub`, `exp`, `nbf`). Stateless: the server validates the signature instead of a session store. |
| **Bearer token** | An access credential sent as `Authorization: Bearer <token>`; whoever holds it can use it, so it must travel only over TLS and have a short lifetime. |
| **OAuth2 Password / Bearer flow** | The grant where a client exchanges username+password for an access token, then presents that token as a bearer credential on later requests. |
| **Claim** | A key/value assertion inside a token, e.g. `sub` (subject/identity), `exp` (expiry), `nbf` (not-before), `iat` (issued-at). |
| **Password hashing** | One-way transform of a password for storage. Modern memory-hard algorithms (Argon2, scrypt) are preferred; bcrypt is an accepted older standard. Never store or log plaintext. |
| **Argon2** | A memory-hard password-hashing algorithm (Argon2id variant recommended) and winner of the Password Hashing Competition. |
| **Timing-attack resistance** | Comparing secrets in constant time (and hashing a dummy value when a user is absent) so response latency doesn't leak whether an account exists. |
| **User enumeration** | An information leak where differing responses reveal whether an email/username exists; mitigated by returning identical responses (e.g. on password-recovery). |

## Web / API

| Term | Meaning |
|---|---|
| **CORS** | Cross-Origin Resource Sharing — browser policy controlling which origins may call an API; the server declares allowed origins via response headers. |
| **OpenAPI** | A machine-readable specification of an HTTP API (paths, schemas, auth). Enables auto-generated docs and typed client SDKs. |
| **Reverse proxy** | A server that fronts one or more backends, handling TLS termination, routing, and load balancing (e.g. Traefik, Nginx). |
| **TLS termination** | Decrypting HTTPS at the edge (proxy) so internal services speak plain HTTP on a trusted network. |
| **Idempotency** | A property where repeating the same request yields the same result; important for retries (PUT/DELETE are idempotent, POST usually not). |

## Data & operations

| Term | Meaning |
|---|---|
| **ORM** | Object-Relational Mapper — maps database rows to typed objects (e.g. SQLAlchemy/SQLModel). |
| **Schema migration** | A versioned, ordered change to a database schema (e.g. via Alembic); applied with `upgrade head` and reversible with `downgrade`. |
| **Cascade delete** | A referential rule that deletes child rows when their parent is deleted. |
| **ACME** | Automatic Certificate Management Environment — the protocol (used by Let's Encrypt) for automated TLS certificate issuance/renewal via HTTP-01, DNS-01, or TLS-ALPN-01 challenges. |
| **Healthcheck** | A lightweight endpoint/command an orchestrator polls to decide if a service is ready/live. |
| **Superuser / admin role** | An elevated principal permitted to manage other accounts and global resources; contrasted with a regular user. |

---

## Acronyms quick reference

JWT · OAuth2 · CORS · TLS · ACME · ORM · SMTP · DSN · SPA · HMAC · PK/FK · UUID
