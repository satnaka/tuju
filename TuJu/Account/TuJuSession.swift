import AppAuth
import Combine
import Security
import UIKit

struct TuJuIdentity: Codable, Equatable {
    let issuer: String
    let subject: String
    let displayName: String
}

private struct OIDCSettings {
    let issuer: URL
    let clientID: String
    let redirect: URL

    init?(bundle: Bundle = .main) {
        let info = bundle.infoDictionary ?? [:]
        guard let value = info["TuJuOIDCIssuer"] as? String, let issuer = URL(string: value),
              issuer.scheme == "https", issuer.host != nil, issuer.query == nil, issuer.fragment == nil,
              issuer.user == nil, issuer.password == nil,
              let id = info["TuJuOIDCClientID"] as? String, !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let uri = info["TuJuOIDCRedirectURI"] as? String, let redirect = URL(string: uri),
              let scheme = redirect.scheme, scheme.contains("."),
              let types = info["CFBundleURLTypes"] as? [[String: Any]],
              types.contains(where: { ($0["CFBundleURLSchemes"] as? [String])?.contains(scheme) == true }) else { return nil }
        self.issuer = issuer
        clientID = id
        self.redirect = redirect
    }
}

private enum SignInIssue: LocalizedError {
    case unconfigured, busy, connection, invalidIdentity, unavailable, storage
    var errorDescription: String? {
        switch self {
        case .unconfigured: "Account sign-in is unavailable in this build."
        case .busy: "Another sign-in is in progress."
        case .connection: "TuJu couldn’t reach the sign-in provider. Check your connection and try again."
        case .invalidIdentity: "TuJu couldn’t verify the account returned by the sign-in provider."
        case .unavailable: "The secure sign-in window could not finish. Try again."
        case .storage: "TuJu couldn’t access the secure account storage on this device."
        }
    }
}

private struct SavedSession: Codable {
    let identity: TuJuIdentity
    let clientID: String
    let redirect: URL
    let credentials: Data
    let needsVerification: Bool
}

private enum SessionKeychain {
    private static var item: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: (Bundle.main.bundleIdentifier ?? "com.satnaka.tuju") + ".account",
         kSecAttrAccount as String: "OpenID Connect"]
    }

    static func read() throws -> SavedSession? {
        var query = item
        query[kSecReturnData as String] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw SignInIssue.storage }
        return try JSONDecoder().decode(SavedSession.self, from: data)
    }

    static func write(_ record: SavedSession) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: try JSONEncoder().encode(record),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        var status = SecItemUpdate(item as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(item.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw SignInIssue.storage }
    }

    static func delete() throws {
        let status = SecItemDelete(item as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw SignInIssue.storage }
    }
}

// UserInfo receives a bearer token. Keep it on the discovered HTTPS endpoint.
private final class UserInfoConnection: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

@MainActor
final class TuJuSession: ObservableObject {
    @Published private(set) var identity: TuJuIdentity?
    @Published private(set) var isSigningIn = false
    var isConfigured: Bool { settings != nil }
    var displayName: String? { identity?.displayName }

    private let settings = OIDCSettings()
    private var flow: OIDExternalUserAgentSession?
    private var revision = UUID()
    private var restoring = false

    init() {
        Task { await restoreIfNeeded() }
    }

    func signIn() async throws {
        guard let settings else { throw SignInIssue.unconfigured }
        guard !isSigningIn else { throw SignInIssue.busy }
        let attempt = UUID()
        revision = attempt
        isSigningIn = true
        defer { if revision == attempt { isSigningIn = false; flow = nil } }

        try await withTaskCancellationHandler {
            let service = try await discovery(settings)
            try check(attempt)
            guard let controller = Self.presentingController() else { throw SignInIssue.unavailable }
            let request = OIDAuthorizationRequest(configuration: service, clientId: settings.clientID,
                                                  clientSecret: nil, scopes: [OIDScopeOpenID, OIDScopeProfile, "offline_access"],
                                                  redirectURL: settings.redirect, responseType: OIDResponseTypeCode,
                                                  additionalParameters: nil)
            let state: OIDAuthState = try await withCheckedThrowingContinuation { continuation in
                flow = OIDAuthState.authState(byPresenting: request, presenting: controller) { state, error in
                    if let state {
                        continuation.resume(returning: state)
                    } else if let error = error as NSError?, error.domain == OIDGeneralErrorDomain,
                              [OIDErrorCode.userCanceledAuthorizationFlow.rawValue,
                               OIDErrorCode.programCanceledAuthorizationFlow.rawValue].contains(error.code) {
                        continuation.resume(throwing: CancellationError())
                    } else { continuation.resume(throwing: SignInIssue.unavailable) }
                }
            }
            try check(attempt)
            guard let rawToken = state.lastTokenResponse?.idToken, let idToken = OIDIDToken(idTokenString: rawToken),
                  idToken.issuer.absoluteString == settings.issuer.absoluteString, !idToken.subject.isEmpty,
                  idToken.audience.contains(where: { ($0 as? String) == settings.clientID }),
                  let access = state.lastTokenResponse?.accessToken else { throw SignInIssue.invalidIdentity }
            let verified = try await Self.userInfo(service, access: access, issuer: settings.issuer, subject: idToken.subject)
            try check(attempt)
            try save(state, identity: verified, settings: settings)
            identity = verified
        } onCancel: {
            Task { @MainActor [weak self] in
                if self?.revision == attempt { self?.flow?.cancel() }
            }
        }
    }

