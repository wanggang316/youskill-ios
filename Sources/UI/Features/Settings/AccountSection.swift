import AuthenticationServices
import SwiftUI

/// Sign-in, the signed-in identity, sign-out, and account deletion.
struct AccountSection: View {
    let authProvider: AuthProvider
    let syncService: FavoriteSyncService

    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @State private var isWorking = false
    @State private var isConfirmingSignOut = false
    @State private var isConfirmingDeletion = false
    @State private var failure: Failure?

    var body: some View {
        Section {
            if let identity = authProvider.identity {
                signedIn(identity)
            } else {
                signedOut
            }
        } header: {
            Text(L10n.string("account.section"))
                .font(.subheadline)
                .fontWeight(.regular)
                .textCase(nil)
        } footer: {
            if authProvider.identity != nil {
                Text(L10n.string("account.identity_hint"))
            }
        }
        .disabled(isWorking)
        .alert(failure?.title ?? "", isPresented: Binding(
            get: { failure != nil },
            set: { if !$0 { failure = nil } }
        )) {
            Button(L10n.string("common.done"), role: .cancel) {}
        } message: {
            Text(failure?.message ?? "")
        }
    }

    private var signedOut: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("account.signed_out_message"))
                .font(.footnote)
                .foregroundStyle(.secondary)
            // Guideline 4.8: both options have the same size and style.
            signInButton(.apple, title: "account.sign_in_apple") { Image(systemName: "apple.logo") }
            signInButton(.github, title: "account.sign_in_github") {
                Image("github").renderingMode(.template).resizable().scaledToFit().frame(width: 18, height: 18)
            }
            if isWorking {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
    }

    private func signInButton<Icon: View>(
        _ provider: SignInProvider,
        title: String,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        Button {
            Task { await signIn(with: provider) }
        } label: {
            HStack(spacing: 8) {
                icon()
                Text(L10n.string(title)).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(.white)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("account.sign-in.\(provider.rawValue)")
    }

    @ViewBuilder
    private func signedIn(_ identity: AccountIdentity) -> some View {
        LabeledContent(L10n.format("account.signed_in_with", L10n.string("account.provider.\(identity.provider.rawValue)"))) {
            Text(identity.displayName ?? identity.email ?? "")
        }
        .accessibilityIdentifier("account.identity")
        if let email = identity.email, identity.displayName != nil {
            Text(email)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        Button(L10n.string("account.sign_out")) {
            isConfirmingSignOut = true
        }
        .accessibilityIdentifier("account.sign-out")
        .confirmationDialog(L10n.string("account.sign_out_confirm_title"), isPresented: $isConfirmingSignOut,
                            titleVisibility: .visible) {
            Button(L10n.string("account.sign_out"), role: .destructive) {
                Task { await run { await syncService.signOut() } }
            }
        } message: {
            Text(L10n.string("account.sign_out_confirm_message"))
        }

        Button(L10n.string("account.delete"), role: .destructive) {
            isConfirmingDeletion = true
        }
        .accessibilityIdentifier("account.delete")
        .confirmationDialog(L10n.string("account.delete_confirm_title"), isPresented: $isConfirmingDeletion,
                            titleVisibility: .visible) {
            Button(L10n.string("account.delete"), role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text(L10n.string("account.delete_confirm_message"))
        }
    }

    private func signIn(with provider: SignInProvider) async {
        await run {
            do {
                try await syncService.signIn(with: provider) { url, scheme in
                    try await webAuthenticationSession.authenticate(using: url, callbackURLScheme: scheme,
                                                                    preferredBrowserSession: .shared)
                }
            } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
                // The person closed the sign-in page.
            } catch {
                failure = Failure(title: L10n.string("account.sign_in_failed"), message: error.localizedDescription)
            }
        }
    }

    private func deleteAccount() async {
        await run {
            do {
                try await syncService.deleteAccount()
            } catch {
                failure = Failure(title: L10n.string("account.delete_failed"), message: error.localizedDescription)
            }
        }
    }

    private func run(_ action: () async -> Void) async {
        isWorking = true
        await action()
        isWorking = false
    }

    private struct Failure {
        let title: String
        let message: String
    }
}
