# ExecPlan: Adaptive catalog navigation

**Status:** Completed
**Created:** 2026-10-22
**Last Updated:** 2026-10-22

## Purpose / Big Picture

Show the catalog and its Skills together when the window has room for two columns. Keep single-column navigation on compact displays.

## Context and Orientation

`Sources/UI/Features/Home/SkillListView.swift` owns catalog scope, search, sort, and result scroll state. It previously pushed results and readers onto one navigation stack. `scripts/verify-duo.rb` checks display transitions on a running Duo simulator.

## Plan of Work

Use a system navigation split view with the catalog in the sidebar and a reader navigation stack in the detail column. Keep state above both columns. Extend the Duo regression to check simultaneous catalog and result visibility and compact navigation.

## Progress

- [x] 2026-10-22: Inspect navigation, design guidance, and simulator acceptance workflow.
- [x] 2026-10-22: Implement adaptive columns and selected-scope highlighting.
- [x] 2026-10-22: Simulator build and two iPhone UI regressions passed.
- [x] 2026-10-22: Full Duo column, fold, file, drawer, rotation, and reader re-entry regression passed.
- [x] 2026-10-22: `harness check`, Ruby syntax, and `git diff --check` passed.

## Surprises & Discoveries

- Simulator access requires execution outside the filesystem sandbox.
- sim-use reports geometry in `frame.width` and `frame.height`; the prior script read obsolete fields.
- The reader accessibility identifier masks the drawer close identifier. The English fixture flow locates the visible Done button instead.
- Inner-display portrait can hide the sidebar when space is limited. The two-column geometry assertion explicitly uses landscape.

## Decision Log

- Use `NavigationSplitView` rather than device-specific width checks. The system owns column collapse, safe areas, and fold adaptation.
- Show all Skills before an explicit selection. Selecting a scope clears the reader stack and shows that scope's results.
- Preserve the existing view model and result scroll binding across display changes.

## Outcomes & Retrospective

The catalog and results share the wide window without rebuilding view state. Compact category/repository navigation, failed-load retry, rotation, fold transitions, selected-file retention, and reader re-entry passed on simulators. Evidence is in `build/test-results/adaptive-catalog/` and Xcode result bundle `Test-YouSkill-2026.10.22_17-17-08-+0800.xcresult`. Tests use fixture data; they do not establish real-device acceptance or long-list scroll retention.
