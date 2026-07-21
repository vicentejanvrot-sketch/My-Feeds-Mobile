import SwiftUI

struct LoginView: View {
    @Binding var path: [AuthRoute]
    @Environment(AuthStore.self) private var auth

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var toast: AuthToast?
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    var body: some View {
        AuthScaffold(toast: $toast) {
            AuthBranding(title: "My Feeds", subtitle: "Sign in to your account to continue.")

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
    }

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
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                toast = AuthToast(message: "Welcome back!", isError: false)
            }
        }
    }
}
