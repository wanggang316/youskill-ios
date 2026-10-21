# ExecPlan: Verified iOS releases

**Status:** Blocked on simulator acceptance and release credentials
**Created:** 2026-10-22
**Last Updated:** 2026-10-22

## Purpose / Big Picture

Make build, simulator acceptance, store screenshots, and App Store submission a repeatable fastlane workflow. Adapt the app to iPhone Duo and verify display transitions before claiming device support.

## Context and Orientation

Version 1.1 build 20261021 was uploaded before this work. `project.yml` generates the Xcode project. Shared tests cover repositories and list state. `UITests/MarketplaceNavigationTests.swift` contains one live navigation regression that was compiled but never executed. The app currently supports portrait only. `SkillListView` owns navigation state, and `SkillDetailView` owns reading state.

## Plan of Work

Run the existing simulator tests first and diagnose failures from result bundles. Add stable user-flow coverage for catalog browsing, search, sorting, favorites, reading, files, settings, and resizing. Use XCUITest for repeatable assertions and sim-use for interactive inspection. Add fastlane lanes with explicit device selection, failure propagation, test artifacts, screenshot gating, signing, and API-key submission. Keep release secrets outside Git. Generate and inspect store screenshots only after the acceptance suite passes. Build and upload a new build number after code changes.

## Progress

- [x] Inspect project conventions and previous failed acceptance attempts.
- [x] Verify iPhone Duo and Xcode 27.1 support in Apple documentation.
- [x] Execute baseline simulator tests and fix the observed failures.
- [x] Add adaptive layout and regression coverage.
- [ ] Configure and validate fastlane and CI.
- [ ] Pass the simulator acceptance matrix and inspect screenshots.
- [ ] Upload the verified build and screenshots, then submit for review.

## Surprises & Discoveries

- Sandboxed simctl fails with CoreSimulator connection errors. The same command outside the sandbox lists installed runtimes successfully; this does not establish a simulator service crash.
- The previous UI acceptance failure was in the computer-control service. XCUITest was compiled but not executed. The user now explicitly authorizes simulator automation frameworks.
- Installed Xcode is 27.0 (27A266a). Installed device types do not include iPhone Duo. Apple documents Duo simulator support in Xcode 27.1. The host runs macOS 26.6.2, which meets its minimum requirement. Free disk space was about 15 GiB before tool installation.
- The exec-plan skill is absent. This plan follows the repository's existing template.
- The baseline navigation test queried an `Other` element, but the observed SwiftUI hierarchy exposed a scroll view. The corrected live navigation test passed, including a second entry and return.
- A portrait-only declaration prevented the rotation regression from passing. The same test passed after enabling all orientations.
- The first fastlane execution used system Ruby for xcpretty despite starting Bundler with Homebrew Ruby. Prefixing the active Ruby directory fixes that environment mismatch.
- The final iPhone 17 fastlane run passed all 32 logic tests and five UI tests, including files, translation settings, favorites, rotation, and the live navigation regression. The result bundle is `build/test-results/20261021T174258Z/CE86A573-E6BB-4BA8-A9E0-B8BFADA14C51/YouSkill.xcresult`. This evidence covers the local build 20261022 source before commit; it does not cover Duo.
- Ruby syntax, lane discovery, and `harness check` pass. These checks do not establish screenshot capture, signing, upload, or Duo runtime support.
- The file workflow initially queried an identifier that SwiftUI replaced with its parent identifier. The failure hierarchy showed `example.swift` and the rendered code. Querying the visible filename fixed the test; the complete file and translation-settings flow then passed.
- The production Release configuration builds with signing disabled. Its binary excludes the Debug fixture markers. Build 20261022 is the final local test candidate.
- The first iPhone 16e boot stalled in the MobileGestalt migration plugin's synchronous IPC call. Diagnostics were preserved before a device-only restart. Boot and Duo host checks now have bounded execution; success, failure propagation, and timeout exit 124 were verified.
- Host load average exceeded 600 while multiple simulators were active. The workflow now activates and tests one selected simulator at a time. The legacy iOS 26 iPhone 16e was retained; a new iPhone 16e on iOS 27 completed initialization after the idle test simulator was shut down. This supports resource contention as a contributing factor, but does not establish the sole cause of the legacy migration stall.
- One file-flow run completed every assertion at 299 seconds but reached the five-minute limit during teardown. App sampling showed an idle main thread while XCTest waited for an idle notification. Test execution now allows 10 minutes, with unchanged element assertions and a 20-minute limit for each device's complete build/test process. The next iPhone 17 run passed all 32 logic tests and five UI flows; the file flow completed in 54 seconds.
- Inspection of fastlane 2.241.1 found that the snapshot launcher unconditionally shuts down booted simulators. Store capture now uses a native XCTest PNG writer through `run_tests` so that the selected Duo posture is retained. This capture path remains gated by full device acceptance.
- The iPhone 16e run passed 32 logic tests, live navigation, and catalog/retry coverage, then hit the overall timeout during the file/settings flow after tapping a text field. XCTest reported a missing app-idle notification. A sample showed the app main thread waiting in the event loop; concurrent unrelated builds were also active. The incomplete result is retained beside the iPhone 17 result, and no `acceptance.json` was issued for the matrix. Further acceptance needs a responsive simulator host; no tests were skipped or marked passed from this timeout.
- The final native screenshot target passed `build-for-testing` without running screenshot capture. Final fastlane lane discovery, Ruby syntax checks, `harness check`, and `git diff --check` passed. CI is configured but has not run remotely. Native capture, Duo display changes, signed archive export, and submission remain unverified.

## Decision Log

- Use the existing repository and XCUITest target rather than a parallel test system. sim-use supplements interactive diagnosis; it does not replace assertions.
- Test at the user interaction boundary and existing repository/service public interfaces. Preserve the navigation regression and add one behavior at a time.
- Treat a passing build, passing simulator tests, screenshots, upload, review submission, and public availability as separate evidence.
- Do not label another simulator or a resized screenshot as iPhone Duo evidence.

## Outcomes & Retrospective

The implementation is ready for review, with complete ordinary iPhone 17 regression evidence and partial iPhone 16e evidence. Finish the small-device suite on a responsive host, install Xcode 27.1 with Duo support, and run the full matrix before store capture. Configure App Store Connect API credentials before submission. No new store screenshots or release upload have been produced by this workflow. See [the release workflow](../references/ios-release.md) for commands and evidence boundaries.

## References

- https://www.apple.com/iphone-duo/
- https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes
- https://developer.apple.com/design/human-interface-guidelines/layout
- https://github.com/lycorp-jp/sim-use
- https://docs.fastlane.tools/actions/upload_to_app_store/
