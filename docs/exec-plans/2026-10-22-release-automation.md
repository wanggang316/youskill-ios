# ExecPlan: Verified iOS releases

**Status:** Active
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
- App Store Connect API access to YouSkill was verified with a read-only request. Credentials are in ignored local configuration; the private key remains outside the repository.
- Xcode 27.1 and the iOS 27.1 runtime are installed. Disk cleanup increased available space to 25 GiB. The app and test targets compiled with the new SDK, but two Duo devices reported a terminal `Data Migration Failed` status after restart. `simctl bootstatus` returned zero despite this failure. The lane now rejects that result and supports exact device selection through `IOS_SIMULATOR_UDIDS`; regression checks cover both behaviors and invalid selection input.
- Signature verification returned `-67054` for both iOS 27.1 and the existing iOS 27.0 runtime. This does not isolate the failure to the new runtime. The ordinary iPhone 16e booted successfully but remained in app installation while host load exceeded 600. Attempts were stopped without erasing devices, and logs were preserved. A separate active Duo prevented a global simulator-service restart without coordination.

## Decision Log

- Use the existing repository and XCUITest target rather than a parallel test system. sim-use supplements interactive diagnosis; it does not replace assertions.
- Test at the user interaction boundary and existing repository/service public interfaces. Preserve the navigation regression and add one behavior at a time.
- Treat a passing build, passing simulator tests, screenshots, upload, review submission, and public availability as separate evidence.
- Do not label another simulator or a resized screenshot as iPhone Duo evidence.

## Current Release Attempt

- The user authorized updating version 1.1 metadata and screenshots, uploading a new build, and submitting it for automatic release after approval.
- App Store Connect reports 1.1 as `PREPARE_FOR_SUBMISSION`, with no selected build. The newest uploaded build is 20261021. The new candidate is 202610221.
- The previously blocked Duo simulator now boots. The catalog split-view regression passed on device `09D50758-369E-4ED0-BC56-C45A956B51B6`.
- Store capture must use the open display in landscape and handle the split-view sidebar when returning to Settings.
- An executed screenshot smoke test passed its UI assertions but produced black images through `XCUIApplication.screenshot()`. Screenshot capture is not accepted until native image content and dimensions are verified.
- Four-language descriptions and release notes now describe the catalog and Duo layouts. The support URL is preserved. The privacy URL now points to `/apps/privacy.html`; the former `/privacy.html` returned the site shell rather than the policy. The previous dark-mode claim is removed because the app currently uses a light interface.
- Native active-display capture passed a five-page Duo smoke flow with exact 2853 x 2007 images. The capture worker has checks for success, command failure, and invalid filenames. PNG export uses an opaque ImageIO context to satisfy the App Store format requirement.
- Existing uploaded builds declare no non-exempt encryption. This release retains that declaration in the app plist; it does not change networking or cryptography.
- Full matrix acceptance, final screenshot inspection, signed archive, upload, and review submission are pending for this candidate.
- The first candidate matrix passed iPhone 16e, then failed on iPhone 17 because the model-settings tap occurred during sheet presentation. The failure hierarchy remained on the settings home screen. The test now waits for the entry to be interactive and the destination to appear. The complete file, configuration, validation, and translation flow passed in a focused iPhone 17 rerun.
- The next matrix passed the complete iPhone 16e, iPhone 17, and iPhone 18 Pro Max suites. Duo passed navigation, catalog retry, and file/translation settings. Its cover display did not rotate through XCTest, and search appeared as a button rather than an expanded field. The updated search/sort/favorite flow passed on Duo. Rotation coverage now uses explicit sim-use acceptance on both displays; this replacement still needs a complete run.
- The display-only rerun encountered a blank application window with an idle main thread. Diagnostics were retained. A device-only restart then reported `Data Migration Failed` while host load exceeded 250. The failed device was shut down. No final matrix acceptance, store screenshots, signed archive, or submission is established by these partial results.
- After the user reopened Duo, the complete host regression passed, including explicit cover and inner rotation checks. Evidence is in `build/test-results/duo-resumed-20261022`. The workflow can retain this recovered device through `IOS_KEEP_BOOTED_UDIDS`; checks cover both retention and the default shutdown behavior. A new full release run will bind all evidence and artifacts to the final source revision.
- The next Duo logic and four-flow UI suite passed. The following host check reproduced a blank foreground window after XCTest. Both Debug and Release had a valid SwiftUI scene and root controller but no rendered content. Restarting only SpringBoard and the accessibility bridge restored normal Release live-data rendering without a device reboot. The host setup now performs this bounded recovery. The complete host regression then passed in `build/test-results/duo-handoff-recovery-final`.

