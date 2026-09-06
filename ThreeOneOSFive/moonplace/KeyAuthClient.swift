import Foundation

/// Cliente mínimo del API 1.3 de https://keyauth.cc
/// Documentación: https://keyauth.cc (API Documentation)
///
/// Flujo usado por Moon Place:
///   1. `initialize()` → obtiene un `sessionid` (requerido por todas las demás llamadas).
///   2. `register(username:password:license:)` → crea la cuenta usando una license key.
///   3. `login(username:password:)` → entra con usuario y contraseña.
enum KeyAuthClient {
    private static var apiBase: URL {
        URL(string: MoonConfig.keyAuthAPIURL)!
    }
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        return URLSession(configuration: configuration)
    }()

    struct Response: Decodable {
        let success: Bool
        let message: String?
        let sessionid: String?
        let info: UserInfo?
    }

    struct UserInfo: Decodable {
        let username: String?
        let ip: String?
        let hwid: String?
        let createdate: String?
        let lastlogin: String?
        let subscriptions: String?
    }

    enum KeyAuthError: LocalizedError {
        case notConfigured
        case badResponse
        case server(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "MoonConfig: rellena keyAuthAppName y keyAuthOwnerID con los datos de tu app en keyauth.cc"
            case .badResponse:
                return "Respuesta inválida del servidor de KeyAuth"
            case .server(let message):
                return message
            }
        }
    }

    // MARK: - Llamadas al API

    static func initialize() async throws -> String {
        guard !MoonConfig.keyAuthAppName.hasPrefix("REPLACE_"),
              !MoonConfig.keyAuthOwnerID.hasPrefix("REPLACE_") else {
            throw KeyAuthError.notConfigured
        }
        let response = try await post([
            "type": "init",
            "name": MoonConfig.keyAuthAppName,
            "ownerid": MoonConfig.keyAuthOwnerID,
            "ver": MoonConfig.keyAuthAppVersion,
        ])
        guard response.success, let sessionID = response.sessionid, !sessionID.isEmpty else {
            throw KeyAuthError.server(response.message ?? "No se pudo inicializar la sesión de KeyAuth")
        }
        return sessionID
    }

    static func register(
        sessionID: String,
        username: String,
        password: String,
        license: String
    ) async throws -> Response {
        try await post([
            "type": "register",
            "name": MoonConfig.keyAuthAppName,
            "ownerid": MoonConfig.keyAuthOwnerID,
            "ver": MoonConfig.keyAuthAppVersion,
            "sessionid": sessionID,
            "username": username,
            "pass": password,
            "license": license,
        ])
    }

    static func login(
        sessionID: String,
        username: String,
        password: String
    ) async throws -> Response {
        try await post([
            "type": "login",
            "name": MoonConfig.keyAuthAppName,
            "ownerid": MoonConfig.keyAuthOwnerID,
            "ver": MoonConfig.keyAuthAppVersion,
            "sessionid": sessionID,
            "username": username,
            "pass": password,
        ])
    }

    // MARK: - Red

    private static func post(_ parameters: [String: String]) async throws -> Response {
        var request = URLRequest(url: apiBase)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let formAllowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        let body = parameters
            .map { key, value in
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: formAllowed) ?? key
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: formAllowed) ?? value
                return "\(encodedKey)=\(encodedValue)"
            }
            .joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw KeyAuthError.server("KeyAuth respondio con un estado HTTP no valido.")
        }
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw KeyAuthError.server("KeyAuth devolvio una respuesta no valida.")
        }
    }
}
