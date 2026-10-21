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

The implementation passes 30 Swift tests, `harness check`, and an iOS Simulator build. Native layout includes a segmented category/repository browser, scoped search, heat/star sorting, a separate favorites entry, and preserved list state. An installed iPhone simulator runtime loaded the live homepage with category counts and SVG icons. Full interactive navigation remains unverified. Xcode 27 provides the simulator GUI through Device Hub; the earlier missing-GUI diagnosis was incorrect.

Catalog icons use SVGView 1.0.6 (MIT) to render the backend Iconify SVGs. The icon service caches response data for the session and falls back to SF Symbols on missing or failed icons.

## GUI acceptance follow-up

- [x] Decode UTC timestamps without a timezone suffix from the live catalog.
- [ ] Restore reliable Device Hub input and run the marketplace GUI flows.

The Xcode 27 simulator GUI is Device Hub, not Simulator.app. The initial GUI absence conclusion was incorrect. Live GUI testing found a catalog decoding error: `updated_at` can omit the UTC suffix. Backend timestamps use UTC. Match both timestamp forms at the JSON boundary and retain rejection of invalid input.

Timestamp regression first failed at `skills[0].updated_at`, then passed after the decoder change. All 32 Swift tests (including timezone offset and malformed input cases), `harness check`, and the iOS Simulator build pass. The repaired app was installed on the running iPhone 17. Device Hub screenshots confirmed the original error, but subsequent Computer Use operations timed out even for Finder. GUI acceptance remains blocked on the control service; no successful click recovery is claimed.

## Detail navigation regression

The user reported an extra navigation level when opening a skill. Static inspection shows one detail destination but mixes Boolean result presentation with value-based detail navigation. This is a hypothesis, not a confirmed cause. A new UI test checks two consecutive detail entries: one back action must return to the original list, and the next back action must return to the catalog. The test uses the live catalog and keeps screenshots at each step. Accessibility identifiers do not change routing behavior.

Computer Use recovered discovery after opening the internal DeviceHub executable through Finder, but later input again failed with `noWindowsAvailable` and the native pipe failed to start. The UI test bundle passes `xcodebuild build-for-testing` and `harness check`; running XCUITest awaits explicit user authorization to use an alternative UI control technology under the Computer Use tool rules. No navigation fix has been applied yet.

The first Xcode test build found a pre-existing product-name collision: `YouSkillTests` inherited `PRODUCT_NAME: YouSkill`. The test target now has its own product name. UI test lifecycle methods use async XCTest overrides for Swift 6 isolation.

## Video-confirmed navigation fix

The user-provided recording (2026-10-21 17:40:08, 2.398 seconds) shows the detail title briefly behind a second skill-list push at about 1.6 seconds. The list is pushed again above the detail; this is not merely the expected catalog/list/detail hierarchy. Replace the Boolean list destination with a value destination in one bound `NavigationPath`, shared with the existing skill destinations. The root toolbar now derives visibility from the same path. UI execution through XCUITest is still pending authorization; compilation and shared tests do not establish GUI acceptance.

Validation after the path change: all 32 shared Swift tests, `harness check`, `git diff --check`, and the iPhone 17 `build-for-testing` pass. The UI test bundle has not been executed, so the video establishes the original failure but not runtime acceptance of the fix.

## Release 1.1 preparation

The user requested a PR merge and a new iOS release. Version 1.1 uses build
20261021. On 2026-10-21, all 32 Swift tests and `harness check` pass. A signed
Release archive succeeds with the existing Xcode development identity. The
release archive must be rebuilt after the version bump. App Store Connect has
no active browser session yet. Distribution upload and App Review submission
remain pending. The existing XCUITest is compiled but has not run; authorization
to use it instead of Computer Use is pending.