## Outcomes & Retrospective

The implementation is ready for review, with complete ordinary iPhone 17 regression evidence from Xcode 27.0 and partial iPhone 16e evidence. Xcode 27.1, its Duo runtime, and release credentials are now configured. Resolve the simulator startup and installation failures, then run the full matrix before store capture. No new store screenshots or release upload have been produced by this workflow. See [the release workflow](../references/ios-release.md) for commands and evidence boundaries.

## References

- https://www.apple.com/iphone-duo/
- https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes
- https://developer.apple.com/design/human-interface-guidelines/layout
- https://github.com/lycorp-jp/sim-use
- https://docs.fastlane.tools/actions/upload_to_app_store/

## Release resumption on 2026-10-22

The prepared 1.1 build 202610221 is bound to `1de97641391f643f1da11811ca7fa5893e3005c1`. Its 101 artifact hashes match after transfer. The clean acceptance record in `build/test-results/20261022T111233Z/acceptance.json` covers iPhone 16e, iPhone 17, iPhone 18 Pro Max, and Duo. All four locale contact sheets were inspected, including Duo open landscape. The images contain live content and are opaque RGB.

Use the exec-plan skill for this continuation. The remaining milestones are to validate restricted candidate reuse, inspect App Store Connect, and submit the existing archive and assets through the release lane. No new app behavior is needed. The later navigation test change affects test setup only; app and archive inputs are identical. The new reuse option requires original clean acceptance and unchanged production inputs. It preserves the manifest revision and writes a separate submission-source record. The default lane still rejects a changed HEAD without explicit opt-in.

- [x] Verify transferred candidate hashes, acceptance, and screenshot content.
- [x] Add and test rejection of changed production inputs, dirty source, incomplete acceptance, version mismatch, altered artifacts, and unbound screenshots.
- [x] Upload the candidate, verify metadata and image processing, and request review with automatic release.

Decision: preserve the verified archive and capture rather than repeat the device matrix. The explicit allowlist accepts only non-artifact paths and the tested release gate files. The original tests remain the evidence for this candidate; later test changes are not represented as executed acceptance.

Revision note: added the resumption contract because the merge and skill changes advanced HEAD beyond the original artifact revision. Remote upload and review remain unverified until the final readback.

The first submission attempt exposed conflicting Fastlane options (`ipa` and `build_number`); no upload occurred. The lane now validates identity from the IPA and lets Deliver select that exact processed build. The next attempt updated all four locales, then failed on a concurrent TLS read before image or binary upload. A single-thread retry successfully uploaded images. The user then requested only 3–5 key images. That uploader was stopped before IPA upload. The release now selects five images per locale (20 total) from the original hashed capture set. The original 100 captures and manifest remain unchanged. Sync must retain matching selected remote images, remove the redundant images, and upload only missing selections. Selection rejection tests and `harness check` pass.

## Confirmed submission outcome — 2026-10-22

App Store Connect readback confirmed version **1.1**, build **202610221**, build processing **VALID**, version state **WAITING_FOR_REVIEW**, and release type **AFTER_APPROVAL**. This is a review submission, not public availability. The original archive source remains `1de97641391f643f1da11811ca7fa5893e3005c1`; the final release-tool revision used for submission was `eeb93e4`. The manifest was not rewritten.

Each of en-US, zh-Hans, ja, and ko has exactly five images: four ordinary iPhone core screens and one Duo expanded catalog. All 20 images report COMPLETE and their remote source checksums match the selected local captures. Descriptions, keywords, release notes, support URLs, and marketing URLs match local metadata. Privacy URLs, names, and subtitles were read back. Copyright keeps the existing owner and now reads `2026 WangGang`; precheck passes without warnings. The review contact and encryption/content-rights declarations were preserved.

