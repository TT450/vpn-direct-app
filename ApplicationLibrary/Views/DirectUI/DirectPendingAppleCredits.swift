import Foundation

#if os(iOS)

/// Local queue of Apple credit purchases that succeeded in StoreKit/RevenueCat
/// but may not yet be credited on the Direct ledger (kill / offline / backend blip).
public enum DirectPendingAppleCredits {
    private static let defaultsKey = "vpndirect.pending.apple.credits.v1"
    private static let creditedKey = "vpndirect.credited.apple.tx.v1"

    public struct Record: Codable, Equatable, Identifiable {
        public var id: String { transactionID }
        public let productID: String
        public let transactionID: String
        public let appUserID: String
        public let purchasedAt: Date
        public var lastError: String?

        public init(
            productID: String,
            transactionID: String,
            appUserID: String,
            purchasedAt: Date = Date(),
            lastError: String? = nil
        ) {
            self.productID = productID
            self.transactionID = transactionID
            self.appUserID = appUserID
            self.purchasedAt = purchasedAt
            self.lastError = lastError
        }
    }

    public static func all() -> [Record] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let rows = try? JSONDecoder().decode([Record].self, from: data) else {
            return []
        }
        return rows
    }

    public static func enqueue(_ record: Record) {
        if isCredited(transactionID: record.transactionID) { return }
        var rows = all().filter { $0.transactionID != record.transactionID }
        rows.append(record)
        save(rows)
    }

    public static func updateError(transactionID: String, message: String?) {
        var rows = all()
        guard let idx = rows.firstIndex(where: { $0.transactionID == transactionID }) else { return }
        rows[idx].lastError = message
        save(rows)
    }

    public static func remove(transactionID: String) {
        save(all().filter { $0.transactionID != transactionID })
        markCredited(transactionID: transactionID)
    }

    public static var hasPending: Bool { !all().isEmpty }

    public static func isCredited(transactionID: String) -> Bool {
        creditedIDs().contains(transactionID)
    }

    public static func markCredited(transactionID: String) {
        var ids = creditedIDs()
        guard !ids.contains(transactionID) else { return }
        ids.append(transactionID)
        // Cap growth — keep newest ~200.
        if ids.count > 200 {
            ids = Array(ids.suffix(200))
        }
        UserDefaults.standard.set(ids, forKey: creditedKey)
    }

    private static func creditedIDs() -> [String] {
        UserDefaults.standard.stringArray(forKey: creditedKey) ?? []
    }

    private static func save(_ rows: [Record]) {
        if let data = try? JSONEncoder().encode(rows) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}

#endif
