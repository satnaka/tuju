import MapKit
import SwiftUI

private enum RideProvider: String, CaseIterable {
    case grab = "Grab", maxim = "Maxim", inDrive
    var fare: String {
        switch self { case .grab: "RM18–25"; case .maxim: "RM15–22"; case .inDrive: "RM16–23" }
    }
    var logo: String {
        switch self { case .grab: "RideGrab"; case .maxim: "RideMaxim"; case .inDrive: "RideInDrive" }
    }
    var url: URL {
        switch self {
        case .grab: URL(string: "https://www.grab.com/my/transport/")!
        case .maxim: URL(string: "https://taximaxim.com/my/en/")!
        case .inDrive: URL(string: "https://indrive.com/en-my/city-rides")!
        }
    }
    var color: Color {
        switch self { case .grab: .mint; case .maxim: .yellow; case .inDrive: .green }
    }
}

private enum RideStage: Int, CaseIterable {
    case options, finding, matched, pickup
    var title: String {
        switch self { case .options: "Ride options"; case .finding: "Finding driver"; case .matched: "Driver found"; case .pickup: "Driver on the way" }
    }
    var subtitle: String {
        switch self {
        case .options: "Choose a provider to continue"
        case .finding: "Matching you with a nearby driver"
        case .matched: "Amir has accepted your ride"
        case .pickup: "Your driver is heading to your pickup"
        }
    }
    var map: String {
        switch self { case .options: "RideOverview"; case .finding: "RideFinding"; case .matched: "RideMatched"; case .pickup: "RidePickup" }
    }
}

struct TuJuRideView: View {
    let destination: String
    @Environment(\.dismiss) private var dismiss
    @State private var stage = RideStage.options
    @State private var provider = RideProvider.grab
    @State private var contactTitle = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left").frame(width: 44, height: 44).heroGlass(.control, radius: 22)
                    }
                        .accessibilityLabel("Back to route")
                    Spacer()
                    Text(stage.title).font(.title2.bold())
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                Text(stage.subtitle).font(.subheadline)
                Image(stage.map).resizable().aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .accessibilityLabel(stage == .options ? "Illustrated route to your destination" : "Illustrated pickup map")
                VStack(spacing: 12) {
                    Capsule().fill(.gray.opacity(0.32)).frame(width: 34, height: 4)
                    if stage == .options { options } else { booking }
                }
                .padding(16).frame(maxWidth: .infinity)
                .heroGlass(.panel, radius: 27)
                Text("Ride preview · Simulated drivers and fares").font(.caption2).foregroundStyle(.secondary)
            }.padding(.horizontal, 20).padding(.vertical, 12)
        }.background(Color(red: 0.94, green: 0.98, blue: 0.99).ignoresSafeArea())
        .foregroundStyle(Color.tujuNavy).buttonStyle(HeroUIGlassButtonStyle())
        .task(id: stage) {
            guard stage == .finding else { return }
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            withAnimation { stage = .matched }
        }
        .alert(contactTitle, isPresented: Binding(get: { !contactTitle.isEmpty }, set: { if !$0 { contactTitle = "" } })) {
            Button("OK") { contactTitle = "" }
        } message: { Text("Amir is a sample driver in the TuJu ride preview.") }
    }

    private var options: some View {
        Group {
            Text("Find your ride").font(.title3.bold())
            Text("Your location → \(destination)").font(.subheadline)
            HStack {
                Button("Drive") { dismiss() }.buttonStyle(.bordered)
                Label("Ride", systemImage: "circle.fill").font(.footnote.weight(.semibold))
                    .padding(.horizontal, 20).padding(.vertical, 7).background(.blue.opacity(0.07), in: Capsule())
            }
            ForEach(RideProvider.allCases, id: \.self) { option in
                Button {
                    provider = option
                    withAnimation { stage = .finding }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.rawValue).font(.headline)
                            Text("Preview ride in TuJu").font(.caption)
                            HStack { Text("Est. fare").font(.caption2); Text(option.fare).font(.subheadline.bold()) }
                        }
                        Spacer()
                        Image(option.logo).resizable().scaledToFit().frame(width: 60, height: 40)
                    }.padding(15).frame(minHeight: 82)
                        .background(option.color.opacity(0.13), in: RoundedRectangle(cornerRadius: 20))
                        .overlay { RoundedRectangle(cornerRadius: 20).stroke(option == .grab ? Color.blue.opacity(0.65) : option.color.opacity(0.65), lineWidth: option == .grab ? 2.5 : 1) }
                }
            }
        }
    }

    private var booking: some View {
        Group {
            HStack {
                ForEach([RideStage.finding, .matched, .pickup], id: \.rawValue) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Capsule().fill(item.rawValue <= stage.rawValue ? Color.blue : .gray.opacity(0.22)).frame(height: 3)
                        Text(item == .finding ? "Finding" : item == .matched ? "Matched" : "Pickup").font(.caption2)
                    }
                }
            }
            if stage == .finding {
                ProgressView().padding(.top, 8)
                Text("Looking for a nearby driver").font(.headline)
                Text("We’ll update you when a driver accepts.").font(.caption)
            } else {
                HStack {
                    Text("AH").bold().padding(12).background(.blue.opacity(0.08), in: Circle())
                    VStack(alignment: .leading) {
                        Text("Amir Hakim").font(.headline)
                        Text("★ 4.9 · 326 trips").font(.caption)
                    }
                    Spacer()
                    Text(provider.rawValue).font(.caption.bold())
                }
                HStack {
                    Image(systemName: "car.fill")
                    VStack(alignment: .leading) {
                        Text("Perodua Bezza").bold()
                        Text("Silver · 4 seats").font(.caption)
                    }
                    Spacer()
                    Text("VJD 2486").font(.caption.bold())
                }.font(.subheadline).padding(10).background(.blue.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            }
            VStack(alignment: .leading, spacing: 7) {
                Label("Pickup · Your location", systemImage: "circle.fill")
                Label(destination, systemImage: "square.fill")
            }.font(.caption).frame(maxWidth: .infinity, alignment: .leading).padding(10)
            HStack {
                Text(stage == .finding ? provider.rawValue : stage == .matched ? "5 min away" : "3 min away").bold()
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Est. fare").font(.caption2)
                    Text(provider.fare).font(.headline)
                }
            }
            if stage != .finding {
                HStack {
                    Button("Call driver") { contactTitle = "Call driver" }
                    Spacer()
                    Button("Message") { contactTitle = "Message driver" }
                }.font(.subheadline.bold()).padding(.horizontal, 22).padding(.vertical, 8)
            }
            Button {
                withAnimation {
                    switch stage { case .finding: stage = .options; case .matched: stage = .pickup; default: dismiss() }
                }
            } label: {
                Text(stage == .finding ? "Cancel search" : stage == .matched ? "Preview pickup" : "Finish preview")
                    .font(HeroUIGlass.controlFont).foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 44)
                    .background(.blue, in: Capsule())
            }
        }
    }
}

