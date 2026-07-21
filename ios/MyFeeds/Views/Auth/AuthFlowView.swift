import SwiftUI

enum AuthRoute: Hashable {
    case signup
    case forgotPassword
    case resetPassword
}

/// Auth navigation stack shown while unauthenticated.
struct AuthFlowView: View {
    @State private var path: [AuthRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            LoginView(path: $path)
                .navigationDestination(for: AuthRoute.self) { route in
                    switch route {
                    case .signup:
                        SignupView(path: $path)
                    case .forgotPassword:
                        ForgotPasswordView(path: $path)
                    case .resetPassword:
                        ResetPasswordView(path: $path)
                    }
                }
        }
        .onOpenURL { url in
            if url.absoluteString.contains("reset-password") {
                path = [.resetPassword]
            }
        }
    }
}
