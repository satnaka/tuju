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
    var body: some View {
        AccountLedgerReader { ledger in
            AccountPage(title: "TuJu Rewards", subtitle: "A little progress with every journey", centered: true) {
                VStack(spacing: 10) {
                    Text("YOUR TIER PROGRESS").font(.caption2.weight(.semibold))
                    HStack {
                        NavigationLink { AccountTier(tier: ledger.tierName, ledger: ledger) } label: { tierBadge(ledger.tierName, upcoming: false) }
                        VStack(spacing: 6) {
                            let target = ledger.nextTier?.xp ?? 5_000
                            Text("\(ledger.xp.formatted()) / \(target.formatted()) XP").font(.subheadline.bold())
                            ProgressView(value: Double(min(ledger.xp, target)), total: Double(target)).tint(.mint)
                            Text("\(min(100, ledger.xp * 100 / target))% complete").font(.caption)
                        }
                        if let next = ledger.nextTier {
                            NavigationLink { AccountTier(tier: next.name, ledger: ledger) } label: { tierBadge(next.name, upcoming: true) }
                        }
                    }
                    Text(milestoneSummary(ledger)).font(.caption.weight(.semibold))
                }
                .frame(maxWidth: .infinity).padding(16).foregroundStyle(.white)
                .background(AccountPalette.blue, in: RoundedRectangle(cornerRadius: 23))
                HStack(spacing: 10) {
                    metric(ledger.balance.formatted(), "Available points")
                    metric("\(ledger.unlockedMilestones.count) / \(TuJuMilestone.allCases.count)", "Badges unlocked")
                }
                AccountCard {
                    VStack(spacing: 10) {
                        Text("Make your next move").font(.title3.weight(.semibold))
                        Text(milestoneSummary(ledger)).font(.subheadline).foregroundStyle(.secondary)
                        NavigationLink { AccountAchievements(backTitle: "Back to Rewards") } label: { AccountAction(title: "View achievements", prominent: false) }
                    }.frame(maxWidth: .infinity)
                }
                NavigationLink { RewardsCatalogue() } label: { AccountAction(title: "Explore rewards") }
                AccountCard {
                    NavigationLink {
                        AccountPage(title: "Rewards tiers", subtitle: "Journey XP milestones", centered: true) {
                            AccountCard {
                                ForEach(["Explorer", "Navigator", "Trailblazer"], id: \.self) { name in
                                    NavigationLink { AccountTier(tier: name, ledger: ledger) } label: {
                                        AccountRowLabel(title: name, detail: name == ledger.tierName ? "Current tier" : "", art: "Account" + name)
                                    }
                                }
                            }
                        }
                    } label: { AccountRowLabel(title: "Rewards tiers") }
                    Divider()
                    NavigationLink { MyVouchers() } label: { AccountRowLabel(title: "My rewards") }
                    Divider()
                    NavigationLink { EarningPoints() } label: { AccountRowLabel(title: "How to earn points") }
                    Divider()
                    NavigationLink { PointsHistory() } label: { AccountRowLabel(title: "Points history") }
                }
            }
        }
    }

    private func tierBadge(_ name: String, upcoming: Bool) -> some View {
        VStack(spacing: 4) {
            Image("HomeTrophy").resizable().scaledToFit().frame(width: 64, height: 64).accessibilityHidden(true)
            Text(name).font(.caption.weight(.semibold))
        }.opacity(upcoming ? 0.6 : 1)
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(spacing: 8) {
            Text(value).font(.title2.weight(.semibold))
            Text(label).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).padding(.vertical, 16).heroGlass(.card)
        .accessibilityElement(children: .combine)
    }

    private func milestoneSummary(_ ledger: TuJuRewardsLedger) -> String {
        guard let next = ledger.nextTier else { return "Trailblazer tier reached" }
        return "\((next.xp - ledger.xp).formatted()) XP to the \(next.name) milestone"
    }
}

