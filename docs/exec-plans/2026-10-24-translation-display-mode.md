# ExecPlan: Translation Display Mode and Reader Translation Menu

**Status:** Completed
**Author:** Claude (HAN-259)
**Created:** 2026-10-24
**Last Updated:** 2026-10-24

## Purpose / Big Picture

Match the desktop app (you-skill `main` `dc3212e`): Settings gains a global display mode (Bilingual / Translation, default Bilingual). In the reader, an untranslated file shows Translate; once a translation exists the toolbar becomes a native Menu with Bilingual / Translation / Original and Retranslate. Bilingual view stacks each original Markdown block above its translation. A failed translation no longer replaces the page.

Source of truth: the v1.0 product spec "youskill-ios 翻译显示模式与正文页翻译下拉" (Linear HAN-259).

## Context and Orientation

- `Sources/Types/TranslationSettings.swift` — persisted settings (`UserDefaults` key `translation-settings`, JSON). Adds `TranslationDisplayMode`, the reader-only `TranslationView`, and `missingFields`.
- `Sources/Types/BilingualMarkdown.swift` — `MarkdownBlockParser` splits Markdown into blocks; `BilingualMarkdownAligner` aligns original and translated blocks by kind (LCS) into `BilingualSegment`s.
- `Sources/Service/TranslationService.swift` — `translate(force:)`, `cachedTranslation`, unchanged-result rejection.
- `Sources/UI/Features/Detail/SkillDetailViewModel.swift` / `SkillDetailView.swift` — reader view state, toolbar Menu, failure banner.
- `Sources/UI/Components/MarkdownContentView.swift` — renders a single Markdown body or bilingual segments.

## Plan of Work

1. Settings field, migration, and Picker.
2. Block parser and aligner (pure, Foundation only).
3. Service: force, cache lookup, unchanged results.
4. Reader view model and UI.
5. Unit and UI tests; screenshots from the UI test attachments.

## Progress

- [x] 2026-10-24 Settings display mode, migration, Picker (`a49206a`)
- [x] 2026-10-24 Block alignment (`b863b19`)
- [x] 2026-10-24 Service force / cache restore / unchanged results (`801f9ce`)
- [x] 2026-10-24 Reader menu, bilingual rendering, failure banner (`d57f42d`)
- [x] 2026-10-24 UI tests with screenshot attachments (`6c092d3`)
- [x] 2026-10-24 Review: icon toolbar control

## Surprises & Discoveries

- The translation cache key used `String.hashValue`, which is seeded per process, so cached translations were never found after a relaunch. Restoring a cached translation on open (P1) depends on a stable key, so the key now contains the source text itself; `DiskCache` already hashes the whole key with SHA-256. Old entries are orphaned once.
- The UI-test translation cache lives in the simulator's Caches directory and persisted between tests. With restore-on-open, that would hide the Translate button, so the fixture clears it when launched with `--ui-testing`.
- MarkdownUI strips the top margin of the first block in each `Markdown` view, so bilingual segments are separate `Markdown` views in a `VStack` with fixed spacing.

## Decision Log

- **Decision:** Parse Markdown blocks with a small line-based parser instead of MarkdownUI internals.
  **Rationale:** MarkdownUI's block tree is internal; a Foundation-only parser is testable and covers the block kinds the spec names (heading, paragraph, list, quote, table, code, rule, HTML).
  **Date/Author:** 2026-10-24 / Claude
- **Decision:** A bilingual heading renders as two SwiftUI `Text` lines (inline Markdown) at the GitHub theme's heading size, with one rule under h1/h2.
  **Rationale:** An ATX heading cannot contain a line break, and the spec asks for the translation as the heading's second line. A custom MarkdownUI theme does not compile under Swift 6 strict concurrency (its style closures are nonisolated while SwiftUI modifiers are main-actor isolated).
  **Date/Author:** 2026-10-24 / Claude
- **Decision:** List items pair only when item counts match; the translation is appended inside the item as an indented paragraph. Otherwise the whole lists stack.
  **Rationale:** Desktop behavior; spec §7.
  **Date/Author:** 2026-10-24 / Claude
- **Decision:** Code, rules, HTML, and blocks whose text is unchanged render once; unmatched translated code/rule/HTML blocks are dropped.
  **Rationale:** Desktop `UNTRANSLATED_BLOCK_TYPES` and `sameText`.
  **Date/Author:** 2026-10-24 / Claude
- **Decision:** Retry after a failure repeats the failed request's mode (forced or not).
  **Rationale:** A failed Retranslate must not silently return the old cached text.
  **Date/Author:** 2026-10-24 / Claude
- **Decision:** The reader's translation control is a drawn icon (globe behind an "A" bubble and a "文" bubble) instead of the view name. Original fills A, Translation fills 文, Bilingual fills both; before a translation exists neither is filled. VoiceOver reads "Translation view" with the current view as its value.
  **Rationale:** Review feedback on HAN-259: the text label was too long for the toolbar. Drawn with SwiftUI shapes so it follows the toolbar tint and disabled state.
  **Date/Author:** 2026-10-24 / Claude
- **Decision:** No translated-text styling option.
  **Rationale:** Spec P2.
  **Date/Author:** 2026-10-24 / Claude

## Outcomes & Retrospective

All P0 and P1 items from the spec are implemented. Logic is covered by `BilingualMarkdownTests`, `TranslationSettingsTests`, `TranslationServiceTests`, `SkillDetailViewModelTests`, and `AppSettingsStoreTests`; the reader flow by `ReleaseAcceptanceTests.testTranslationViewsRetranslateAndFailureKeepTheReader`.
