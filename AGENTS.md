# youskill-ios

## Quick Start

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
# requires iOS platform/runtime installed in Xcode
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project YouSkill.xcodeproj -scheme YouSkill -destination 'generic/platform=iOS Simulator' build
```

## Architecture Overview

<!-- Describe high-level system architecture in 3-5 sentences -->
<!-- See docs/architecture.md for detailed layer definitions and dependency rules -->

This project follows a layered domain architecture. See [Architecture](docs/architecture.md) for the full domain model, layer structure, and dependency rules.

## Repository Structure

```
youskill-ios/
├── Sources/               # Swift source organized by architecture layers
├── Tests/                 # Shared logic and repository tests
├── Assets.xcassets/       # App colors and icons
├── project.yml            # XcodeGen project manifest
├── YouSkill.xcodeproj/    # Generated Xcode project
├── docs/                  # System of record for all project knowledge
│   ├── architecture.md    # Domain model, layers, dependency rules
│   ├── golden-rules.md    # Numbered principles (enforced by harness check)
│   ├── design-docs/       # Design documentation for features and systems
│   ├── exec-plans/        # Versioned execution plans with progress tracking
│   ├── product-specs/     # Product specifications and requirements
│   ├── references/        # External references and integration notes
│   └── generated/         # Auto-generated artifacts (do not edit)
├── .opencode/agents/      # OpenCode subagents (reviewer, planner, sweep)
├── .claude/agents/        # Claude Code subagents (mirrors .opencode/agents/)
└── .harness/rules/        # Custom lint rules (YAML)
```

## Golden Rules

1. **AGENTS.md is a map, not a manual** — keep this file under 150 lines
2. **Validate boundaries** — parse and validate data at system edges, never probe
3. **Prefer shared utilities** — centralize invariants, avoid hand-rolled duplicates
4. **Every decision gets logged** — use ExecPlans (exec-plan skill) for complex work
5. **Fix the environment, not the prompt** — when agents struggle, add missing tools/docs/guardrails

See [Golden Rules](docs/golden-rules.md) for the complete list with rationale and enforcement.

## Documentation

All project knowledge lives in `docs/`. Start with the area relevant to your task:

| Directory | Purpose |
|---|---|
| [docs/architecture.md](docs/architecture.md) | System architecture, domains, layers |
| [docs/golden-rules.md](docs/golden-rules.md) | Enforced principles and conventions |
| [docs/design-docs/](docs/design-docs/) | Design documentation for features |
| [docs/exec-plans/](docs/exec-plans/) | Execution plans for complex work |
| [docs/product-specs/](docs/product-specs/) | Product specifications |
| [docs/references/](docs/references/) | External docs, API references |
| [docs/generated/](docs/generated/) | Auto-generated artifacts |

## Working with This Repository

- Before making changes, read the relevant design doc in `docs/design-docs/`
- For complex work, create an ExecPlan using the exec-plan skill
- Run `harness check` before submitting PRs
- Follow the layer dependency rules in [docs/architecture.md](docs/architecture.md)
- When something fails, ask: "What capability is missing?" — then add it

## Build & Test Commands

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
# requires iOS platform/runtime installed in Xcode
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project YouSkill.xcodeproj -scheme YouSkill -destination 'generic/platform=iOS Simulator' build
```

## Code Style & Conventions

<!-- Link to your linter config, formatting rules, naming conventions -->
<!-- These should be mechanically enforced, not just documented -->

Run `harness check` to validate project structure and documentation.

## ExecPlans

When writing complex features or significant refactors, use an ExecPlan (exec-plan skill) from design to implementation.
