# Architecture

## System Overview

YouSkill iOS is a SwiftUI application for browsing, reading, and translating Agent Skills on mobile devices. The app combines a remote skill catalog API with direct GitHub file tree and raw file reads so users can discover skills, open `SKILL.md`, inspect related files, and translate Markdown into a target language. The main user-facing interfaces are the home feed, the skill detail reader with a catalog drawer, and the settings flow for translation model configuration.

## Catalog Navigation

The catalog uses `NavigationSplitView`: the sidebar contains the category/repository picker and catalog list; the detail column contains the selected scope's Skills and a `NavigationStack` for the reader. Wide windows show both columns; the system can hide the sidebar when space is limited. Compact windows show one column at a time, starting with the catalog. The system controls column collapse and toolbar placement.

`SkillListView` owns the view model, search draft, sort, result scroll position, and reader path above both columns. Display changes do not reset them. Selecting a catalog scope returns the detail column to its results; selecting a different scope resets the result scroll position. The selected scope is highlighted in the wide catalog. Before an explicit selection, the detail column shows all Skills.

## Domain Model

- **Skill Catalog** — Remote skill listing, search, sorting, pagination, and feed presentation.
- **Skill Content** — GitHub repository resolution, skill directory tree construction, raw file retrieval, and file-type aware rendering.
- **Translation** — Chat Completion API model configuration, connectivity validation, translation requests, and translation caching.
- **Settings** — Local persistence of translation settings, target language preference, translation display mode (bilingual or translation only), version metadata, and external links.
- **Favorites** — Local favorite records (state, `updatedAt`, snapshot, pending flag), favorite-only filtering, and sync with the account favorites on the server. A favorite whose skill left the marketplace shows from its snapshot as unavailable.
- **Account** — Optional sign-in with Apple or GitHub through the server (OAuth with PKCE), Keychain session, sign-out, and account deletion. See [Account API](references/account-api.md).

> Planned: favorites will sync across the desktop and iOS apps through a server account (GitHub or Apple sign-in). Current favorites become local favorites and merge into the account at first sign-in. See `youskill-web/docs/decisions/0001` to `0004` and `youskill-web/docs/glossary.md`.

## Layer Structure

Each domain follows a fixed set of layers with strictly validated dependency directions:

```
Types → Config → Repo → Service → Runtime → UI
```

| Layer | Responsibility |
|---|---|
| **Types** | Shared type definitions and schemas |
| **Config** | Configuration loading and validation |
| **Repo** | Data access and persistence |
| **Service** | Business logic and orchestration |
| **Runtime** | Application lifecycle, scheduling, background work |
| **UI** | User interface and presentation |

## Dependency Rules

- Code may only depend **forward** through layers (Types → Config → ... → UI)
- Cross-cutting concerns (auth, telemetry, feature flags) enter through **Providers** (`Sources/Providers/`). `AuthProvider` is the only owner of account tokens; other code gets a token through `withAccessToken`.
- No circular dependencies between domains
- Shared utilities live in a `utils/` package outside domain boundaries

## Key Abstractions

- **Repository protocols** — `SkillCatalogRepositoryProtocol`, `SkillContentRepositoryProtocol`, and `TranslationRepositoryProtocol` define the system edges for remote APIs and GitHub content access.
- **Services** — `SkillCatalogService`, `SkillContentService`, and `TranslationService` orchestrate repository calls and cache-aware workflows without leaking transport details into UI.
- **Stores** — `FavoritesStore` and `AppSettingsStore` own user-defaults-backed local state and expose it to the UI. `FavoritesStore` knows nothing about accounts; it keeps pending changes and applies server records.
- **Favorite sync** — `FavoriteSyncService` pushes pending changes, then pulls from the stored cursor (last write wins on `updatedAt`, tombstones apply, a rejected add reverts). It runs on launch, on return to the app, after a local change (debounced), and when the network comes back. It also runs sign-in (local favorites merge as a union: in the first sync, a local favorite wins over an account tombstone), sign-out, and account deletion, which clear the favorites on the device.
- **App container** — `AppContainer` wires stores, repositories, and services into a single runtime composition root.
- **File tree builder** — `FileTreeBuilder` converts flat GitHub paths into a hierarchical drawer model for the detail screen.

## Technology Choices

- **SwiftUI + Observation** — Native iOS UI with explicit state ownership and lightweight reactive view models.
- **URLSession + async/await** — Standard Apple networking stack; avoids unnecessary third-party dependencies for a small API surface.
- **XcodeGen** — Declarative project generation keeps the repo readable and reproducible from `project.yml`.
- **Direct GitHub access** — Uses Git Trees API for directory discovery and `raw.githubusercontent.com` for file reads instead of cloning repositories.
- **Disk-backed caches** — File tree, file content, and translation results cache to the app cache directory using hashed keys.
- **UserDefaults persistence** — Settings and local favorite records (at most about 1000 favorites plus tombstones). Favorites saved before account sync migrate once from the `favorite-skills` key; each record decodes on its own.
- **Keychain** — Account access and refresh tokens, available after first unlock on this device only.
- **ASWebAuthenticationSession** — Sign-in runs the server OAuth flow in the system browser, so iOS and the desktop app use the same flow.
