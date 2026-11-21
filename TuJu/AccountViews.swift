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
        .buttonStyle(HeroUIGlassButtonStyle())
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
            .heroGlass(.card)
    }
}

struct AccountRowLabel: View {
    var title: String
    var detail = ""
    var art: String? = nil
    var body: some View {
        HStack(spacing: 12) {
            if let art { Image(art).resizable().scaledToFit().frame(width: 22, height: 22).accessibilityHidden(true) }
            Text(title).font(HeroUIGlass.controlFont)
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
        Text(title).font(HeroUIGlass.controlFont).padding(.horizontal).padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .foregroundStyle(prominent ? Color.white : AccountPalette.blue)
            .background {
                if prominent {
                    Capsule().fill(AccountPalette.blue)
                } else {
                    Capsule().fill(.regularMaterial).overlay { Capsule().fill(Color.primary.opacity(0.07)) }
                }
            }
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
        .tujuLightChrome()
        .tint(AccountPalette.blue)
    }
}

struct TuJuProfileView: View {
    @EnvironmentObject private var session: TuJuSession
    @AppStorage("tuju.displayName") private var localName = ""
    @AppStorage(TuJuRewardsLedger.storageKey) private var data = Data()
    @State private var confirmLogout = false
    @State private var editing = false
    @State private var draftName = ""
    @State private var showSignIn = false
    @State private var showWelcome = false
    @State private var sessionError: String?
    private var ledger: TuJuRewardsLedger? { TuJuRewardsLedger.decode(data) }
    private var name: String { session.displayName ?? (localName.isEmpty ? "Guest" : localName) }

