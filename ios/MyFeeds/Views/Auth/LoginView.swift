import SwiftUI
import LocalAuthentication

struct LoginView: View {
    @Binding var path: [AuthRoute]
    @Environment(AuthStore.self) private var auth
    @Environment(VideoPrefs.self) private var prefs

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var isBiometricLoading = false
    @State private var toast: AuthToast?
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    /// The display name for the available biometric ("Face ID", "Touch ID", etc.), if any.
    private var biometryName: String? { BiometricAuthService.biometryName }

    /// Whether the biometric quick sign-in button should appear.
    private var showsBiometricLogin: Bool {
        auth.isBiometricLoginAvailable && biometryName != nil
    }

    var body: some View {
        AuthScaffold(toast: $toast) {
            AuthBranding(title: "My Feeds", subtitle: "Sign in to your account to continue.")

            if showsBiometricLogin {
                biometricCard
            }

            AuthFieldLabel(text: "Email", topMargin: 0)
            TextField("you@example.com", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }
                .modifier(AuthInputStyle(isFocused: focusedField == .email))
                .disabled(isLoading)

            AuthFieldLabel(text: "Password")
            SecureField("Your password", text: $password)
                .textContentType(.password)
                .focused($focusedField, equals: .password)
                .submitLabel(.done)
                .onSubmit { submit() }
                .modifier(AuthInputStyle(isFocused: focusedField == .password))
                .disabled(isLoading)

            PrimaryButton(title: "Sign in", isLoading: isLoading) { submit() }
                .padding(.top, 28)

            Button {
                path.append(.forgotPassword)
            } label: {
                Text("Forgot password?")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
            .padding(.top, 20)

            Button {
                path.append(.signup)
            } label: {
                Text("Don't have an account? Sign up")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.top, 12)
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .task {
            // Pre-fill the email from any saved biometric credentials.
            if email.isEmpty, let saved = auth.biometricSavedEmail {
                email = saved
            }
        }
    }

    // MARK: - Biometric card

    @ViewBuilder
    private var biometricCard: some View {
        VStack(spacing: 10) {
            Button {
                Task { await biometricSignIn() }
            } label: {
                HStack(spacing: 10) {
                    if isBiometricLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: biometryIcon)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    Text("Sign in with \(biometryName ?? "Biometrics")")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Theme.accentGradient)
                .clipShape(.rect(cornerRadius: 10))
            }
            .disabled(isBiometricLoading || isLoading)

            Text("Use \(biometryName ?? "biometrics") to unlock your saved login.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(14)
        .background(Color(hsl: 199, 40, 14, alpha: 0.5))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border, lineWidth: 0.5)
        )
        .padding(.bottom, 20)
    }

    /// SF Symbol matching the active biometric type.
    private var biometryIcon: String {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID: return "faceid"
            case .touchID: return "touchid"
            case .opticID: return "opticid"
            case .none: return "lock.fill"
            @unknown default: return "lock.fill"
            }
        }
        return "lock.fill"
    }

    // MARK: - Actions

    private func submit() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            toast = AuthToast(message: "Please fill in both email and password.", isError: true)
            return
        }
        isLoading = true
        Task {
            let error = await auth.signIn(email: trimmedEmail, password: password)
            isLoading = false
            if let error {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                toast = AuthToast(message: error, isError: true)
            } else {
                // After a successful manual sign-in, persist credentials for biometric
                // login when the user has opted in (toggle in Settings).
                auth.persistCredentialsForBiometricLogin(email: trimmedEmail, password: password)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                toast = AuthToast(message: "Welcome back!", isError: false)
            }
        }
    }

    private func biometricSignIn() async {
        isBiometricLoading = true
        let error = await auth.signInWithBiometrics()
        isBiometricLoading = false
        if let error {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            toast = AuthToast(message: error, isError: true)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            toast = AuthToast(message: "Welcome back!", isError: false)
        }
    }
}