Evidence is in ignored local files `build/release/status/remote-verification.json`, `submit.log`, `upload-binary.log`, and `final-readback.log`. Original captures, acceptance, and the IPA remain intact. The first wide screenshot upload was stopped at the user's request; the final remote set is the reduced selection, not the original 100 images. Image processing and IPA upload were resumed separately through the installed Deliver/Spaceship dependencies to avoid duplicate upload. No Git push, tag, or deployment was performed.

Validation completed: release candidate rejection checks, screenshot selection checks, release preflight and simulator-retention checks, Fastlane option validation, `harness check`, and `git diff --check`. No device acceptance was rerun; the full original candidate acceptance was reused under the tested non-artifact change contract. This documentation update occurs after confirmed submission and changes HEAD without changing the submitted artifact provenance.

Revision note: recorded final remote evidence and the user's reduced screenshot scope. Apple's review is the only remaining external step; approval triggers automatic release.

## Screenshot parity correction

The user clarified that the 3–5 screenshot limit applies to each language and device group, with consistent content across groups. Replace the asymmetric 4-phone/1-Duo selection with four matching screens per group: categories, popular repositories, skills, and reader. All four locales use the same sequence. This gives 32 images total. The existing archive and metadata remain valid. The release gate now rejects a missing group, fewer than three or more than five images per group, and inconsistent screen order. Candidate and selection tests, `harness check`, and `git diff --check` pass.

Withdraw the pending review, retain existing matching images, upload the 12 missing Duo screenshots, and resubmit the same build. Confirm all eight locale/device groups contain the same four screens with COMPLETE state and matching source checksums before submission. Record the final review state after resubmission. The previous WAITING_FOR_REVIEW evidence describes the superseded asymmetric screenshot submission.

### Parity correction confirmed

On 2026-10-22 at 14:24:55 UTC, the same 1.1 build 202610221 was submitted again. Final API readback confirms WAITING_FOR_REVIEW, VALID build processing, and AFTER_APPROVAL release. The previous submission was canceled and its item became REMOVED before screenshot edits.

For each of en-US, zh-Hans, ja, and ko, APP_IPHONE_67 and APP_IPHONE_DUO each contain four images in the order categories, popular repositories, skill list, reader. All 32 images are COMPLETE and their source checksums match local captures. Exact ordered filenames were asserted against `fastlane/screenshot-selection.json` for all eight groups; no other populated groups remain. Existing metadata still matches local files. Only the 12 missing Duo images were uploaded; the existing 20 images and IPA were retained.

Evidence: `build/release/status/complete-device-groups.log`, `resubmit.log`, `parity-final-readback.log`, and `remote-verification.json`. Candidate/selection tests and harness checks passed. This outcome supersedes the earlier 20-image submission. Apple review remains pending, with automatic release after approval.

## Public release tag and workflow follow-up

The user requested a release tag after successful publication. A fresh App Store Connect read still reports 1.1 build 202610221 as WAITING_FOR_REVIEW with AFTER_APPROVAL release. No tag was created from submission alone.

- [ ] Verify public availability of 1.1 in an intended storefront and confirm selected build 202610221 in App Store Connect.
- [ ] Create annotated tag `1.1.0`, following the existing `1.0.0` convention, at the IPA source revision `1de97641391f643f1da11811ca7fa5893e3005c1`. Check local and remote tag conflicts first. Include version/build and public-release evidence in the annotation. Do not tag a later documentation commit. Tag push and GitHub Release publication are not authorized by this request.

This is a recorded follow-up, not an active background monitor. The release skill now carries the public-release/tag boundary and pending-item requirements.

The release retrospective identified these reusable lessons: capture evidence and store selection are different sets; 3–5 screens means per locale and device group with matching content and order; later non-artifact commits need the tested candidate-reuse gate; IPA and build-number upload options conflict; concurrent TLS failures require remote readback and a targeted serial retry; pending image processing must not trigger replacement; withdrawal requires waiting for editability; and upload, review, public release, and tagging need separate evidence. These rules are maintained in `.agents/skills/release/SKILL.md`, with implementation details in the existing release reference and helpers.
