import Foundation
import Security

/// Gestiona la sesión de Moon Place: registro/login contra KeyAuth,
/// persistencia del usuario en Keychain y auto-login al reabrir la app.
@MainActor
final class MoonAuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var username: String?
    @Published var isBusy = false
    @Published var errorMessage: String?
    @Published var justWelcomed = false

    private var sessionID: String?

    private static let service = "cc.moonplace.auth"
    private static let account = "moon-user"

    init() {
        tryAutoLogin()
    }

    // MARK: - Registro / Login

    func register(username: String, password: String, licenseKey: String) {
        guard !isBusy else { return }
        errorMessage = nil
        isBusy = true
        Task { [weak self] in
            guard let self else { return }
            do {
                let session = try await KeyAuthClient.initialize()
                let response = try await KeyAuthClient.register(
                    sessionID: session,
                    username: username,
                    password: password,
                    license: licenseKey
                )
                guard response.success else {
                    throw KeyAuthClient.KeyAuthError.server(
                        response.message ?? "No se pudo registrar el usuario"
                    )
                }
                self.saveCredentials(username: username, password: password)
                self.finishSuccess(username: username, sessionID: session)
            } catch {
                self.fail(error)
            }
        }
    }

    func login(username: String, password: String) {
        guard !isBusy else { return }
        errorMessage = nil
        isBusy = true
        Task { [weak self] in
            guard let self else { return }
            do {
                let session = try await KeyAuthClient.initialize()
                let response = try await KeyAuthClient.login(
                    sessionID: session,
                    username: username,
                    password: password
                )
                guard response.success else {
                    throw KeyAuthClient.KeyAuthError.server(
                        response.message ?? "Usuario o contraseña incorrectos"
                    )
                }
                self.saveCredentials(username: username, password: password)
                self.finishSuccess(username: username, sessionID: session)
            } catch {
                self.fail(error)
            }
        }
    }

    func logout() {
        try? KeychainHelper.delete(service: Self.service, account: Self.account)
        sessionID = nil
        username = nil
        isAuthenticated = false
        justWelcomed = false
    }

    // MARK: - Privado

    private func tryAutoLogin() {
        guard let credentials = KeychainHelper.load(service: Self.service, account: Self.account),
              let username = credentials.username,
              let password = credentials.password else {
            return
        }
        isBusy = true
        Task { [weak self] in
            guard let self else { return }
            do {
                let session = try await KeyAuthClient.initialize()
                let response = try await KeyAuthClient.login(
                    sessionID: session,
                    username: username,
                    password: password
                )
                guard response.success else {
                    self.isBusy = false
                    return // sesión guardada inválida → mostrar login normal
                }
                self.finishSuccess(username: username, sessionID: session, silent: true)
            } catch {
                self.isBusy = false // sin red u otro error → mostrar login
            }
        }
    }

    private func finishSuccess(username: String, sessionID: String, silent: Bool = false) {
        self.sessionID = sessionID
        self.username = username
        self.isAuthenticated = true
        self.justWelcomed = !silent
        self.isBusy = false
    }

    private func fail(_ error: Error) {
        errorMessage = error.localizedDescription
        isBusy = false
    }

    private func saveCredentials(username: String, password: String) {
        KeychainHelper.save(
            username: username,
            password: password,
            service: Self.service,
            account: Self.account
        )
    }
}

/// Keychain mínimo para guardar las credenciales del usuario de Moon Place.
enum KeychainHelper {
    private static func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    static func save(username: String, password: String, service: String, account: String) {
        let data = "\(username)\u{1F}\(password)".data(using: .utf8) ?? Data()
        var query = baseQuery(service: service, account: account)
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(service: String, account: String) -> (username: String?, password: String?)? {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let combined = String(data: data, encoding: .utf8) else {
            return nil
        }
        let parts = combined.components(separatedBy: "\u{1F}")
        guard parts.count == 2 else { return nil }
        return (parts[0], parts[1])
    }

    static func delete(service: String, account: String) {
        SecItemDelete(baseQuery(service: service, account: account) as CFDictionary)
    }
}
