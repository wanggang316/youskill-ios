# Design Doc: TestFlight builds

**Status:** Implemented
**Author:** Gump
**Date:** 2026-11-02

## Problem Statement

The only distribution path is the App Store release in [ios-release.md](../references/ios-release.md). It runs the full simulator matrix, including iPhone Duo, and captures store screenshots. Then it submits for review. This takes too long to put a test build on a device after each change. Also, no lane uploads a build to TestFlight only.

## Goals

- One local command uploads the current commit to TestFlight for internal testers.
- A short test gate runs before the upload.
- The upload does not need a commit or a push to `main`.

## Non-Goals

- External TestFlight groups and Beta App Review.
- Running the upload in GitHub Actions. CI keeps running tests only and does not hold distribution signing.
- Changes to the App Store release lanes.

## Proposed Solution

Terms:

- **TestFlight build:** a build uploaded to TestFlight for testing only.
- **App Store release:** the existing `prepare_release` and `release` flow that requests App Store review.

Do not use "release" for a TestFlight build.

Decisions:

1. **Where it runs.** A fastlane lane, `ios beta`, runs on the local Mac. It uses the automatic signing that is already set up in Xcode, and the App Store Connect API key from `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_PATH`. These are the same variables that `ios release` uses.
2. **Gate.**
   - The lane requires a clean working tree.
   - It runs the logic tests and the UI tests on one simulator, iPhone 17.
   - Any failure stops the lane before the archive.
   - The lane does not require iPhone Duo and does not capture screenshots.
3. **Build number.**
   - The lane sets a date-based build number (`YYYYMMDD`, then `YYYYMMDDN` for later builds on the same day) at archive time.
   - The number must be greater than the latest build that App Store Connect has for the current marketing version.
   - The lane does not write the number to `project.yml` and does not commit it.
   - The marketing version comes from `project.yml`.
4. **Testers.** The lane distributes the build to the internal testing group only.
5. **What to Test.**
   - The notes list the commit subjects since the source revision of the previous TestFlight build.
   - They also give the source revision of this build.
   - The lane finds the previous revision from the notes of the previous build in App Store Connect, not from a git tag. So the lane does not push.
6. **No promotion to the App Store.** An App Store release always archives again through `prepare_release`, with the full matrix, screenshots and manifest. It never submits a TestFlight build. Thus the binary that testers used and the binary on the App Store are different, but the source revision in What to Test links them.
7. **Trigger.**
   - A person runs the lane when a test build is needed, or asks the agent to run it on the local Mac.
   - The lane does not run after each merge.
   - When an iOS ticket needs device acceptance, the agent can propose a TestFlight build. It uploads only after the person agrees.
8. **Processing.**
   - After the upload, the lane waits for App Store Connect processing, for at most 30 minutes. Then it adds the build to the internal group.
   - The lane reports three states as separate states: uploaded, processed, and available to testers.
   - If processing times out, the lane fails. It tells the person that the distribute step can run again without a second upload.
9. **Internal group.** The lane distributes to the internal group named `Internal`. If that group does not exist, the lane creates it before it distributes the build.

## Alternatives Considered

- **GitHub Actions upload on push or tag.** This needs distribution certificates in CI, through match or cloud signing with an API key. It adds a secret store and more failure modes. We do not need it for internal testing now.
- **Full release gate.** This would run the Duo matrix and screenshots. It is too slow and too fragile for test builds. The App Store release keeps this gate.
- **Committed build number.** This would bump `project.yml` and push to `main` for each TestFlight build. It adds noise commits and needs push access. App Store releases still commit their build number. A TestFlight build number is a date-based number. The release bump (`ios bump_build`) applies the same rule to the committed number and the latest App Store Connect build, and `prepare_release` stops when the committed number is not greater. Thus the release build number exceeds every TestFlight build of the version.

## Dependencies

- An App Store Connect API key with access to the app. One exists in local configuration.
- Automatic signing for team `HC438T2B8P` in Xcode on the machine that runs the lane.

## Risks

- **Not tested on iPhone Duo.** A TestFlight build is not evidence of Duo support. The App Store release gate stays the evidence.
- **Build not in source control.** The build number of a TestFlight build is not in source control. The source revision in What to Test is the link back to the source.
- **Local machine required.** The lane needs this machine, with Xcode signing set up. Reconsider a CI upload when external testers or other machines need TestFlight builds.

## References

- [iOS test and release workflow](../references/ios-release.md)
- [fastlane upload_to_testflight](https://docs.fastlane.tools/actions/upload_to_testflight/)
