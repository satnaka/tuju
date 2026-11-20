import SwiftUI
import UIKit

struct TuJuRewardsView: View {
    var body: some View { AccountSheet { AccountRewardsOverview() } }
}

private struct AccountLedgerReader<Content: View>: View {
    @AppStorage(TuJuRewardsLedger.storageKey) private var data = Data()
    @ViewBuilder let content: (TuJuRewardsLedger) -> Content

    var body: some View {
        if let ledger = TuJuRewardsLedger.decode(data) {
            content(ledger)
        } else {
            ContentUnavailableView("Rewards unavailable", systemImage: "exclamationmark.circle",
                                   description: Text("The rewards saved on this device could not be read."))
        }
    }
}

private struct RewardsBalance: View {
    var balance: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AVAILABLE TO REDEEM").font(.caption2.weight(.semibold))
            Text("\(balance) points").font(.title.bold()).foregroundStyle(AccountPalette.blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(18)
        .background(Color(red: 0.89, green: 0.95, blue: 1), in: RoundedRectangle(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(.white) }
    }
}

struct AccountRewardsOverview: View {
    private let tiers = ["Explorer", "Navigator", "Trailblazer"]
    var body: some View {
        AccountLedgerReader { ledger in
            AccountPage(title: "TuJu Rewards", subtitle: "Earn points on the road and redeem them for rewards.") {
                RewardsBalance(balance: ledger.balance)
                AccountCard {
                    Text("Rewards tiers").font(.headline)
                    ForEach(tiers, id: \.self) { tier in
                        NavigationLink {
                            AccountTier(tier: tier, ledger: ledger)
                        } label: {
                            HStack(spacing: 9) {
                                Image("Account" + tier).resizable().scaledToFit()
                                    .frame(width: tier == "Explorer" ? 44 : 32, height: tier == "Explorer" ? 44 : 32)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(tier).font(.headline)
                                    Text(tier == "Explorer" ? "Current tier · \(ledger.xp) / 2,000 Journey XP" : tier == "Navigator" ? "Early access to selected rewards" : "Exclusive rewards and priority access")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption.bold())
                            }
                            .frame(minHeight: 36)
                        }.buttonStyle(.plain)
                        if tier == "Explorer" {
                            ProgressView(value: Double(min(ledger.xp, 2_000)), total: 2_000)
                            Text("\(max(0, 2_000 - ledger.xp)) XP to the Navigator milestone").font(.caption)
                        }
                        if tier != "Trailblazer" { Divider() }
                    }
                }
                NavigationLink { RewardsCatalogue() } label: { AccountAction(title: "Explore rewards") }
                NavigationLink { MyVouchers() } label: { AccountAction(title: "My rewards", prominent: false) }
                AccountCard {
                    NavigationLink { EarningPoints() } label: { AccountRowLabel(title: "How to earn points") }
                    Divider()
                    NavigationLink { PointsHistory() } label: { AccountRowLabel(title: "Points history") }
                    Divider()
                    NavigationLink { AccountAchievements() } label: { AccountRowLabel(title: "Achievements") }
                }
            }
        }
    }
}

private struct AccountTier: View {
    var tier: String
    var ledger: TuJuRewardsLedger
    var body: some View {
        AccountPage(title: tier, subtitle: tier == "Explorer" ? "Your current rewards tier" : "Rewards tier preview") {
            AccountCard {
                HStack {
                    Image("Account" + tier).resizable().scaledToFit().frame(width: 52, height: 52)
                    Text(tier).font(.title2.bold())
                }
                if tier == "Explorer" {
                    Text("Explore the rewards catalogue and use your points for vouchers.")
                } else {
                    Text(tier == "Navigator" ? "Early access to selected rewards" : "Exclusive rewards and priority access")
                    Text("Journey XP milestone").font(.headline)
                    let target = tier == "Navigator" ? 2_000 : 5_000
                    ProgressView(value: Double(min(ledger.xp, target)), total: Double(target))
                    Text("\(ledger.xp) / \(target) Journey XP").font(.subheadline)
                }
            }
        }
    }
}

