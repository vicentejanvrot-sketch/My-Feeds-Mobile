import Foundation
import Supabase
import Observation

/// Global authentication state driven by Supabase auth changes.
@Observable
final class AuthStore {
    enum Status {
        case loading
        case authenticated
        case unauthenticated
    }

    var status: Status = .loading
    var userEmail: String?
    var userId: String?

    private var listenTask: Task<Void, Never>?

    func start() {
        guard listenTask == nil else { return }
        listenTask = Task { [weak self] in
            let auth = SupabaseService.shared.client.auth
            for await change in auth.authStateChanges {
                guard let self else { return }
                let session = change.session
                self.userEmail = session?.user.email
                self.userId = session?.user.id.uuidString.lowercased()
                self.status = session != nil ? .authenticated : .unauthenticated
            }
        }
    }

    func signIn(email: String, password: String) async -> String? {
        do {
            try await SupabaseService.shared.client.auth.signIn(email: email, password: password)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Backend auto-confirms accounts; if signUp returns no session, sign in immediately.
    func signUp(email: String, password: String) async -> String? {
        do {
            let response = try await SupabaseService.shared.client.auth.signUp(email: email, password: password)
            if response.session == nil {
                try await SupabaseService.shared.client.auth.signIn(email: email, password: password)
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func signOut() async {
        try? await SupabaseService.shared.client.auth.signOut()
        userEmail = nil
        userId = nil
        status = .unauthenticated
    }

    func sendPasswordReset(email: String) async -> String? {
        do {
            try await SupabaseService.shared.client.auth.resetPasswordForEmail(
                email,
                redirectTo: URL(string: "rork-app://reset-password")
            )
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func updatePassword(_ newPassword: String) async -> String? {
        do {
            try await SupabaseService.shared.client.auth.update(user: UserAttributes(password: newPassword))
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