    func signOut() throws {
        try SessionKeychain.delete()
        revision = UUID()
        flow?.cancel()
        flow = nil
        isSigningIn = false
        identity = nil
    }

    func handleRedirect(_ url: URL) {
        guard let flow, let redirect = settings?.redirect,
              url.scheme == redirect.scheme, url.host == redirect.host, url.path == redirect.path else { return }
        // AppAuth checks the OAuth state before accepting a response.
        try? flow.resumeExternalUserAgentFlow(url)
    }

    func restoreIfNeeded() async {
        guard let settings, !isSigningIn, !restoring else { return }
        restoring = true
        defer { restoring = false }
        let attempt = revision
        do {
            guard let record = try SessionKeychain.read(), record.identity.issuer == settings.issuer.absoluteString,
                  record.clientID == settings.clientID, record.redirect == settings.redirect,
                  let state = try NSKeyedUnarchiver.unarchivedObject(ofClass: OIDAuthState.self, from: record.credentials),
                  state.isAuthorized else { return }
            if !record.needsVerification, let expires = state.lastTokenResponse?.accessTokenExpirationDate, expires.timeIntervalSinceNow > 60 {
                identity = record.identity
                return
            }
            guard state.refreshToken != nil || (state.lastTokenResponse?.accessTokenExpirationDate?.timeIntervalSinceNow ?? 0) > 0 else {
                try signOut()
                return
            }
            let access: String = try await withCheckedThrowingContinuation { continuation in
                state.performAction { token, _, _ in
                    if let token { continuation.resume(returning: token) }
                    else { continuation.resume(throwing: state.isAuthorized ? SignInIssue.connection : SignInIssue.invalidIdentity) }
                }
            }
            try check(attempt)
            // Persist rotating refresh tokens even if the subsequent profile request is interrupted.
            try save(state, identity: record.identity, settings: settings, needsVerification: true)
            let verified = try await Self.userInfo(state.lastAuthorizationResponse.request.configuration, access: access,
                                                   issuer: settings.issuer, subject: record.identity.subject)
            try check(attempt)
            try save(state, identity: verified, settings: settings)
            identity = verified
        } catch {
            guard revision == attempt else { return }
            identity = nil
            if case SignInIssue.invalidIdentity = error { try? SessionKeychain.delete() }
        }
    }

    private func check(_ attempt: UUID) throws {
        try Task.checkCancellation()
        guard revision == attempt else { throw CancellationError() }
    }

    private func save(_ state: OIDAuthState, identity: TuJuIdentity, settings: OIDCSettings, needsVerification: Bool = false) throws {
        let credentials = try NSKeyedArchiver.archivedData(withRootObject: state, requiringSecureCoding: true)
        try SessionKeychain.write(SavedSession(identity: identity, clientID: settings.clientID,
                                               redirect: settings.redirect, credentials: credentials, needsVerification: needsVerification))
    }

    private func discovery(_ settings: OIDCSettings) async throws -> OIDServiceConfiguration {
        let service: OIDServiceConfiguration = try await withCheckedThrowingContinuation { continuation in
            OIDAuthorizationService.discoverConfiguration(forIssuer: settings.issuer) { result, _ in
                if let result { continuation.resume(returning: result) }
                else { continuation.resume(throwing: SignInIssue.connection) }
            }
        }
        guard let doc = service.discoveryDocument, doc.issuer.absoluteString == settings.issuer.absoluteString,
              [service.authorizationEndpoint, service.tokenEndpoint, doc.userinfoEndpoint].allSatisfy({
                  $0?.scheme == "https" && $0?.host != nil && $0?.user == nil && $0?.password == nil
              }) else { throw SignInIssue.invalidIdentity }
        return service
    }

    private static func userInfo(_ service: OIDServiceConfiguration, access: String,
                                 issuer: URL, subject: String) async throws -> TuJuIdentity {
        guard let endpoint = service.discoveryDocument?.userinfoEndpoint, endpoint.scheme == "https" else { throw SignInIssue.invalidIdentity }
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 20
        request.setValue("Bearer " + access, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let session = URLSession(configuration: .ephemeral, delegate: UserInfoConnection(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode else { throw SignInIssue.connection }
        if status == 401 || status == 403 { throw SignInIssue.invalidIdentity }
        guard status == 200 else { throw SignInIssue.connection }
        struct Profile: Decodable { let sub: String; let name: String?; let preferred_username: String? }
        guard let profile = try? JSONDecoder().decode(Profile.self, from: data), profile.sub == subject else {
            throw SignInIssue.invalidIdentity
        }
        let name = [profile.name, profile.preferred_username].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? "TuJu member"
        return TuJuIdentity(issuer: issuer.absoluteString, subject: subject, displayName: name)
    }

    private static func presentingController() -> UIViewController? {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }.flatMap(\.windows)
        var controller = windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = controller?.presentedViewController { controller = presented }
        return controller
    }
}
