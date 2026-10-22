---
name: release
description: Prepare, resume, submit, and verify a YouSkill iOS App Store release. Use for builds, store metadata or screenshots, review resubmission, and release tagging after successful review submission.
---

# Release YouSkill iOS

Complete the requested release through the existing Fastlane workflow. Reuse verified work and report the actual App Store state. Upload, review submission, approval, public availability, and Git tagging are separate milestones. A tag does not publish this app; the current GitHub Actions workflows only run checks.

## Establish the candidate and remote state

Read `AGENTS.md`, `docs/references/ios-release.md`, the relevant lanes in `fastlane/Fastfile`, and `scripts/release-candidate.rb`. These are the release contract. Keep reusable workflow logic there rather than creating a second release system. Use the existing execution plan for decisions, evidence, and pending work; do not treat ignored recovery scripts as maintained tooling.

Before a long operation, inspect:

- Branch, HEAD, working tree, `project.yml` version/build, and existing tags.
- `build/release/manifest.json`, its original source revision and hashes, and the IPA's embedded version/build.
- Acceptance records, existing source captures, and `fastlane/screenshot-selection.json`.
- App Store Connect version/build processing, selected build, localized metadata, screenshots and processing errors, review submission, and release mode.
- Running uploaders and simulator suites. Do not start a duplicate process.

Use the repository Ruby version, Bundler, selected Xcode, and existing local configuration. A transferred checkout may contain artifacts but lack gems; restore the locked dependencies before running Fastlane. Required API variables are `ASC_KEY_ID`, `ASC_ISSUER_ID`, and `ASC_KEY_PATH`. Never print credentials or store the private key in Git.

## Resume the next unfinished stage

| Observed state | Next action |
| --- | --- |
| Prepared candidate, clean matching HEAD, valid assets | Inspect selected images, then run `bundle exec fastlane ios release`. |
| Prepared candidate, later non-artifact commits | Use `release reuse_prepared:true` only when the existing gate accepts ancestry, unchanged app inputs, original clean acceptance, version/build, hashes, and screenshot inventory. |
| Metadata or images partly uploaded | Read remote state and reconcile only missing or incorrect items through installed Fastlane/Spaceship dependencies. |
| IPA upload accepted or build processing | Check the exact version/build before any retry. Wait for processing; do not upload the same build again. |
| Build VALID, assets ready, no review requested | Select the exact existing build and submit without binary or asset upload. |
| Review requested, no requested changes | Verify selection and release mode, then create the submission tag if missing. Do not submit again. |
| Review requested, user asks to change screenshots | Cancel that submission, wait until the version is editable, update the requested assets, then resubmit the same valid build. |
| No prepared candidate | Commit release inputs and use `prepare_release`; inspect its output before submission. |
| Public release confirmed | Record public availability separately from the existing submission tag. |

`prepare_release` runs acceptance, capture, and archive; it is not a resume command and rejects an existing capture directory. Preserve valid outputs. Repair only the failed stage, with a narrow tested lane change if required.

The release lane requires a clean checkout. By default HEAD must match the manifest. The explicit reuse path permits only the changes accepted by `scripts/release-candidate.rb`; it does not assert that newer tests ran. Preserve the original manifest revision and record the submission revision separately. Never rewrite provenance or check out an old commit to defeat the gate. Later documentation commits also advance HEAD.

## Select screenshots before uploading

The capture inventory is evidence, not the upload selection. Do not upload every captured image just because it exists or passes its hash check.

Use **3–5 distinct core screens per language and device display group**, with the same content and order across groups. Do not interpret this as a combined limit across all device groups. The current selection is categories, popular repositories, skills, and reader for both ordinary iPhone and expanded Duo, in each supported locale. Read the selection file for the actual filenames and groups rather than relying on a remembered total.

Use the largest supported ordinary iPhone screenshot size and Apple's scaling for smaller sizes where applicable. Preserve a distinct Duo group with equivalent screen coverage; one Duo image does not replace a full matching set. The regression device matrix does not require marketing images for every tested model or posture. Consult current Apple specifications if display-size acceptance is uncertain.

Validate and inspect the complete proposed selection **before any remote replacement**:

- Every supported locale and intended device group is present.
- Screen identities, count, and order agree across the matrix.
- Images have accepted dimensions, opaque pixels, correct locale/UI, live content, and no blank or clipped content. Inspect Duo expanded layouts.
- Selected files match original manifest hashes. Use the selection helper to create a separate upload directory; preserve unselected captures and the original manifest.

`fastlane/screenshot-selection.json` is the maintained selection. `ReleaseCandidate.select_screenshots!` validates it and produces a content-addressed upload directory. For a missing or bad image, repair that item rather than recapturing the whole matrix. Preserve supported locales and accurate accepted text unless the release requires a change.

