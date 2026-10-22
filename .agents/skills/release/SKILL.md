---
name: release
description: Prepare, resume, and submit a YouSkill iOS App Store release from this repository. Use when asked to release the app, upload a build, update store metadata or screenshots, or resume a failed submission.
---

# Release YouSkill iOS

Complete the requested release with the existing Fastlane workflow. Reuse valid work and report the actual App Store state. Creating a Git tag does not publish this app; the current GitHub Actions workflows only run checks.

## Read the current state first

Run from the repository root. Read `AGENTS.md`, `docs/references/ios-release.md`, and the relevant lanes in `fastlane/Fastfile`. These files define the release contract; do not copy their implementation into a second release script.

Before starting a long operation, inspect:

- The branch, HEAD, working tree, and `project.yml` version and build number.
- `build/release/manifest.json`, its source revision and artifact hashes, and `build/release/YouSkill.ipa`.
- Existing images in `fastlane/screenshots/` and evidence in `build/test-results/`.
- App Store Connect: the target version, uploaded builds, processing state, selected build, localized metadata, screenshot sets, and review state.
- Any release process already running. Do not start a second uploader or simulator suite.

Use current files and remote state, not an earlier progress message. File existence alone does not prove validation or upload. Never print credentials. Use the repository Ruby and Bundler environment, the selected Xcode, and the existing `.env` or environment variables. Required API variables are `ASC_KEY_ID`, `ASC_ISSUER_ID`, and `ASC_KEY_PATH`; keep the private key outside Git.

## Choose the next unfinished stage

| Observed state | Next action |
| --- | --- |
| Valid manifest, matching clean HEAD, unchanged assets | Inspect the images, then run `bundle exec fastlane ios release`. Do not rerun preparation. |
| Build already uploaded or submission partly complete | Read App Store Connect first. Resume only the missing metadata, screenshot, build-selection, or review step through the existing Fastlane/Spaceship dependencies. Do not blindly upload the IPA again. |
| Review already requested | Verify the selected build and release mode. Report the review state; do not create another submission. |
| No prepared candidate | Commit the intended version/build and release inputs, then use `bundle exec fastlane ios prepare_release`. Inspect its output before submission. |
| Stale or incomplete local artifacts | Identify the exact failed contract and preserve the usable evidence. Repair only the affected stage. Do not describe partial output as accepted. |

The current `prepare_release` lane always runs acceptance, captures screenshots, and archives. It is not a resume command and rejects an existing screenshot destination. Do not invoke it merely because a previous attempt stopped. If preparation needs a resume capability, make a narrow, tested change to the existing lane that verifies reusable inputs; do not delete valid screenshots or fabricate a manifest to bypass the guard.

The current `release` lane requires a clean HEAD equal to the manifest revision and verifies asset hashes. Even a documentation-only commit changes HEAD. Check this before committing during a prepared release. Never rewrite the manifest revision or check out an older revision just to defeat the gate. If a later commit must be released, establish which evidence and artifacts remain valid under an explicit, tested reuse contract, or rebuild the affected candidate.

## Keep screenshots proportional

Reuse the existing store images when they show the intended release and pass inspection. Read their dimensions, transparency, locale, and display group, then inspect the chosen images for empty content, clipping, and correct UI. Include the Duo expanded layout when Duo support is part of the release.

The regression device matrix is not the marketing screenshot matrix. Do not capture every tested device, every posture, or every page by default. Select a small set of distinct core screens. Use the App Store's supported scaling for ordinary iPhone sizes where applicable. Consult Apple's current screenshot specifications only when a size or upload constraint is uncertain.

Preserve existing supported locales and accurate store text. Do not add languages or replace accepted images without a release need. Do not retake the full set for one bad image. If the set is already bound by the manifest, do not silently remove or replace files; use the release contract to validate and record any asset change.

## Submit and verify

A request to publish authorizes upload and review submission for the agreed candidate. Continue under that authorization; ask only for missing factual information or a new consequential decision. A request only to prepare or write this skill does not authorize submission. Do not infer permission to merge, push tags, or change unrelated services.

Before upload, verify the version/build, metadata, privacy and support links, signing, screenshot selection, and manifest. Preserve existing review contact, content-rights, and encryption declarations unless a verified change requires an update. Do not invent compliance answers.

The existing `release` lane uploads the IPA and metadata, replaces screenshot sets, requests review, and selects automatic release after approval. Account for that entire effect before invoking it. For a partial retry, inspect remote state before repeating any mutation, especially screenshot replacement.

After Fastlane finishes, read App Store Connect again and verify:

- The exact version and build, processing result, and selected build.
- The intended localized metadata and screenshot groups, including image processing errors.
- The review submission state and automatic release setting.

An accepted upload is not a review submission. A review submission is not a public release. Report the exact reached state. Do not wait indefinitely for Apple's review; once submission is confirmed, state that approval is pending and automatic release is configured.

## Recovery and cost control

Keep successful outputs and logs. For a transient failure, retry the affected step once after checking the cause. If the same failure repeats without new evidence, stop that loop and report the precise blocker and smallest next action. Do not restart the entire matrix, erase simulators, increase screenshot scope, or change app behavior to work around an unrelated environment failure.

Do not run tests again after acceptance unless source changes, failures, or missing evidence justify them. Keep brief progress updates focused on the remaining release stage. At completion, report version/build, upload/review/public state, and any blocker. Record durable evidence in the existing execution plan after accounting for the manifest's clean-HEAD requirement.
