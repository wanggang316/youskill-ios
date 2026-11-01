import Foundation

enum SignInProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case apple
    case github

    var id: String { rawValue }
}

/// The sign-in identity of the account. Identities are never linked, so it also names the account.
struct AccountIdentity: Codable, Equatable, Sendable {
    let provider: SignInProvider
    let displayName: String?
    let email: String?
}

struct AccountSession: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let accessTokenExpiresAt: Date
    let identity: AccountIdentity
}

enum FavoriteChangeStatus: String, Sendable {
    case applied
    /// The server already has the same or a later write; the record shows the stored state.
    case ignored
    case rejected
}

struct FavoriteChangeResult: Equatable, Sendable {
    static let limitReachedError = "favorite_limit_reached"

    let skillID: Int
    let status: FavoriteChangeStatus
    let error: String?
    let record: RemoteFavorite?
}

struct FavoriteChangesPage: Equatable, Sendable {
    let records: [RemoteFavorite]
    let cursor: Int
    let hasMore: Bool
}
