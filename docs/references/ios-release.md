# iOS test and release workflow

`project.yml` is the source of truth for the app version, build number, orientations, and test targets. Commit the build number before release. Tests, screenshots, and the archive must use that commit.

## Setup

- Install the Ruby version in `.ruby-version`, Bundler, XcodeGen, and sim-use.
- Install Xcode 27.1 or later and the runtime that includes iPhone Duo. Select that Xcode with `DEVELOPER_DIR` or `xcode-select`.
- Create iPhone 16e, iPhone 17, and iPhone Duo simulators in Xcode.
- Run `bundle install`. Keep the App Store Connect `.p8` key outside the repository.
- Sign in to the development team in Xcode and confirm automatic signing before release preparation. The current CI workflow runs tests; it does not configure distribution signing.

```bash
bundle exec fastlane ios prepare
bundle exec fastlane ios verify
```

`IOS_TEST_DEVICES` accepts a comma-separated list of exact simulator names. A reduced matrix is useful for local regression work but does not establish Duo support. `IOS_DERIVED_DATA` can reuse an existing build cache.

If several simulators have the same name, `IOS_SIMULATOR_UDIDS` can select an exact device with a JSON object, such as `{"iPhone Duo":"DEVICE-UDID"}`. An unknown UDID fails selection instead of falling back to another device. Run `bundle exec ruby scripts/test-release-preflight.rb` to check device selection and startup failure guards without booting a simulator. Run `ruby scripts/test-screenshot-capture.rb` to check the screenshot handshake and failure propagation.

The workflow activates one selected simulator at a time and shuts down other selected devices to reduce host memory and CPU load. It does not erase device data or shut down devices outside the selected matrix. Each device gets its own result bundle. Use a current runtime when creating test devices; legacy-runtime boot failures are environment failures, not passing app tests.

```bash
IOS_TEST_DEVICES='iPhone 17' bundle exec fastlane ios verify
```

## Acceptance boundary

The standard suite runs shared logic tests, a live catalog-to-reader navigation regression, and deterministic UI flows for search, sorting, favorite persistence, file types, translation settings, retry, and rotation. Fixture repositories are available only in Debug builds with `--ui-fixtures`. Store screenshots use live data.

When Duo is in the matrix, `scripts/verify-duo.rb` changes the active display with sim-use while a selected file remains open. It checks catalog/result column geometry, compact navigation, the selected scope, file, drawer, rotation, back navigation, and reader re-entry without restarting the app between display changes. A failed command or assertion blocks screenshots. This script requires validation on the supported runtime; syntax checks are not device acceptance.

The ordinary XCTest rotation case is excluded only on Duo because its orientation command did not rotate the active cover display. The Duo script replaces that case with explicit cover and inner display rotation checks and rejects a command that reports no rotation. Duo search can appear as a Search button; the UI test opens that control before entering a query.

Test results are stored in `build/test-results/<timestamp>/`. Keep the `.xcresult`, JUnit report, Duo accessibility snapshots, and `acceptance.json` together. CI runs ordinary iPhone regression tests; the current hosted runner configuration does not provide Duo acceptance.

## Screenshots and submission

```bash
bundle exec fastlane ios screenshots
```

The screenshot lane first runs acceptance. It captures five screens in English, Simplified Chinese, Japanese, and Korean, including separate Duo cover and inner display sets. Existing `fastlane/screenshots` must be moved aside before a fresh capture. Inspect the generated images for clipping, empty content, localization, and correct active-display dimensions before submission. A completed capture alone does not establish visual quality.

Capture uses the separate `YouSkillScreenshots` XCTest scheme through fastlane `run_tests`. The pinned snapshot launcher shuts down all booted simulators, so it cannot preserve a selected Duo posture. The native test target reads a temporary host configuration, sets the app language and posture, and signals when each page is ready. A host worker uses sim-use to capture the active display at its native resolution, then returns the PNG for the test result attachment. This avoids black images and rounded dimensions from XCTest screen capture on Duo. Open-display screenshots use landscape to show both catalog columns. The workflow removes that configuration after capture and validates both image counts and Duo display dimensions.

```bash
./scripts/bump-build.sh
# Review and commit the generated version change before release.
bundle exec fastlane ios prepare_release
# Inspect fastlane/screenshots before submission.
export ASC_KEY_ID='your-key-id'
export ASC_ISSUER_ID='your-issuer-id'
export ASC_KEY_PATH='/absolute/path/to/AuthKey.p8'
bundle exec fastlane ios release
```

The preparation lane requires a clean commit. It runs acceptance and screenshot capture, archives with automatic signing, and records SHA-256 hashes for the IPA and images. The release lane requires API credentials and checks that the commit and artifacts still match. It uploads those artifacts and requests review with automatic release after approval. Upload, review submission, approval, and public availability are separate states. Do not report a release as public from an upload result.

## Simulator failures

- Run simulator tools in an environment that can access CoreSimulator. A sandbox connection error does not prove that the service failed.
- Read the failing assertion, screenshot attachment, and accessibility hierarchy from the result bundle before changing app behavior. SwiftUI identifiers can appear on scroll views or text rather than `Other` elements.
- If a process stalls before app code, inspect its stack and the test runner. Do not erase all simulators or suppress a failed test. Stop only the task's runner and reboot only its selected device if needed.
- sim-use reports an explicit hint for a stale accessibility bridge. Restart that device's bridge only when no test runner is using it, then retry the query.
- fastlane prefixes child-process `PATH` with its active Ruby directory so formatters do not load the macOS system Ruby.
- Simulator boot waits and the host Duo check have a 10-minute limit. The timeout wrapper terminates its command group and returns exit code 124. A timeout fails the lane; it does not skip the device or mark acceptance complete.
- A `Data Migration Failed` boot result also fails the lane, even when `simctl` exits with status zero. Keep the failed device and logs for diagnosis; do not treat this state as a ready test destination.
- Each device's build and test process has a 20-minute total limit, including installation and test-host launch. Individual test execution has a separate 10-minute limit. This allows cold simulator input services to start; element and state assertion deadlines remain short.

## Sources

- [Apple: Prepare for iPhone Duo](https://developer.apple.com/iphone-duo/prepare/)
- [Apple: Xcode 27.1 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes)
- [sim-use](https://github.com/lycorp-jp/sim-use)
- [fastlane scan](https://docs.fastlane.tools/actions/run_tests/)
- [fastlane snapshot](https://docs.fastlane.tools/actions/capture_screenshots/)
- [fastlane deliver](https://docs.fastlane.tools/actions/upload_to_app_store/)
