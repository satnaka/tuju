import AVFoundation
import SwiftUI

enum AccountPalette {
    static let ink = Color(red: 0.06, green: 0.19, blue: 0.38)
    static let blue = Color(red: 0.025, green: 0.39, blue: 0.72)
    static let mist = Color(red: 0.90, green: 0.97, blue: 0.99)
    static let paper = Color(red: 0.965, green: 0.984, blue: 0.992)
}

struct AccountPage<Content: View>: View {
    let title: String
    let subtitle: String
    var centered = false
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 13) {
                VStack(alignment: centered ? .center : .leading, spacing: 8) {
                    Text(title).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                    Text(subtitle).font(.subheadline).foregroundStyle(AccountPalette.ink.opacity(0.75))
                }
                .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
                .multilineTextAlignment(centered ? .center : .leading)
                content
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 32)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .background(LinearGradient(colors: [AccountPalette.mist, AccountPalette.paper, AccountPalette.paper], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .foregroundStyle(AccountPalette.ink)
        .tint(AccountPalette.blue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

struct AccountCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 23))
            .overlay { RoundedRectangle(cornerRadius: 23).stroke(.white, lineWidth: 1) }
            .shadow(color: AccountPalette.ink.opacity(0.046), radius: 8, y: 4)
    }
}

struct AccountRowLabel: View {
    var title: String
    var detail = ""
    var art: String? = nil
    var body: some View {
        HStack(spacing: 12) {
            if let art { Image(art).resizable().scaledToFit().frame(width: 22, height: 22).accessibilityHidden(true) }
            Text(title).font(.subheadline.weight(.medium))
            Spacer()
            if !detail.isEmpty { Text(detail).font(.caption).foregroundStyle(.secondary) }
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.secondary)
        }
        .frame(minHeight: 36).contentShape(Rectangle())
    }
}

struct AccountAction: View {
    let title: String
    var prominent = true
    var body: some View {
        Text(title).font(.headline).padding(.horizontal).padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .foregroundStyle(prominent ? Color.white : AccountPalette.blue)
            .background(prominent ? AccountPalette.blue : Color.white.opacity(0.9), in: Capsule())
    }
}

struct AccountSheet<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    @ViewBuilder var content: Content
    var body: some View {
        NavigationStack {
            content.toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .preferredColorScheme(.light)
        .tint(AccountPalette.blue)
    }
}

