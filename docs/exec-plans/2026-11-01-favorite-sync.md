# ExecPlan: Favorite Sync with Account Sign-in

**Status:** Completed
**Author:** Claude (youskill-ios#5)
**Created:** 2026-11-01
**Last Updated:** 2026-11-01

## Purpose / Big Picture

Favorites were local to the phone. Now they are local records that work without an account, and after Sign in with Apple or GitHub they merge into the account and stay in sync with the desktop app and other devices. Source of truth: [youskill-ios#5](https://github.com/wanggang316/youskill-ios/issues/5), server spec [youskill-web#68](https://github.com/wanggang316/youskill-web/issues/68), decisions 0001–0004 in youskill-web.

## Context and Orientation

- `Sources/Types/Favorite.swift` — `LocalFavorite` (state, `updatedAt`, snapshot, pending flag), `RemoteFavorite`.
- `Sources/Repo/LocalStores.swift` — `FavoritesStore` (UserDefaults key `local-favorites`, cursor `favorite-sync-cursor`) and `LegacyFavoritesMigration` (reads `favorite-skills`).
- `Sources/Repo/AccountRepository.swift` — the account API edge; contract in `docs/references/account-api.md`.
- `Sources/Repo/AccountSessionStore.swift` — Keychain session.
- `Sources/Providers/AuthProvider.swift` — PKCE sign-in, refresh, session end.
- `Sources/Service/FavoriteSyncService.swift` — push/pull and account actions.
- `Sources/UI/Features/Settings/AccountSection.swift`, `SkillListView`, `SkillCard` — account UI, unavailable favorite, limit alert.

## Plan of Work

1. Local favorite model and one-time migration.
2. Account API repository and Keychain store.
3. Auth provider.
4. Sync service and its triggers.
5. Account UI, unavailable favorites, localization.
6. Privacy manifest, docs, UI tests with fixtures.

## Progress

- [x] 2026-11-01 Local records and lenient migration (`8ef9b3f`)
- [x] 2026-11-01 Account repository and Keychain store (`1dbab72`)
- [x] 2026-11-01 Auth provider (`f09c2d1`)
- [x] 2026-11-01 Sync service (`8ded99e`), triggers and marketplace lookup (`ecf39d6`)
- [x] 2026-11-01 Account settings, unavailable favorite, limit alert (`2860cf6`)
- [x] 2026-11-01 Privacy manifest, docs, UI tests
- [x] 2026-11-01 Review: first merge keeps local favorites over account tombstones; App Store privacy details prepared as a release gate; merge protection follows the current record (round 2)
- [ ] Remaining outside this repository: final server routes (youskill-web#68), redirect URI registration, App Store Connect privacy details, real Apple and GitHub sign-in on a device

## Surprises & Discoveries

- The server routes did not exist when this work started; only the favorite repository was in progress. The client follows its statuses and states and keeps every route in one file.
- Favorites pulled from the server have no reader fields (URL, path, branch). The favorites list looks each skill up in the marketplace (`GET /api/public/skills/{id}`); a 404 marks it unavailable.
- Refresh tokens rotate and reuse revokes the session, so concurrent requests must share one refresh.
- In UI tests, a `LabeledContent` with an accessibility identifier merges into one static text ("Signed in with GitHub, Ada Lovelace").

## Decision Log

- **Decision:** Keep favorites in UserDefaults under a new key; leave the legacy key untouched until sign-out or account deletion.
  **Rationale:** The record shape fits; a read-only legacy key makes the migration safe to repeat after a crash, and nothing is lost if a record cannot be read.
  **Date/Author:** 2026-11-01 / Claude
- **Decision:** A legacy record needs only an `id`; missing fields fall back (name → source → id, added time → 1970).
  **Rationale:** "Must not drop records that fail to decode individually." Only a record without an id cannot become a favorite.
  **Date/Author:** 2026-11-01 / Claude
- **Decision:** A local change gets `updatedAt = max(now, previous + 1 ms)`.
  **Rationale:** Last write wins with ties kept on the server; a change must be later than the record it replaces, even with a clock behind the server record.
  **Date/Author:** 2026-11-01 / Claude
- **Decision:** Every sign-in is a merge (push all local favorites, pull from no cursor), including after a session expired.
  **Rationale:** The spec keeps local records when a session ends; the next sign-in must not drop them.
  **Date/Author:** 2026-11-01 / Claude
- **Decision:** In the first sync with an account, a local favorite wins over an account tombstone, even a later one. The store keeps the merge set (`favorite-account-merge`); when the push answer is a tombstone, the favorite gets a time after it and is pushed again. After that answer, last write wins again.
  **Rationale:** Review of the first version: with the saved `updatedAt`, a later tombstone from another device removed the local favorite, so the merge was not a union as issue #5 requires. The set is persisted so an interrupted first sync still merges as a union.
  **Date/Author:** 2026-11-01 / Claude
- **Decision:** The current record decides the merge protection, not the pushed change: a favorite that is favorited and pending when the tombstone answer arrives is kept, even if the person removed and added it again during the push. A removal made during the push is not protected.
  **Rationale:** Review round 2: the first fix compared the pushed time with the current record, so an in-flight remove and re-add lost the protection and the tombstone removed the favorite.
  **Date/Author:** 2026-11-01 / Claude
- **Decision:** The sign-in page opens through SwiftUI `WebAuthenticationSession`, passed into `AuthProvider` as a closure.
  **Rationale:** It is `ASWebAuthenticationSession` with the presentation anchor handled by SwiftUI, and tests pass a fake closure.
  **Date/Author:** 2026-11-01 / Claude
- **Decision:** Sign-out asks for confirmation.
  **Rationale:** It removes all favorites from the device.
  **Date/Author:** 2026-11-01 / Claude

## Outcomes & Retrospective

Favorites, sign-in, sync, sign-out, and account deletion are in place and covered by unit tests with a fake server and UI tests with fixtures. The server contract is assumed until youskill-web#68 ships; `AccountRepository` is the single place to adjust.