private struct AccountTier: View {
    var tier: String
    var ledger: TuJuRewardsLedger
    var body: some View {
        AccountPage(title: tier, subtitle: tier == ledger.tierName ? "Your current rewards tier" : "Rewards tier preview") {
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
    private enum Filter: String, CaseIterable { case forYou = "For you", all = "All rewards", mine = "My rewards" }
    @State private var filter = Filter.forYou
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        AccountLedgerReader { ledger in
            AccountPage(title: "Rewards catalogue", subtitle: "Explore offers", centered: true) {
                Picker("Reward filters", selection: $filter) {
                    ForEach(Filter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)
                if filter == .mine {
                    VoucherCollection(ledger: ledger) {
                        Button { filter = .forYou } label: { AccountAction(title: "Explore rewards") }
                    }
                } else {
                    let affordable = TuJuReward.allCases.filter { $0.cost <= ledger.balance }
                    let offers = filter == .all ? TuJuReward.allCases : affordable
                    ForEach(offers) { reward in
                        AccountCard {
                            HStack(spacing: 12) {
                                if reward == .latte {
                                    Image("RewardLatte").resizable().scaledToFit()
                                        .frame(width: 91, height: 91).accessibilityHidden(true)
                                }
                                VStack(spacing: 6) {
                                    Text(reward.title).font(.title3.weight(.semibold))
                                    Text(reward.summary).font(.caption).foregroundStyle(.secondary)
                                    Text("\(reward.cost) points").font(.title3.weight(.semibold)).foregroundStyle(AccountPalette.blue)
                                }
                                .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                            }
                            NavigationLink { RewardDetails(reward: reward) } label: {
                                AccountAction(title: "View reward", prominent: ledger.balance >= reward.cost)
                            }
                        }
                    }
                    if filter == .forYou, let next = TuJuReward.allCases.filter({ $0.cost > ledger.balance }).min(by: { $0.cost < $1.cost }) {
                        AccountCard {
                            VStack(spacing: 10) {
                                Text("A little extra for your journey").font(.headline)
                                Text("\(next.cost) points").font(.headline).foregroundStyle(.orange)
                                Text("You need \(next.cost - ledger.balance) more points.").font(.subheadline).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity)
                        }
                    }
                }
                Button { dismiss() } label: { AccountAction(title: "Back to Rewards", prominent: false) }
                Text("Concept catalogue · Demo vouchers can only be used in TuJu.").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

private struct RewardHeading: View {
    var reward: TuJuReward
    var body: some View {
        HStack(spacing: 12) {
            if reward == .latte { Image("RewardLatte").resizable().scaledToFit().frame(width: 58, height: 58) }
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
    var body: some View {
        AccountLedgerReader { ledger in
            AccountPage(title: "My rewards", subtitle: "Find and manage your vouchers.") {
                VoucherCollection(ledger: ledger) {
                    NavigationLink { RewardsCatalogue() } label: { AccountAction(title: "Explore rewards") }
                }
            }
        }
    }
}

private struct VoucherCollection<Explore: View>: View {
    let ledger: TuJuRewardsLedger
    @ViewBuilder let explore: Explore
    @State private var status = VoucherStatus.active

    var body: some View {
        Picker("Voucher status", selection: $status) {
            ForEach(VoucherStatus.allCases) { status in Text(status.rawValue).tag(status) }
        }.pickerStyle(.segmented)
        let filtered = ledger.vouchers.reversed().filter { $0.status == status }
        if filtered.isEmpty {
            AccountCard {
                Text("No \(status.rawValue.lowercased()) vouchers").font(.headline)
                Text(status == .active ? "Redeem a reward to get a voucher. You’ll find it here when it’s ready to use." : "Vouchers appear here when their status changes.").font(.subheadline)
                if status == .active {
                    explore
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
    var backTitle = "Back"
    @State private var selectedMilestone: TuJuMilestone?

    @AppStorage("tuju.displayName") private var localName = ""
    @EnvironmentObject private var session: TuJuSession
    @Environment(\.dismiss) private var dismiss
    @State private var showChallenges = false
    @Environment(\.dynamicTypeSize) private var typeSize
    private var displayName: String { session.displayName ?? (localName.isEmpty ? "Guest" : localName) }

    var body: some View {
        AccountLedgerReader { ledger in
            AccountPage(title: "Your achievements", subtitle: "Small milestones along the way", centered: true) {
                AccountCard {
                    HStack {
                        Text(String(displayName.prefix(1)).uppercased()).font(.headline).foregroundStyle(AccountPalette.blue)
                            .frame(width: 48, height: 48).background(.blue.opacity(0.08), in: Circle())
                        VStack(spacing: 4) {
                            Text(displayName).font(.title3.weight(.semibold))
                            Text(ledger.tierName + " · " + ledger.achievementSummary).font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity)
                    }
                }
                Picker("Badge collection", selection: $showChallenges) {
                    Text("Challenges").tag(true)
                    Text("Achievements").tag(false)
                }.pickerStyle(.segmented)
                if showChallenges {
                    AccountCard {
                        ForEach(TuJuMilestone.allCases) { milestone in
                            if milestone != .firstJourney { Divider() }
                            Label {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(milestone.rawValue).font(.headline)
                                    Text(milestone.challenge).font(.subheadline).foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: milestone.isUnlocked(in: ledger) ? "checkmark.circle.fill" : "circle")
                            }
                        }
                    }
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9),
                                             count: typeSize.isAccessibilitySize ? 2 : 3), spacing: 12) {
                        ForEach(TuJuMilestone.allCases) { milestone in
                            let earned = milestone.isUnlocked(in: ledger)
                            if earned {
                                Button { selectedMilestone = milestone } label: {
                                    badgeTile(milestone, earned: true)
                                }.buttonStyle(.plain)
                            } else {
                                badgeTile(milestone, earned: false).accessibilityElement(children: .combine)
                            }
                        }
                    }
                }
                Button { dismiss() } label: { AccountAction(title: backTitle, prominent: false) }
            }
            .fullScreenCover(item: $selectedMilestone) { milestone in
                MilestoneUnlocked(milestone: milestone, ledger: ledger)
            }
        }
    }

    private func badgeTile(_ milestone: TuJuMilestone, earned: Bool) -> some View {
        VStack(spacing: 5) {
            Image(earned ? "HomeTrophy" : "AchievementLocked").resizable().scaledToFit()
                .frame(maxWidth: 96).opacity(earned ? 1 : 0.25).accessibilityHidden(true)
            Text(milestone.rawValue).font(.caption.weight(.semibold))
            Text(earned ? "Unlocked" : "Locked").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10).heroGlass(.card)
    }
}

private struct MilestoneUnlocked: View {
    let milestone: TuJuMilestone
    let ledger: TuJuRewardsLedger
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("TUJU ACHIEVEMENTS").font(.footnote.weight(.semibold))
                Image("HomeTrophy").resizable().scaledToFit()
                    .frame(width: 228, height: 228).accessibilityHidden(true)
                Text("Milestone unlocked!").font(.title.weight(.semibold)).accessibilityAddTraits(.isHeader)
                Text(milestone == .firstJourney ? "Your first journey is just the beginning." : milestone.challenge).font(.body.weight(.semibold))
                VStack(spacing: 11) {
                    Text(milestone.rawValue.uppercased()).font(.subheadline.weight(.semibold))
                    Text(ledger.achievementSummary)
                        .font(.title2.weight(.semibold))
                    Text("\(ledger.tierName) tier").font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 20)
                .foregroundStyle(AccountPalette.ink)
                .background(.white.opacity(reduceTransparency ? 1 : 0.72), in: RoundedRectangle(cornerRadius: 22))
                .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.8), lineWidth: 1) }
                Button { dismiss() } label: {
                    Text("Back to achievements").font(.body.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .heroGlass(.control, radius: 24)
                }
                .foregroundStyle(AccountPalette.ink)
                .buttonStyle(HeroUIGlassButtonStyle())
                .padding(.horizontal, 21)
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 26)
            .frame(maxWidth: .infinity)
        }
        .multilineTextAlignment(.center).foregroundStyle(.white)
        .background(Color(red: 0.031, green: 0.459, blue: 0.949).ignoresSafeArea())
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
