# Architecture

## System Overview

<!-- Describe the system in 2-3 sentences: what it does, who uses it, what the key interfaces are -->

## Domain Model

<!-- List each business domain with a brief description -->
<!-- Example:
- **Authentication** — User identity, sessions, tokens
- **Billing** — Subscriptions, payments, invoicing
- **Notifications** — Email, push, in-app messaging
-->

## Layer Structure

Each domain follows a fixed set of layers with strictly validated dependency directions:

```
Types → Config → Repo → Service → Runtime → UI
```

| Layer | Responsibility |
|---|---|
| **Types** | Shared type definitions and schemas |
| **Config** | Configuration loading and validation |
| **Repo** | Data access and persistence |
| **Service** | Business logic and orchestration |
| **Runtime** | Application lifecycle, scheduling, background work |
| **UI** | User interface and presentation |

## Dependency Rules

- Code may only depend **forward** through layers (Types → Config → ... → UI)
- Cross-cutting concerns (auth, telemetry, feature flags) enter through **Providers**
- No circular dependencies between domains
- Shared utilities live in a `utils/` package outside domain boundaries

## Key Abstractions

<!-- Document the core abstractions that agents need to understand -->
<!-- Example:
- **Repository pattern** — All data access goes through typed repo interfaces
- **Service layer** — All business logic lives in service classes, never in routes
-->

## Technology Choices

<!-- Document key technology decisions and rationale -->
<!-- Prefer "boring" technology that agents can reason about easily -->