    var body: some View {
        AccountSheet { profile }
        .sheet(isPresented: $showSignIn) {
            TuJuAccountEntry(onContinue: { showSignIn = false }, onBack: { showSignIn = false })
        }
        .sheet(isPresented: $showWelcome) {
            TuJuWelcomeView { showWelcome = false }
        }
        .confirmationDialog("Sign out of TuJu?", isPresented: $confirmLogout, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) {
                do { try session.signOut() }
                catch { sessionError = error.localizedDescription }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Trip history and map preferences are stored on this device.") }
        .alert("Couldn’t sign out", isPresented: Binding(
            get: { sessionError != nil }, set: { if !$0 { sessionError = nil } }
        )) {
            Button("OK") { sessionError = nil }
        } message: { Text(sessionError ?? "") }
        .alert("Edit on-device profile", isPresented: $editing) {
            TextField("Display name", text: $draftName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                localName = String(draftName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(48))
            }.disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var profile: some View {
        AccountPage(title: "Profile", subtitle: "Your journeys, preferences and rewards", centered: true) {
            Button {
                draftName = localName
                editing = true
            } label: {
                AccountCard {
                    HStack(spacing: 14) {
                        Text(String(name.prefix(1)).uppercased()).font(.title3.bold())
                            .frame(width: 48, height: 48).background(AccountPalette.mist, in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(name).font(.title3.bold())
                            Text((session.identity == nil ? "On-device profile" : "Signed in to TuJu") + " · " + badgeSummary).font(.caption)

                        }
                        Spacer()
                        if session.identity == nil { Image(systemName: "pencil").font(.caption) }
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(session.identity != nil)
            .accessibilityLabel(session.identity == nil ? "Edit on-device profile, " + name : "Signed in as " + name)
            if session.isConfigured && session.identity == nil {
                Button { showSignIn = true } label: { AccountAction(title: "Sign in to TuJu") }
            }
            NavigationLink {
                AccountRewardsOverview()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("TuJu Rewards").font(.headline)
                        if let ledger {
                            Text("\(ledger.balance) points").font(.title.bold())
                            Text("\(ledger.tierName) · \(ledger.xp) Journey XP").font(.caption)
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
                    AccountRowLabel(title: "Your achievements", detail: ledger.map { $0.unlockedMilestones.count == 1 ? "1 badge" : "\($0.unlockedMilestones.count) badges" } ?? "", art: "AccountAward")
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
            Button { showWelcome = true } label: { AccountAction(title: "Welcome tour", prominent: false) }
            if session.identity != nil {
                Button { confirmLogout = true } label: { AccountAction(title: "Sign out", prominent: false) }
            }
        }
    }

    private var badgeSummary: String {
        ledger?.achievementSummary ?? "Rewards unavailable"
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
    @AppStorage("tuju.vehicleIcon") private var vehicle = TuJuVehicle.arrow
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
                Divider()
                TuJuVehiclePicker(selection: $vehicle)
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

enum TuJuVoice {
    static func voice(language: String, accent: String) -> AVSpeechSynthesisVoice? {
        let sameLanguage = !accent.isEmpty && accent.split(separator: "-").first == language.split(separator: "-").first
        if sameLanguage, let voice = AVSpeechSynthesisVoice(language: accent) { return voice }
        return AVSpeechSynthesisVoice(language: language)
    }

    static func installedAccents(for language: String) -> [String] {
        let prefix = language.split(separator: "-").first
        return Set(AVSpeechSynthesisVoice.speechVoices().map(\.language).filter {
            $0.split(separator: "-").first == prefix
        }).sorted { localized($0) < localized($1) }
    }

    static func localized(_ language: String) -> String {
        Locale.current.localizedString(forIdentifier: language) ?? language
    }
}

private struct AccountVoiceSettings: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("tuju.voiceAccent") private var accent = ""
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
                let accents = TuJuVoice.installedAccents(for: language)
                Picker("Choose accent", selection: $accent) {
                    Text("Standard").tag("")
                    ForEach(accents, id: \.self) { code in Text(TuJuVoice.localized(code)).tag(code) }
                }
                .frame(minHeight: 44)
                Button {
                    speech.stopSpeaking(at: .immediate)
                    let short = detail == "Simple"
                    let malay = language == "ms-MY"
                    let words = short ? (malay ? "Belok kiri." : "Turn left.")
                        : (malay ? "Dalam dua ratus meter, belok kiri." : "In two hundred metres, turn left.")
                    let sample = AVSpeechUtterance(string: words)
                    sample.voice = TuJuVoice.voice(language: language, accent: accent)
                    speech.speak(sample)
                } label: { AccountAction(title: "Play voice preview", prominent: false) }
                .disabled(detail == "Mute")
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
            Button { dismiss() } label: { AccountAction(title: "Save voice settings") }
        }
        .onChange(of: language) { _, newValue in
            if !TuJuVoice.installedAccents(for: newValue).contains(accent) { accent = "" }
            speech.stopSpeaking(at: .immediate)
        }
        .onDisappear { speech.stopSpeaking(at: .immediate) }
    }
}

struct TuJuMapAppearanceView: View {
    var body: some View { AccountSheet { AccountMapSettings() } }
}

private struct AccountMapSettings: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("tuju.nightMode") private var nightMode = TuJuNightMode.initial
    @AppStorage("tuju.vehicleIcon") private var vehicle = TuJuVehicle.arrow
    @AppStorage("tuju.mapTheme") private var theme = "TuJu Blue"
    @AppStorage("tuju.mapStyle") private var style = "Daylight"
    var body: some View {
        AccountPage(title: "Map appearance", subtitle: "Choose your preferred view", centered: true) {
            AccountCard {
                Text("Colour theme").font(.headline)
                options(["TuJu Blue", "Night Blue"], ["BluePreview", "NightPreview"], selection: Binding(
                    get: { theme }, set: { theme = $0; nightMode = .manual }
                ))
            }
            AccountCard {
                Text("Map style").font(.headline)
                options(["Default 3D", "Daylight", "Terrain"], ["3DPreview", "DaylightPreview", "TerrainPreview"], selection: $style)
            }
            AccountCard {
                Picker("Night mode", selection: $nightMode) {
                    Text("Automatic").tag(TuJuNightMode.automatic)
                    Text("Selected colour theme").tag(TuJuNightMode.manual)
                }.frame(minHeight: 44)
                TuJuVehiclePicker(selection: $vehicle)
            }
            Button { dismiss() } label: { AccountAction(title: "Apply appearance") }
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

enum TuJuVehicle: String, CaseIterable {
    case arrow = "Navigation arrow", car = "Car", motorcycle = "Motorcycle"

    var symbol: String {
        switch self {
        case .arrow: return "location.north.fill"
        case .car: return "car.fill"
        case .motorcycle: return "motorcycle.fill"
        }
    }
}

private struct TuJuVehiclePicker: View {
    @Binding var selection: TuJuVehicle

    var body: some View {
        Picker("Vehicle icon", selection: $selection) {
            ForEach(TuJuVehicle.allCases, id: \.self) { icon in
                Label(icon.rawValue, systemImage: icon.symbol).tag(icon)
            }
        }.frame(minHeight: 44)
    }
}

struct TuJuVehicleMarker: View {
    @AppStorage("tuju.vehicleIcon") private var icon = TuJuVehicle.arrow

    var body: some View {
        Image(systemName: icon.symbol).font(.body.bold()).foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(AccountPalette.blue, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .accessibilityLabel("Your location")
    }
}

private enum TuJuNightMode: String {
    case automatic, manual
    static var initial: Self { UserDefaults.standard.string(forKey: "tuju.mapTheme") == nil ? .automatic : .manual }
}

private struct TuJuSystemScheme: EnvironmentKey {
    static let defaultValue: ColorScheme? = nil
}

private extension EnvironmentValues {
    var tujuSystemScheme: ColorScheme? {
        get { self[TuJuSystemScheme.self] }
        set { self[TuJuSystemScheme.self] = newValue }
    }
}

private struct TuJuLightChrome: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.tujuSystemScheme) private var inherited

    func body(content: Content) -> some View {
        content.environment(\.tujuSystemScheme, inherited ?? scheme).environment(\.colorScheme, .light)
    }
}

private struct TuJuMapColors: ViewModifier {
    let theme: String
    @Environment(\.colorScheme) private var scheme
    @Environment(\.tujuSystemScheme) private var inherited
    @AppStorage("tuju.nightMode") private var mode = TuJuNightMode.initial

    func body(content: Content) -> some View {
        content.environment(\.colorScheme, mode == .automatic ? (inherited ?? scheme) : (theme == "Night Blue" ? .dark : .light))
    }
}

extension View {
    func tujuLightChrome() -> some View { modifier(TuJuLightChrome()) }
    func tujuMapColors(theme: String) -> some View { modifier(TuJuMapColors(theme: theme)) }
}
