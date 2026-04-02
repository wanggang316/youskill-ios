# Documentation

This directory is the **system of record** for all project knowledge. If it's not here, it doesn't exist to the agent.

## Structure

| Directory | Purpose | Maintained by |
|---|---|---|
| [architecture.md](architecture.md) | System architecture, domains, layers | Engineers |
| [golden-rules.md](golden-rules.md) | Enforced principles and conventions | Engineers |
| [quality-scorecard.md](quality-scorecard.md) | Quality grades per area | `harness score` |
| [design-docs/](design-docs/) | Feature and system design documentation | Engineers |
| [exec-plans/](exec-plans/) | Versioned execution plans with progress | Engineers + agents |
| [product-specs/](product-specs/) | Product specifications and requirements | Product team |
| [references/](references/) | External references, API docs, integration notes | Engineers |
| [generated/](generated/) | Auto-generated artifacts — do not edit manually | Automation |

## Conventions

- Every document should be self-contained enough for an agent to act on it
- Use relative links between documents
- Keep documents focused: one concept per file
- Mark documents as deprecated rather than deleting them
- Run `harness check` to validate structure and freshness