struct TuJuProfileView: View {
    @AppStorage("tuju.displayName") private var name = "Amir"
    @AppStorage(TuJuRewardsLedger.storageKey) private var data = Data()
    @AppStorage("tuju.profileSignedIn") private var signedIn = true
    @State private var confirmLogout = false
    @State private var editing = false
    @State private var draftName = ""
    private var ledger: TuJuRewardsLedger? { TuJuRewardsLedger.decode(data) }
    var body: some View {
        AccountSheet {
            if signedIn {
                profile
            } else {
                AccountPage(title: "Profile", subtitle: "Your journeys, preferences and rewards", centered: true) {
                    AccountCard {
                        Text("Local demo profile").font(.headline)
                        Text("Continue with your saved profile to see your rewards and preferences.").font(.subheadline)
                    }
                    Button { signedIn = true } label: { AccountAction(title: "Continue as " + name) }
                }
            }
        }
        .confirmationDialog("Log out of this demo profile?", isPresented: $confirmLogout, titleVisibility: .visible) {
            Button("Log out", role: .destructive) { signedIn = false }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Your rewards and preferences stay on this device.") }
        .alert("Edit profile name", isPresented: $editing) {
            TextField("Name", text: $draftName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                name = String(draftName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(48))
            }.disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var profile: some View {
        AccountPage(title: "Profile", subtitle: "Your journeys, preferences and rewards", centered: true) {
            Button {
                draftName = name
                editing = true
            } label: {
                AccountCard {
                    HStack(spacing: 14) {
                        Text(String(name.prefix(1)).uppercased()).font(.title3.bold())
                            .frame(width: 48, height: 48).background(AccountPalette.mist, in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(name).font(.title3.bold())
                            Text("Explorer · " + badgeSummary).font(.caption)

                        }
                        Spacer()
                        Image(systemName: "pencil").font(.caption)
                    }
                }
            }
            .buttonStyle(.plain).accessibilityLabel("Edit profile name, " + name)
            NavigationLink {
                AccountRewardsOverview()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("TuJu Rewards").font(.headline)
                        if let ledger {
                            Text("\(ledger.balance) points").font(.title.bold())
                            Text("Explorer · \(ledger.xp) Journey XP").font(.caption)
                        }
                        Text("View rewards  ›").font(.caption.weight(.semibold))
                    }
                    Spacer()
                    Image("AccountTrophy").resizable().scaledToFit().frame(width: 80, height: 80)
                }
                .padding(16).foregroundStyle(.white)
                .background(LinearGradient(colors: [Color(red: 0.1, green: 0.58, blue: 0.98), AccountPalette.blue, Color(red: 0.03, green: 0.29, blue: 0.82)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 24))
            }
            .buttonStyle(.plain)
            AccountCard {
                NavigationLink { AccountAchievements() } label: {
                    AccountRowLabel(title: "Your achievements", detail: (ledger?.completedCount ?? 0) >= 10 ? "2 badges" : "1 badge", art: "AccountAward")
                }
            }
            Text("NAVIGATION & PREFERENCES").font(.caption.weight(.semibold))
            AccountCard {
                NavigationLink { AccountSettings() } label: {
                    AccountRowLabel(title: "Navigation settings", art: "AccountSettings")
                }
                NavigationLink { AccountVoiceSettings() } label: {
                    AccountRowLabel(title: "Voice guidance", art: "AccountVoice")
                }
                NavigationLink { AccountMapSettings() } label: {
                    AccountRowLabel(title: "Map appearance", art: "AccountMap")
                }
            }
            Button("Log out", role: .destructive) { confirmLogout = true }
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(.white, in: Capsule()).padding(.top, 24)
        }
    }

    private var badgeSummary: String {
        (ledger?.completedCount ?? 0) >= 10 ? "2 achievements unlocked" : "1 achievement unlocked"
    }
}

private struct AccountSettings: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("tuju.showSpeedLimit") private var showSpeedLimit = true
    @AppStorage("tuju.showRoadNames") private var showRoadNames = true
    @AppStorage("tuju.simpleMode") private var simple = false
    @AppStorage("tuju.mapStyle") private var style = "Daylight"
    @AppStorage("tuju.mapTheme") private var theme = "TuJu Blue"
    @AppStorage("tuju.voiceLanguage") private var language = "ms-MY"
    @AppStorage("tuju.voiceDetail") private var detail = "Essential directions"
    var body: some View {
        AccountPage(title: "Navigation settings", subtitle: "Make the journey feel like yours", centered: true) {
            AccountCard {
                Text("Your navigation, your way").font(.title3.bold())
                Text("Choose the detail and guidance that suit you.").font(.subheadline)
                Picker("Navigation mode", selection: $simple) {
                    Text("Standard").tag(false)
                    Text("Simple Mode").tag(true)
                }.pickerStyle(.segmented)
            }
            AccountCard {
                NavigationLink { AccountVoiceSettings() } label: {
                    AccountRowLabel(title: "Voice guidance", detail: language == "ms-MY" ? "Bahasa Melayu" : "English")
                }
                Text(detail).font(.caption).foregroundStyle(.secondary)
                Divider()
                NavigationLink { AccountMapSettings() } label: {
                    AccountRowLabel(title: "Map appearance", detail: style)
                }
                Text(theme).font(.caption).foregroundStyle(.secondary)
            }
            AccountCard {
                Toggle("Speed limit", isOn: $showSpeedLimit)
                Toggle("Detailed road names", isOn: $showRoadNames)
            }
            NavigationLink { AccountRewardsOverview() } label: { AccountAction(title: "TuJu Rewards", prominent: false) }
            Button { dismiss() } label: { AccountAction(title: "Save preferences") }
        }
    }
}

private struct AccountVoiceSettings: View {
    @AppStorage("tuju.voiceLanguage") private var language = "ms-MY"
    @AppStorage("tuju.voiceDetail") private var detail = "Essential directions"
    @State private var speech = AVSpeechSynthesizer()
    var body: some View {
        AccountPage(title: "Voice guidance", subtitle: "Hear the directions your way", centered: true) {
            AccountCard {
                Text("Language").font(.headline)
                Picker("Language", selection: $language) {
                    Text("Bahasa Melayu").tag("ms-MY")
                    Text("English").tag("en-GB")
                }.pickerStyle(.segmented)
            }
            AccountCard {
                Text("Directions").font(.headline)
                ForEach(["Essential directions", "Detailed directions", "Simple", "Mute"], id: \.self) { choice in
                    Button {
                        detail = choice
                        if choice == "Mute" { speech.stopSpeaking(at: .immediate) }
                    } label: {
                        HStack {
                            Text(choice)
                            Spacer()
                            Image(systemName: detail == choice ? "checkmark.circle.fill" : "circle")
                        }.contentShape(Rectangle()).frame(minHeight: 36)
                    }.accessibilityAddTraits(detail == choice ? .isSelected : [])
                }
            }
            Button {
                speech.stopSpeaking(at: .immediate)
                let sample = AVSpeechUtterance(string: language == "ms-MY" ? "Dalam dua ratus meter, belok kiri." : "In two hundred metres, turn left.")
                sample.voice = AVSpeechSynthesisVoice(language: language)
                speech.speak(sample)
            } label: { AccountAction(title: "Preview voice") }
            .disabled(detail == "Mute").opacity(detail == "Mute" ? 0.5 : 1)
        }
        .onDisappear { speech.stopSpeaking(at: .immediate) }
    }
}

struct TuJuMapAppearanceView: View {
    var body: some View { AccountSheet { AccountMapSettings() } }
}

private struct AccountMapSettings: View {
    @AppStorage("tuju.mapTheme") private var theme = "TuJu Blue"
    @AppStorage("tuju.mapStyle") private var style = "Daylight"
    var body: some View {
        AccountPage(title: "Map appearance", subtitle: "Choose your preferred view", centered: true) {
            AccountCard {
                Text("Colour theme").font(.headline)
                options(["TuJu Blue", "Night Blue"], ["BluePreview", "NightPreview"], selection: $theme)
            }
            AccountCard {
                Text("Map style").font(.headline)
                options(["Default 3D", "Daylight", "Terrain"], ["3DPreview", "DaylightPreview", "TerrainPreview"], selection: $style)
            }
        }
    }

    private func options(_ labels: [String], _ art: [String], selection: Binding<String>) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { tiles(labels, art, selection: selection) }
            VStack(spacing: 8) { tiles(labels, art, selection: selection) }
        }
    }

    private func tiles(_ labels: [String], _ art: [String], selection: Binding<String>) -> some View {
        ForEach(Array(labels.enumerated()), id: \.element) { index, label in
            Button {
                selection.wrappedValue = label
            } label: {
                VStack(spacing: 6) {
                    Image("Account" + art[index]).resizable().scaledToFill()
                        .frame(maxWidth: .infinity).frame(height: 63).clipped().clipShape(RoundedRectangle(cornerRadius: 10))
                    Text(label).font(.caption.weight(.semibold)).fixedSize(horizontal: true, vertical: false)
                }
                .padding(5).overlay {
                    RoundedRectangle(cornerRadius: 14).stroke(selection.wrappedValue == label ? AccountPalette.blue : Color.clear, lineWidth: 2)
                }
            }.accessibilityAddTraits(selection.wrappedValue == label ? .isSelected : [])
        }
    }
}
