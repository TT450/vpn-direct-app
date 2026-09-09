import Foundation
import UIKit

#if os(iOS)

/// Client for Direct product API on `bot.vpn-direct.com` (xuiweb). Never Remnawave.
@MainActor
public final class DirectBackendAPI {
    public static let shared = DirectBackendAPI()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private static let sessionTokenKey = "vpndirect.session.token"
    private static let deviceIdKey = "vpndirect.device.id"

    public private(set) var sessionToken: String? {
        didSet { UserDefaults.standard.set(sessionToken, forKey: Self.sessionTokenKey) }
    }

    public var isAuthenticated: Bool { !(sessionToken ?? "").isEmpty }

    public var deviceId: String {
        if let existing = UserDefaults.standard.string(forKey: Self.deviceIdKey), !existing.isEmpty {
            return existing
        }
        let id = (UIDevice.current.identifierForVendor ?? UUID()).uuidString
        UserDefaults.standard.set(id, forKey: Self.deviceIdKey)
        return id
    }

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 40
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
        encoder = JSONEncoder()
        sessionToken = UserDefaults.standard.string(forKey: Self.sessionTokenKey)
    }

    // MARK: - Models

    public struct Me: Codable, Equatable {
        public var authenticated: Bool?
        public var email: String?
        public var telegramId: Int?
        public var subscriptionUrl: String?
        public var subscriptionEndDate: String?
        public var hasSubscription: Bool?
        public var limitIp: Int?

        enum CodingKeys: String, CodingKey {
            case authenticated, email
            case telegramId = "telegram_id"
            case subscriptionUrl = "subscription_url"
            case subscriptionEndDate = "subscription_end_date"
            case hasSubscription = "has_subscription"
            case limitIp = "limit_ip"
        }
    }

    public struct AuthResponse: Codable {
        public let token: String?
        public let me: Me?
        public let error: String?
        public let linked: Bool?
        public let ok: Bool?
        public let sent: Bool?
    }

    public struct LocationsPayload: Codable {
        public let updatedAt: String?
        public let locations: [DirectLocationRecord]
    }

    public struct CheckoutCreateResponse: Codable {
        public let paymentId: String?
        public let method: String?
        public let payUrl: String?
        public let productHint: String?
        public let amount: Int?
        public let error: String?

        enum CodingKeys: String, CodingKey {
            case paymentId = "payment_id"
            case method
            case payUrl = "pay_url"
            case productHint = "product_hint"
            case amount, error
        }
    }

    public struct CheckoutVerifyResponse: Codable {
        public let ok: Bool?
        public let subscriptionUrl: String?
        public let subscriptionEndDate: String?
        public let me: Me?
        public let error: String?

        enum CodingKeys: String, CodingKey {
            case ok
            case subscriptionUrl = "subscription_url"
            case subscriptionEndDate = "subscription_end_date"
            case me, error
        }
    }

    public struct SubInfo: Codable {
        public let isFound: Bool?
        public let userStatus: String?
    }

    // MARK: - API

    public func registerDevice() async throws {
        struct Body: Encodable {
            let device_id: String
            let platform: String
            let created_at: String
        }
        struct Resp: Decodable { let registered: Bool?; let error: String? }
        let res: Resp = try await post(
            "/api/v1/device/register",
            body: Body(device_id: deviceId, platform: "ios", created_at: ISO8601DateFormatter().string(from: Date())),
            authed: false
        )
        if let err = res.error { throw DirectBackendError.message(err) }
    }

    public func sendEmailCode(email: String) async throws {
        struct Body: Encodable { let email: String; let device_id: String }
        let res: AuthResponse = try await post(
            "/api/v1/auth/email/send",
            body: Body(email: email, device_id: deviceId),
            authed: false
        )
        if let err = res.error { throw DirectBackendError.message(err) }
    }

    public func verifyEmailCode(email: String, code: String) async throws -> Me {
        struct Body: Encodable { let email: String; let code: String; let device_id: String }
        let res: AuthResponse = try await post(
            "/api/v1/auth/email/verify",
            body: Body(email: email, code: code, device_id: deviceId),
            authed: false
        )
        guard let token = res.token else {
            throw DirectBackendError.message(res.error ?? "Не удалось войти")
        }
        sessionToken = token
        return res.me ?? Me(authenticated: true, email: email)
    }

    public func authApple(identityToken: String, email: String?, appleUserId: String?) async throws -> Me {
        struct Body: Encodable {
            let identity_token: String
            let email: String?
            let device_id: String
            let apple_user_id: String?
        }
        let res: AuthResponse = try await post(
            "/api/v1/auth/apple",
            body: Body(
                identity_token: identityToken,
                email: email,
                device_id: deviceId,
                apple_user_id: appleUserId
            ),
            authed: false
        )
        guard let token = res.token else {
            throw DirectBackendError.message(res.error ?? "Apple Sign In не удался")
        }
        sessionToken = token
        return res.me ?? Me(authenticated: true, email: email)
    }

    public func linkBotCode(_ code: String) async throws -> Me {
        struct Body: Encodable {
            let link_token: String
            let device_id: String
        }
        let res: AuthResponse = try await post(
            "/api/v1/device/link",
            body: Body(link_token: code, device_id: deviceId),
            authed: false
        )
        guard let token = res.token else {
            throw DirectBackendError.message(res.error ?? "Неверный код привязки")
        }
        sessionToken = token
        return res.me ?? Me(authenticated: true)
    }

    public func fetchMe() async throws -> Me {
        try await get("/api/v1/me", authed: true)
    }

    public func logout() async {
        _ = try? await postEmpty("/api/v1/auth/logout", authed: true)
        sessionToken = nil
        UserDefaults.standard.set(false, forKey: "vpndirect.authenticated")
    }

    public func fetchLocations() async throws -> [DirectLocationRecord] {
        let payload: LocationsPayload = try await get("/api/v1/locations", authed: false)
        return payload.locations
    }

    public func createCheckout(
        title: String,
        price: Int,
        periodDays: Int,
        paymentMethod: PaymentMethod,
        planName: String?
    ) async throws -> CheckoutCreateResponse {
        struct Body: Encodable {
            let device_id: String
            let title: String
            let price: Int
            let period_days: Int
            let payment_method: String
            let plan_name: String?
        }
        let method = paymentMethod == .apple ? "apple" : "external"
        let res: CheckoutCreateResponse = try await post(
            "/api/v1/checkout/create",
            body: Body(
                device_id: deviceId,
                title: title,
                price: price,
                period_days: periodDays,
                payment_method: method,
                plan_name: planName
            ),
            authed: true
        )
        if let err = res.error { throw DirectBackendError.message(err) }
        return res
    }

    public func verifyCheckout(
        paymentId: String,
        periodDays: Int,
        trafficGB: Int?,
        devices: Int,
        title: String?
    ) async throws -> CheckoutVerifyResponse {
        struct Body: Encodable {
            let payment_id: String
            let device_id: String
            let period_days: Int
            let traffic_gb: Int?
            let devices: Int
            let title: String?
        }
        let res: CheckoutVerifyResponse = try await post(
            "/api/v1/checkout/verify",
            body: Body(
                payment_id: paymentId,
                device_id: deviceId,
                period_days: periodDays,
                traffic_gb: trafficGB,
                devices: devices,
                title: title
            ),
            authed: true
        )
        if let err = res.error { throw DirectBackendError.message(err) }
        return res
    }

    public func fetchSubscriptionInfo(uuid: String) async throws -> SubInfo {
        try await get("/api/sub/\(uuid)/info", authed: false)
    }

    // MARK: - HTTP

    private func url(_ path: String) -> URL {
        URL(string: DirectBackend.baseURLString + path)!
    }

    private func authorizedRequest(_ path: String, method: String, authed: Bool) throws -> URLRequest {
        var request = URLRequest(url: url(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-Id")
        if authed {
            guard let token = sessionToken, !token.isEmpty else {
                throw DirectBackendError.unauthorized
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func get<T: Decodable>(_ path: String, authed: Bool) async throws -> T {
        let request = try authorizedRequest(path, method: "GET", authed: authed)
        let (data, response) = try await session.data(for: request)
        try throwIfNeeded(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private func post<Body: Encodable, T: Decodable>(_ path: String, body: Body, authed: Bool) async throws -> T {
        var request = try authorizedRequest(path, method: "POST", authed: authed)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        let (data, response) = try await session.data(for: request)
        try throwIfNeeded(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private func postEmpty(_ path: String, authed: Bool) async throws {
        let request = try authorizedRequest(path, method: "POST", authed: authed)
        let (data, response) = try await session.data(for: request)
        try throwIfNeeded(response, data: data)
    }

    private func throwIfNeeded(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        if http.statusCode == 401 { throw DirectBackendError.unauthorized }
        if (200..<300).contains(http.statusCode) { return }
        if let obj = try? decoder.decode(AuthResponse.self, from: data), let err = obj.error {
            throw DirectBackendError.message(err)
        }
        let text = String(data: data, encoding: .utf8) ?? ""
        throw DirectBackendError.message("HTTP \(http.statusCode): \(text.prefix(160))")
    }
}

public enum DirectBackendError: LocalizedError {
    case unauthorized
    case message(String)

    public var errorDescription: String? {
        switch self {
        case .unauthorized: return "Нужна авторизация"
        case .message(let s): return s
        }
    }
}

#endif