struct TuJuJourneyChoiceView: View {
    let destination: JourneyPlace
    let pickup: CLLocation?
    let plan: JourneyPlan?
    let calculating: Bool
    let onDrive: () -> Void
    let onBack: () -> Void
    let onTab: ((TuJuTab) -> Void)?

    private enum Page: Equatable {
        case choice, providers, review(RideProvider)
    }
    @State private var page = Page.choice
    @State private var failedToOpen = false
    @Environment(\.openURL) private var openURL
    @AppStorage("tuju.mapStyle") private var mapStyle = "Daylight"
    @AppStorage("tuju.mapTheme") private var mapTheme = "TuJu Blue"

    private var title: String {
        switch page {
        case .choice: "Choose your journey"
        case .providers: "Ride options"
        case .review(let provider): "Continue with " + provider.rawValue
        }
    }

    private var subtitle: String {
        switch page {
        case .choice: "Destination: " + destination.name
        case .providers: "Choose a provider to continue"
        case .review: "Complete booking with the provider"
        }
    }

    var body: some View {
        GeometryReader { bounds in
            ScrollView {
                VStack(spacing: 14) {
                    VStack(spacing: 5) {
                        Text(title).font(.title2.bold()).multilineTextAlignment(.center).accessibilityAddTraits(.isHeader)
                            .padding(.horizontal, 42).frame(maxWidth: .infinity, minHeight: 40)
                            .overlay(alignment: .leading) {
                                Button(action: back) {
                                    Image(systemName: "chevron.left").font(.headline).frame(width: 42, height: 42)
                                        .heroGlass(.control, radius: 21)
                                }.accessibilityLabel("Back")
                            }
                        Text(subtitle).font(.subheadline).multilineTextAlignment(.center)
                    }
                    map.frame(height: min(228, max(145, bounds.size.height * (page == .providers ? 0.24 : 0.28))))
                        .clipShape(RoundedRectangle(cornerRadius: 23))
                    VStack(spacing: 12) {
                        Capsule().fill(Color.secondary.opacity(0.3)).frame(width: 35, height: 4)
                        switch page {
                        case .choice: choice
                        case .providers: providers
                        case .review(let provider): review(provider)
                        }
                    }
                    .padding(16).frame(maxWidth: .infinity).heroGlass(.card, radius: 23)
                    if case .review = page {
                        action("Choose another provider", primary: false) { page = .providers }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 10)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom, spacing: 6) {
            if let onTab { TuJuTabBar(selected: .trips, onSelect: onTab).padding(.bottom, 4) }
        }
        .foregroundStyle(JourneyInk.navy)
        .background(LinearGradient(colors: [JourneyInk.sky, Color(uiColor: .systemBackground), .mint.opacity(0.08)],
                                   startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .alert("Provider could not open", isPresented: $failedToOpen) { Button("OK") {} }
    }

    private var map: some View {
        Map {
            if let pickup { Marker("Pickup", systemImage: "location.fill", coordinate: pickup.coordinate).tint(.blue) }
            Marker(destination.name, coordinate: destination.coordinate).tint(JourneyInk.navy)
            if let plan {
                ForEach(plan.paths.indices, id: \.self) { MapPolyline(plan.paths[$0]).stroke(.blue, lineWidth: 5) }
            }
        }
        .mapStyle(mapStyle == "Terrain" ? .hybrid(elevation: .realistic) :
                  .standard(elevation: mapStyle == "Default 3D" ? .realistic : .flat, emphasis: .muted))
        .tujuMapColors(theme: mapTheme)
        .mapControls { }
        .accessibilityLabel("Map to " + destination.name)
    }

    @ViewBuilder private var choice: some View {
        Text(destination.name).font(.title3.bold()).multilineTextAlignment(.center)
        Text(pickup == nil ? "Choose how to get there" : "From your current location").font(.footnote).foregroundStyle(.secondary)
        modes
        HStack(spacing: 10) {
            estimate(plan.map { JourneyFormat.time($0.duration) }, label: "Drive time")
            estimate(plan.map { JourneyFormat.distance($0.distance) }, label: "Distance")
        }
        action("Drive with TuJu", primary: true, perform: onDrive)
        action("Compare ride options", primary: false) { page = .providers }
    }

    private func estimate(_ value: String?, label: String) -> some View {
        VStack(spacing: 7) {
            Text(value ?? (calculating ? "…" : "—")).font(.title2.bold()).minimumScaleFactor(0.75)
            Text(label).font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 80).heroGlass(.card, radius: 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value ?? (calculating ? "Calculating" : "Unavailable"))
    }

    @ViewBuilder private var providers: some View {
        Text("Find your ride").font(.title3.bold())
        Text((pickup == nil ? "Choose pickup with provider" : "Your location") + " → " + destination.name)
            .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        modes
        ForEach(RideProvider.allCases, id: \.self) { provider in
            Button {
                page = .review(provider)
            } label: {
                VStack(spacing: 6) {
                    Text(provider.rawValue).font(.headline)
                    Text("View fare and availability with the provider").font(.footnote).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, minHeight: 64).heroGlass(.card, radius: 18)
            }
        }
    }

    private var modes: some View {
        HStack(spacing: 10) {
            mode("Drive", isSelected: page == .choice) { page = .choice }
            mode("Ride", isSelected: page == .providers) { page = .providers }
        }
    }

    private func mode(_ name: String, isSelected: Bool, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            HStack(spacing: 4) {
                if isSelected { Circle().fill(JourneyInk.blue).frame(width: 8, height: 8) }
                Text(name).font(.subheadline.weight(.semibold)).foregroundStyle(isSelected ? JourneyInk.blue : .secondary)
            }.frame(width: 106, height: 32).background(JourneyInk.sky.opacity(0.8), in: Capsule())
                .frame(minHeight: 44).contentShape(Rectangle())
        }.accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder private func review(_ provider: RideProvider) -> some View {
        Text(title).font(.title3.bold()).accessibilityAddTraits(.isHeader)
        Text("Finish your booking with the provider").font(.footnote).foregroundStyle(.secondary)
        Image(provider.logo).resizable().scaledToFit().frame(width: 78, height: 34).accessibilityLabel(provider.rawValue)
        VStack(spacing: 4) {
            Text(pickup == nil ? "Pickup: Choose with the provider" : "Pickup: Your current location")
            Text("Drop-off: " + destination.name)
            if !destination.subtitle.isEmpty { Text(destination.subtitle) }
        }
        .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center).textSelection(.enabled)
        Text("Enter your pickup and drop-off with " + provider.rawValue + " to check the fare and vehicle availability.")
            .font(.subheadline).multilineTextAlignment(.center)
        action("Open " + provider.rawValue, primary: true) { open(provider) }
    }

    private func open(_ provider: RideProvider) {
        if provider == .grab, let booking = URL(string: "grab://open?screenType=BOOKING") {
            openURL(booking) { opened in
                if !opened { openProviderSite(provider) }
            }
        } else { openProviderSite(provider) }
    }

    private func openProviderSite(_ provider: RideProvider) {
        openURL(provider.url) { opened in
            if !opened { failedToOpen = true }
        }
    }

    @ViewBuilder private func action(_ title: String, primary: Bool, perform: @escaping () -> Void) -> some View {
        let button = Button(action: perform) {
            Text(title).font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 34)
        }
        if #available(iOS 26, macCatalyst 26, *) {
            if primary { button.buttonStyle(.glassProminent).tint(.blue) }
            else { button.buttonStyle(.glass) }
        } else {
            if primary { button.buttonStyle(.borderedProminent) }
            else { button.buttonStyle(.bordered) }
        }
    }

    private func back() {
        switch page {
        case .choice: onBack()
        case .providers: page = .choice
        case .review: page = .providers
        }
    }
}
