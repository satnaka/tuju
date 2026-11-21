import SwiftUI

private enum WelcomePage: Int, CaseIterable, Identifiable {
    case wayfinding, stops, navigation, rewards

    var id: Self { self }

    var artwork: String {
        switch self {
        case .wayfinding: "WelcomeWayfinding"
        case .stops: "WelcomeStops"
        case .navigation: "WelcomeNavigation"
        case .rewards: "WelcomeRewards"
        }
    }

    var title: String {
        switch self {
        case .wayfinding: "The right lane.\nAt the right time."
        case .stops: "A better stop.\nA smoother journey."
        case .navigation: "Your journey.\nYour way."
        case .rewards: "A little progress.\nEvery journey."
        }
    }

    var detail: String {
        switch self {
        case .wayfinding: "See the lane ahead and prepare for exits with clearer, earlier guidance."
        case .stops: "Check crowd and parking information, then choose a stop that suits your journey."
        case .navigation: "Choose your map, voice and level of detail. Keep things clear with Simple Mode."
        case .rewards: "Track your progress, discover badges and explore rewards after your journey."
        }
    }
}

private let welcomeInk = Color(red: 0.031, green: 0.102, blue: 0.20)

private struct WelcomeBackdrop: View {
    var body: some View {
        LinearGradient(stops: [
            .init(color: Color(red: 0.812, green: 0.898, blue: 1), location: 0),
            .init(color: Color(red: 0.961, green: 0.969, blue: 1), location: 0.58),
            .init(color: .white, location: 1)
        ], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
    }
}

private struct WelcomeButton: View {
    let title: String
    var primary = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).font(.headline).multilineTextAlignment(.center)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 54)
                .foregroundStyle(primary ? Color.white : welcomeInk)
                .background {
                    if primary {
                        Capsule().fill(Color(red: 0.015, green: 0.357, blue: 0.89))
                    } else {
                        Color.clear.heroGlass(.control, radius: 27)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct TuJuWelcomeView: View {
    @EnvironmentObject private var session: TuJuSession
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = WelcomePage.wayfinding
    @State private var showingAccount = false
    let onFinish: () -> Void

    private var shortcutTitle: String {
        if session.identity != nil { return "Continue to TuJu" }
        return session.isConfigured ? "I already have an account" : "Continue as guest"
    }

    var body: some View {
        ZStack {
            WelcomeBackdrop()
            if showingAccount {
                TuJuAccountEntry(onContinue: onFinish, onBack: { showingAccount = false })
            } else {
                VStack(spacing: 0) {
                    TabView(selection: $page) {
                        ForEach(WelcomePage.allCases) { item in
                            GeometryReader { size in
                                ScrollView {
                                    VStack(spacing: 0) {
                                        Spacer(minLength: 8)
                                        Image(item.artwork).resizable().scaledToFit()
                                            .frame(maxWidth: .infinity)
                                            .frame(height: min(340, max(110, size.size.height * (typeSize.isAccessibilitySize ? 0.32 : 0.57))))
                                            .accessibilityHidden(true)
                                        Spacer().frame(height: min(32, size.size.height * 0.052))
                                        Text(item.title).font(.largeTitle.bold()).multilineTextAlignment(.center)
                                            .accessibilityAddTraits(.isHeader)
                                        Text(item.detail).font(.body).multilineTextAlignment(.center)
                                            .padding(.top, 14).frame(maxWidth: 340)
                                        Spacer(minLength: 12)
                                    }
                                    .padding(.horizontal, 24)
                                    .frame(maxWidth: 460, minHeight: size.size.height)
                                    .frame(maxWidth: .infinity)
                                }
                                .scrollBounceBehavior(.basedOnSize)
                            }.tag(item)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    HStack(spacing: 6) {
                        ForEach(WelcomePage.allCases) { item in
                            Capsule().fill(item == page ? Color.blue : Color(red: 0.75, green: 0.82, blue: 0.91))
                                .frame(width: item == page ? 22 : 6, height: 6)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Page \(page.rawValue + 1) of \(WelcomePage.allCases.count)")
                    .padding(.bottom, 28)
                    VStack(spacing: 12) {
                        WelcomeButton(title: page == .rewards ? "Get started" : "Next") {
                            if let next = WelcomePage(rawValue: page.rawValue + 1) {
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { page = next }
                            } else {
                                showingAccount = true
                            }
                        }
                        WelcomeButton(title: shortcutTitle, primary: false) {
                            if session.isConfigured && session.identity == nil { showingAccount = true } else { onFinish() }
                        }
                    }
                    .frame(maxWidth: 408)
                    .padding(.horizontal, 24).padding(.bottom, 12)
                }
            }
        }
        .foregroundStyle(welcomeInk)
        .preferredColorScheme(.light)
    }
}

struct TuJuAccountEntry: View {
    @EnvironmentObject private var session: TuJuSession
    @State private var errorMessage: String?
    let onContinue: () -> Void
    let onBack: () -> Void

    var body: some View {
        GeometryReader { size in
            ScrollView {
                VStack(spacing: 16) {
                    Image("WelcomeJourney").resizable().scaledToFit()
                        .frame(maxWidth: 266).frame(height: min(255, size.size.height * 0.30))
                        .accessibilityHidden(true)
                    Text(session.isConfigured ? "Welcome back." : "Welcome to TuJu.").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                    Text("Let’s get you on the road.").font(.body)
                    VStack(spacing: 12) {
                        if session.isConfigured && session.identity == nil {
                            WelcomeButton(title: session.isSigningIn ? "Signing in…" : "Sign in to TuJu") {
                                Task {
                                    do {
                                        try await session.signIn()
                                        if session.identity != nil { onContinue() }
                                    } catch is CancellationError {
                                        // The system sign-in sheet was dismissed.
                                    } catch {
                                        errorMessage = error.localizedDescription
                                    }
                                }
                            }.disabled(session.isSigningIn)
                        }
                        WelcomeButton(title: session.identity == nil ? "Continue as guest" : "Continue to TuJu",
                                      primary: !session.isConfigured || session.identity != nil, action: onContinue)
                            .disabled(session.isSigningIn)
                    }
                    .padding(.top, 20)
                    if let errorMessage {
                        Text(errorMessage).font(.callout).foregroundStyle(.secondary)
                    }
                    Button("Back", action: onBack).frame(minHeight: 44)
                }
                .multilineTextAlignment(.center).padding(24)
                .frame(maxWidth: 456, minHeight: size.size.height)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background { WelcomeBackdrop() }
        .foregroundStyle(welcomeInk)
        .preferredColorScheme(.light)
    }
}