private struct RewardsCatalogue: View {
    var body: some View {
        AccountLedgerReader { ledger in
            AccountPage(title: "Rewards catalogue", subtitle: "Use your points to redeem vouchers.") {
                HStack {
                    Text("\(ledger.balance) points").font(.headline)
                    Spacer()
                    NavigationLink("My rewards  ›") { MyVouchers() }
                }
                ForEach(TuJuReward.allCases) { reward in
                    AccountCard {
                        RewardHeading(reward: reward)
                        Label("\(reward.cost) points", systemImage: "circle.fill").font(.caption.weight(.semibold))
                        NavigationLink {
                            RewardDetails(reward: reward)
                        } label: { AccountAction(title: "View reward", prominent: ledger.balance >= reward.cost) }
                    }
                }
                Text("Concept catalogue · Demo vouchers can only be used in TuJu.").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

private struct RewardHeading: View {
    var reward: TuJuReward
    var body: some View {
        HStack(spacing: 12) {
            if reward == .latte { Image("AccountCoffee").resizable().scaledToFit().frame(width: 58, height: 58) }
            VStack(alignment: .leading, spacing: 5) {
                Text(reward.title).font(.headline)
                Text(reward.summary).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

private struct RewardDetails: View {
    var reward: TuJuReward
    var body: some View {
        AccountLedgerReader { ledger in
            AccountPage(title: "Reward details", subtitle: reward == .latte ? "ZUS Coffee · Drink voucher" : "R&R · Meal voucher") {
                AccountCard {
                    RewardHeading(reward: reward)
                    Text("\(reward.cost) points").font(.headline)
                    Divider()
                    Text("Voucher terms").font(.headline)
                    Text("Valid for 30 days after redemption. Single use only. This concept voucher has no cash or merchant value.")
                        .font(.subheadline)
                }
                if ledger.balance >= reward.cost {
                    NavigationLink { ConfirmReward(reward: reward) } label: { AccountAction(title: "Redeem reward") }
                    Text("You’ll review the points cost before you confirm.").font(.footnote)
                } else {
                    AccountCard {
                        Text("Not enough points").font(.headline)
                        Text("You need \(reward.cost - ledger.balance) more points to redeem this reward.")
                        NavigationLink("How to earn points  ›") { EarningPoints() }
                    }
                }
            }
        }
    }
}

private struct ConfirmReward: View {
    let reward: TuJuReward
    @State private var transactionID = UUID()
    @State private var error = false
    var body: some View {
        AccountLedgerReader { ledger in
            if let voucher = ledger.vouchers.first(where: { $0.id == transactionID }) {
                AccountPage(title: "Reward redeemed", subtitle: "Your demo voucher is now in My rewards.") {
                    AccountCard {
                        RewardHeading(reward: reward)
                        Text("\(reward.cost) points spent").font(.subheadline)
                        Text("Valid until \(voucher.expiry.formatted(date: .abbreviated, time: .omitted)).").font(.subheadline)
                    }
                    RewardsBalance(balance: ledger.balance)
                    NavigationLink { VoucherDetails(id: voucher.id) } label: { AccountAction(title: "View voucher") }
                    NavigationLink { MyVouchers() } label: { AccountAction(title: "My rewards", prominent: false) }
                }
            } else {
                AccountPage(title: "Confirm redemption", subtitle: "Review your reward before exchanging points.") {
                    AccountCard {
                        RewardHeading(reward: reward)
                        Divider()
                        LabeledContent("Available points", value: "\(ledger.balance)")
                        LabeledContent("Reward cost", value: "\(reward.cost)")
                        LabeledContent("Points remaining", value: "\(max(0, ledger.balance - reward.cost))")
                    }
                    Button {
                        error = !TuJuRewardsLedger.redeem(reward, id: transactionID)
                    } label: { AccountAction(title: "Confirm redemption") }
                    .disabled(ledger.balance < reward.cost)
                    Text("Demo redemption · Stored on this device.").font(.footnote)
                    if error { Text("The redemption could not be saved. Check your balance and try again.").foregroundStyle(.red) }
                }
            }
        }
    }
}

private struct MyVouchers: View {
    @State private var status = VoucherStatus.active
    var body: some View {
        AccountLedgerReader { ledger in
            AccountPage(title: "My rewards", subtitle: "Find and manage your vouchers.") {
                Picker("Voucher status", selection: $status) {
                    ForEach(VoucherStatus.allCases) { status in Text(status.rawValue).tag(status) }
                }.pickerStyle(.segmented)
                let filtered = ledger.vouchers.reversed().filter { $0.status == status }
                if filtered.isEmpty {
                    AccountCard {
                        Text("No \(status.rawValue.lowercased()) vouchers").font(.headline)
                        Text(status == .active ? "Redeem a reward to get a voucher. You’ll find it here when it’s ready to use." : "Vouchers appear here when their status changes.").font(.subheadline)
                        if status == .active {
                            NavigationLink { RewardsCatalogue() } label: { AccountAction(title: "Explore rewards") }
                        }
                    }
                }
                ForEach(filtered) { voucher in
                    AccountCard {
                        NavigationLink { VoucherDetails(id: voucher.id) } label: {
                            HStack {
                                RewardHeading(reward: voucher.reward)
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                        }
                    }
                }
                RewardsBalance(balance: ledger.balance)
            }
        }
    }
}

private struct VoucherDetails: View {
    var id: UUID
    @State private var confirming = false
    @State private var copied = false
    var body: some View {
        AccountLedgerReader { ledger in
            if let voucher = ledger.vouchers.first(where: { $0.id == id }) {
                AccountPage(title: "Your voucher", subtitle: "A TuJu concept voucher for use in this app.") {
                    AccountCard {
                        RewardHeading(reward: voucher.reward)
                        Text(voucher.status == .active ? "Ready to use" : voucher.status.rawValue).font(.headline)
                        Divider()
                        Text("VOUCHER CODE").font(.caption2.bold())
                        Text(voucher.code).font(.title2.monospaced().bold()).textSelection(.enabled)
                        Text("Valid until \(voucher.expiry.formatted(date: .abbreviated, time: .omitted)) · One use only").font(.caption)
                    }
                    if voucher.status == .active {
                        Button {
                            UIPasteboard.general.string = voucher.code
                            copied = true
                        } label: { AccountAction(title: copied ? "Code copied" : "Copy demo code", prominent: false) }
                        Button { confirming = true } label: { AccountAction(title: "Mark as used") }
                    }
                }
                .confirmationDialog("Mark this voucher as used?", isPresented: $confirming, titleVisibility: .visible) {
                    Button("Mark as used") { _ = TuJuRewardsLedger.markUsed(id: id) }
                    Button("Cancel", role: .cancel) {}
                } message: { Text("The voucher will move to Used.") }
            }
        }
    }
}

struct AccountAchievements: View {
    var body: some View {
        AccountLedgerReader { ledger in
            AccountPage(title: "Your achievements", subtitle: "See your level progress and the badges you’ve earned.") {
                AccountCard {
                    HStack {
                        Image("AccountExplorer").resizable().scaledToFit().frame(width: 44, height: 44)
                        VStack(alignment: .leading) {
                            Text("Explorer").font(.headline)
                            Text("\(ledger.xp) / 2,000 Journey XP").font(.caption)
                        }
                    }
                    ProgressView(value: Double(min(ledger.xp, 2_000)), total: 2_000)
                    Text("Next tier: Navigator").font(.caption)
                }
                AccountCard {
                    Label("First journey", systemImage: "medal.fill").font(.headline)
                    Text("Unlocked · Complete your first TuJu journey.").font(.subheadline)
                }
                AccountCard {
                    Label("The regular traveller", systemImage: "car.fill").font(.headline)
                    Text(ledger.completedCount >= 10 ? "Unlocked · Completed 10 journeys." : "\(ledger.completedCount) / 10 journeys completed").font(.subheadline)
                    ProgressView(value: Double(min(ledger.completedCount, 10)), total: 10)
                }
            }
        }
    }
}

private struct EarningPoints: View {
    var body: some View {
        AccountPage(title: "How to earn points", subtitle: "Use points for rewards. Journey XP counts towards your level.") {
            AccountCard {
                Label("Complete a journey", systemImage: "car.fill").font(.headline)
                Text("+20 points · +20 Journey XP").font(.subheadline.bold())
                Text("Complete a TuJu journey to add points to your local account. Ending a trip early earns no points.").font(.subheadline)
            }
            AccountCard {
                Text("Sample account").font(.headline)
                Text("You start with 350 demo points and 120 Journey XP. Vouchers and points activity are saved on this device.").font(.subheadline)
            }
            NavigationLink { PointsHistory() } label: { AccountAction(title: "Points history", prominent: false) }
        }
    }
}

private struct PointsHistory: View {
    struct Entry: Identifiable {
        let id: UUID
        let title: String
        let detail: String
        let date: Date
        let amount: Int
    }
    var body: some View {
        AccountLedgerReader { ledger in
            AccountPage(title: "Points history", subtitle: "Track the points you’ve earned and spent.") {
                RewardsBalance(balance: ledger.balance)
                AccountCard {
                    ForEach(entries(ledger)) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.title).font(.headline)
                                Text(entry.detail).font(.caption)
                                Text(entry.date.formatted(date: .abbreviated, time: .omitted)).font(.caption2)
                            }
                            Spacer()
                            Text(entry.amount.formatted(.number.sign(strategy: .always()))).font(.headline.monospacedDigit())
                        }
                        Divider()
                    }
                    LabeledContent("Opening balance", value: "+350").font(.headline)
                    Text("TuJu sample account").font(.caption)
                }
            }
        }
    }
    private func entries(_ ledger: TuJuRewardsLedger) -> [Entry] {
        let earned = ledger.journeys.map { Entry(id: $0.id, title: "Journey completed", detail: $0.destination, date: $0.date, amount: 20) }
        let spent = ledger.vouchers.map { Entry(id: $0.id, title: "Reward redeemed", detail: $0.reward.title, date: $0.issued, amount: -$0.reward.cost) }
        return (earned + spent).sorted { $0.date > $1.date }
    }
}