## Upload and recover without repeating successful work

The release lane uploads metadata and IPA, replaces selected screenshot sets, requests review, and sets automatic release. Understand all of those effects before invoking it. Use it for a fresh submission, not as a blind retry after partial success.

For the pinned Fastlane, `ipa` and `build_number` are mutually exclusive. For a new upload, pass the IPA and validate its embedded version/build; Deliver derives the build to wait for from the IPA. For an existing build, pass the exact build number, omit the IPA, and skip binary upload. Validate options before a remote mutation when changing invocation code.

Read remote state before a partial retry. Compare selected filenames, display groups, source checksums, processing states, and order. Retain matching COMPLETE images and upload only missing items. Remove only images outside the authorized selection. Do not delete accepted images merely because processing has not yet supplied a checksum. Treat `UPLOAD_COMPLETE` as pending processing, not an upload failure or completion of acceptance.

Concurrent screenshot requests on this host produced `SSL_read` / `tls_retry_write_records` failures. Check the partial result and retry the affected operation once with `DELIVER_NUMBER_OF_THREADS=1`. A TLS error is not proof of invalid screenshot dimensions. Do not restart preparation or repeat metadata/binary upload to recover a screenshot request.

Poll processing with a bounded wait and keep logs. Inspect the installed helper's behavior: the pinned beta screenshot sync has an unbounded exponential processing wait and can replace images whose checksums are not yet available. Prefer targeted reconciliation for a partial upload. Image and build processing can proceed independently; end the previous uploader before starting a separate missing stage, then gate review on both being ready.

Cancellation is also asynchronous. A cancellation response does not mean screenshots are editable. Wait for the old submission to leave progress and the version to become editable (for example, `DEVELOPER_REJECTED`) before changing images. Preserve the valid build and verified declarations during resubmission.

## Submit and verify the result

A release request authorizes upload and review submission for the agreed candidate. A skill-edit or preparation-only request does not. User-requested screenshot corrections during review authorize cancellation and resubmission needed for that correction. Do not infer permission to merge, push tags, or change unrelated services.

Verify version/build, signing, privacy/support links, metadata, selection, and provenance. Preserve review contact, content-rights, and encryption declarations unless a verified change requires an update. Fix factual precheck issues from evidence: for example, add the release year while retaining the verified copyright owner. Do not invent compliance answers or dismiss a real warning because Fastlane allows it.

After submission, read App Store Connect again and verify:

- Exact version/build, VALID processing, selected build, review state, and automatic release setting.
- All intended locales and device groups, exact ordered filenames/counts, COMPLETE image states, and source checksums matching local images.
- Intended descriptions, release notes, names, subtitles, and privacy/support URLs.

A zero exit status or successful upload alone is not enough. Once WAITING_FOR_REVIEW is confirmed, report that review is pending and automatic release is configured. Do not wait indefinitely for Apple's decision or claim public availability from submission.

## Tag after successful review submission

Create an annotated tag after App Store Connect confirms successful review submission for the exact version and selected build, normally WAITING_FOR_REVIEW. Do not wait for approval or public availability. An accepted binary upload alone is not enough. The tag records a submitted candidate; it does not claim that Apple approved or published it.

Follow the repository's existing naming convention. Point the tag at the **source revision that produced the submitted IPA**, taken from the verified manifest, rather than an arbitrary later documentation or tooling commit. Include the marketing version, build number, and confirmed submission evidence in the annotation. Record later submission-tool revisions separately. Check existing local tags and relevant remote tags before creation. Tag creation does not by itself authorize pushing it or publishing a GitHub Release.

If review fails and code changes are needed, create and validate a new build, submit it, then create a new annotated tag for that candidate. Preserve previous tags. Use the new version tag when the version changes; when only the build changes, use a distinct build-qualified tag such as `<version>-build.<build>`. Do not move or overwrite a tag from an earlier submission. Screenshot or metadata corrections that reuse the same IPA do not require a new source tag; record the resubmission evidence in the execution plan.

Record the tag name, source revision, version/build, and review state in the execution plan. Continue to report review and public availability separately. Do not imply that background monitoring is active unless it was actually configured.

## Completion and cost control

Keep successful outputs and logs. If the same operation fails again without new evidence, stop that retry loop and report the precise blocker and smallest next action. Do not erase simulators, broaden captures, or alter app behavior for an unrelated environment problem. Do not rerun acceptance without source changes, failures, or missing evidence.

Record durable outcomes in the existing execution plan after accounting for the clean-HEAD gate. Report version/build, screenshot matrix, upload/review/public state, tag state, and any blocker. Label local checks, simulator acceptance, remote verification, and public availability separately.
