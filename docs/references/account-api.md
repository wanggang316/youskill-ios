# Account and Favorite Sync API

Source: server spec [youskill-web#68](https://github.com/wanggang316/youskill-web/issues/68) and decision records [0001–0004](https://github.com/wanggang316/youskill-web/tree/main/docs/decisions). Written 2026-11-01.

The server contract is [youskill-web `docs/account-api.md`](https://github.com/wanggang316/youskill-web/blob/main/docs/account-api.md) (youskill-web#69). This page lists only what the client uses. All routes live in `Sources/Repo/AccountRepository.swift`.

## Common rules

- Base URL: `AppConfiguration.apiBaseURL`.
- Every request sends `X-API-Key` (the app key). Account requests also send `Authorization: Bearer <access token>`.
- HTTP 401 means the token is expired, revoked, or unknown. The client refreshes once; a 401 on refresh ends the session.

## Sign-in (OAuth with PKCE)

1. The client opens `GET /api/account/sign-in/{apple|github}?redirect_uri=youskill-ios://auth/callback&code_challenge=<S256>&code_challenge_method=S256&state=<random>` in `ASWebAuthenticationSession`.
2. The server redirects to `youskill-ios://auth/callback?code=<code>&state=<state>`, or with `error=<reason>`.
3. `POST /api/account/token` with `{"code", "code_verifier", "redirect_uri"}`.

Token response (also for refresh):

```json
{"access_token": "…", "refresh_token": "…", "token_type": "Bearer", "expires_in": 900,
 "account": {"id": 5, "display_name": "Ada", "email": null, "created_at": "…",
             "identities": [{"provider": "github", "display_name": "Ada", "email": null}]}}
```

The client takes the first identity. Identities are never linked in v1, so there is exactly one.

The server must register `youskill-ios://auth/callback` as a client redirect URI.

## Session

| Request | Body | Notes |
|---|---|---|
| `POST /api/account/refresh` | `{"refresh_token"}` | Rotates the refresh token. |
| `POST /api/account/sign-out` | none | Revokes the session of this device. Best effort. |
| `DELETE /api/account` | none | Deletes the account at once. The client clears local data after success. |

## Favorites

Record: `{"skill_id": 12, "state": "favorited" | "removed", "updated_at": "<ISO 8601>", "change_seq": 7, "snapshot": {"name", "source", "description"} | null}`. A push omits `change_seq`. `snapshot` is required for `favorited`; tombstones from the server usually have `null`.

- `POST /api/account/favorites` with `{"changes": [record, …]}` (at most 200 per request; the server allows 500) returns `{"results": [{"skill_id", "status": "applied" | "ignored" | "rejected", "error": null | "favorite_limit_reached", "record": record | null}]}`. `record` is the stored state after the push.
- `GET /api/account/favorites?limit=500&cursor=<n>` returns `{"favorites": [record, …], "cursor": <n>, "has_more": false}`. No `cursor` returns all records, tombstones included.

## Marketplace lookup

`GET /api/public/skills/{id}` returns the live skill, or 404 when the skill left the marketplace.
