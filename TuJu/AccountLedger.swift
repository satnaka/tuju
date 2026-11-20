import Foundation

enum TuJuReward: String, Codable, CaseIterable, Identifiable {
    case latte, meal
    var id: Self { self }
    var title: String { self == .latte ? "ZUS Coffee Latte" : "RM5 R&R meal voucher" }
    var summary: String { self == .latte ? "1× Latte · Hot or iced" : "RM5 off at participating R&R food outlets." }
    var cost: Int { self == .latte ? 200 : 500 }
}

struct TuJuVoucher: Codable, Identifiable {
    let id: UUID
    let reward: TuJuReward
    let issued: Date
    let expiry: Date
    var used: Date?

    var code: String { "DEMO-" + id.uuidString.prefix(8) }
    var status: VoucherStatus {
        if used != nil { return .used }
        return expiry <= Date() ? .expired : .active
    }
}

enum VoucherStatus: String, CaseIterable, Identifiable {
    case active = "Active", used = "Used", expired = "Expired"
    var id: Self { self }
}

struct TuJuCompletedJourney: Codable, Identifiable {
    let id: UUID
    let destination: String
    let date: Date
}

struct TuJuRewardsLedger: Codable {
    static let storageKey = "tuju.rewardLedger.v1"
    var vouchers: [TuJuVoucher] = []
    var journeys: [TuJuCompletedJourney] = []

    var balance: Int { 350 + 20 * journeys.count - vouchers.reduce(0) { $0 + $1.reward.cost } }
    var xp: Int { 120 + 20 * journeys.count }
    var completedCount: Int { 6 + journeys.count }

    static func decode(_ data: Data?) -> Self? {
        guard let data, !data.isEmpty else { return Self() }
        return try? JSONDecoder().decode(Self.self, from: data)
    }

    @MainActor
    private static func update(_ change: (inout Self) -> Bool) -> Bool {
        guard var ledger = decode(UserDefaults.standard.data(forKey: storageKey)),
              change(&ledger), let data = try? JSONEncoder().encode(ledger) else { return false }
        UserDefaults.standard.set(data, forKey: storageKey)
        return true
    }

    @MainActor
    static func creditCompletedJourney(id: UUID, destination: String) {
        _ = update { ledger in
            guard !ledger.journeys.contains(where: { $0.id == id }) else { return false }
            ledger.journeys.append(TuJuCompletedJourney(id: id, destination: destination, date: .now))
            return true
        }
    }

    @MainActor
    static func redeem(_ reward: TuJuReward, id: UUID) -> Bool {
        update { ledger in
            guard ledger.balance >= reward.cost, !ledger.vouchers.contains(where: { $0.id == id }) else { return false }
            let now = Date()
            guard let expiry = Calendar.current.date(byAdding: .day, value: 30, to: now) else { return false }
            ledger.vouchers.append(TuJuVoucher(id: id, reward: reward, issued: now, expiry: expiry))
            return true
        }
    }

    @MainActor
    static func markUsed(id: UUID) -> Bool {
        update { ledger in
            guard let i = ledger.vouchers.firstIndex(where: { $0.id == id && $0.status == .active }) else { return false }
            ledger.vouchers[i].used = .now
            return true
        }
    }
}
