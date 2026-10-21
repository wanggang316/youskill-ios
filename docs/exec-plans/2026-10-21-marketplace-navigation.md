# ExecPlan: Marketplace navigation

**Status:** Completed
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
- [x] Confirm compact layout and implement native browsing.
- [x] Verify and commit the iOS changes.

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
- **Decision:** Use a native category/repository browser that pushes a scoped skill list on iPhone.
  **Rationale:** The user approved this compact layout. Keep the existing iPhone-only target; do not add iPad distribution support.
  **Date:** 2026-10-21

## Outcomes & Retrospective

The implementation passes 30 Swift tests, `harness check`, and an iOS Simulator build. Native layout includes a segmented category/repository browser, scoped search, heat/star sorting, a separate favorites entry, and preserved list state. An installed iPhone simulator runtime loaded the live homepage with category counts and SVG icons. Full interactive navigation has not been verified because this environment has no available Simulator GUI.

Catalog icons use SVGView 1.0.6 (MIT) to render the backend Iconify SVGs. The icon service caches response data for the session and falls back to SF Symbols on missing or failed icons.
