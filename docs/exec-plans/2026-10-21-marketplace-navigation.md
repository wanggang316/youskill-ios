# ExecPlan: Marketplace navigation

**Status:** Active
**Created:** 2026-10-21
**Last Updated:** 2026-10-21

## Purpose / Big Picture

Bring category and hot repository browsing to iOS. Keep scoped search, star counts, sorting, favorites, and return state consistent with the desktop catalog.

## Context and Orientation

`Sources/UI/Features/Home/SkillListView.swift` owns the current flat feed. `SkillListViewModel.swift` handles search and pagination. `SkillCatalogRepository.swift` uses the authenticated catalog route. Public summary and repository endpoints are deployed. The application currently targets iPhone only.

## Plan of Work

Add typed catalog navigation models and public repository methods through the existing service layer. Extend queries with an exclusive category or repository scope. Protect list state against stale responses and preserve pagination on retry. Adapt native navigation after layout confirmation. Keep local favorites available. Verify repository requests, state transitions, Swift tests, simulator builds, and visible navigation.

## Progress

- [x] Publish desktop PR #44.
- [x] Inspect iOS architecture, repository contracts, and existing tests.
- [x] Add catalog navigation requests and scoped queries with tests.
- [ ] Confirm compact layout and implement native browsing.
- [ ] Verify and commit the iOS changes.

## Surprises & Discoveries

- `harness plan` is not available in the installed CLI; use this repository's ExecPlan template.
- The referenced exec-plan skill is not installed in the local skill directories.
- The current app targets iPhone only; iPad support must not be enabled silently.
- The original list model did not reject stale requests after scope or sort changes; request identity now protects reload and pagination.
- The initial Swift test run hit an existing macOS compile error in `SettingsView.swift` (`Color(.tertiaryLabel)`). Use SwiftUI `.tertiary` so the shared test target compiles.

## Decision Log

- **Decision:** Use public catalog endpoints and existing URLSession infrastructure.
  **Rationale:** The deployed endpoints support category filters, repository filters, icons, and stars without a new dependency.
  **Date:** 2026-10-21
- **Decision:** Keep UI layout pending user confirmation; API and state work can proceed independently.
  **Rationale:** An always-visible phone sidebar and a native browse-then-list flow have different usability tradeoffs.
  **Date:** 2026-10-21

## Outcomes & Retrospective

The data layer and state changes pass 27 Swift tests and `harness check`. Native layout implementation remains pending user confirmation. The iOS Simulator build passes. UI runtime acceptance remains pending.
