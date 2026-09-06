import SwiftUI

/// Pantalla de bienvenida / acceso de Moon Place.
/// - Registro: usuario + contraseña + license key de KeyAuth.
/// - Login: usuario + contraseña.
struct MoonLoginView: View {
    @ObservedObject var auth: MoonAuthManager

    @State private var mode: Mode = .login
    @State private var username = ""
    @State private var password = ""
    @State private var licenseKey = ""

    enum Mode: String, CaseIterable, Identifiable {
        case login = "Login"
        case register = "New User"
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(indigo).opacity(0.35), Color.black],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    header
                    card
                }
                .padding(24)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, Color(indigo)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            Text("MOON PLACE")
                .font(.title.bold())
                .foregroundStyle(.white)
            Text(mode == .login ? "Welcome back" : "Welcome, new user")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.top, 40)
    }

    private var card: some View {
        VStack(spacing: 16) {
            Picker("", selection: $mode) {
                ForEach(Mode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)

            VStack(spacing: 12) {
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .moonField()

                SecureField("Password", text: $password)
                    .textContentType(mode == .register ? .newPassword : .password)
                    .moonField()

                if mode == .register {
                    TextField("License Key", text: $licenseKey)
                        .font(.body.monospaced())
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .moonField()
                }
            }

            if let error = auth.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            Button(action: submit) {
                Group {
                    if auth.isBusy {
                        ProgressView().tint(.white)
                    } else {
                        Text(mode == .login ? "Enter Moon Place" : "Create Account")
                            .bold()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule().fill(
                        LinearGradient(
                            colors: [Color(indigo), Color.purple],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                )
                .foregroundStyle(.white)
            }
            .disabled(auth.isBusy || !isValid)

            Text("Access powered by KeyAuth")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 22).fill(.ultraThinMaterial))
    }

    private var isValid: Bool {
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty,
              password.count >= 4 else { return false }
        if mode == .register {
            return !licenseKey.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return true
    }

    private func submit() {
        let user = username.trimmingCharacters(in: .whitespaces)
        switch mode {
        case .login:
            auth.login(username: user, password: password)
        case .register:
            auth.register(
                username: user,
                password: password,
                licenseKey: licenseKey.trimmingCharacters(in: .whitespaces)
            )
        }
    }
}

private extension View {
    func moonField() -> some View {
        self
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.35)))
            .foregroundStyle(.white)
            .tint(Color(indigo))
    }
}
