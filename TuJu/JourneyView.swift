import MapKit
import SwiftUI

enum JourneyInk {
    static let navy = Color(red: 0.058, green: 0.18, blue: 0.36)
    static let blue = Color(red: 0.015, green: 0.36, blue: 0.70)
    static let sky = Color(red: 0.86, green: 0.96, blue: 0.99)
    static let line = Color(red: 0.70, green: 0.84, blue: 0.97)
}

extension View {
    func journeyCard(_ radius: CGFloat = 20) -> some View {
        heroGlass(.card, radius: radius)
    }

    func journeyPanel() -> some View {
        heroGlass(.panel, radius: 27)
    }
}

struct JourneyView: View {
    let initialQuery: String
    let origin: CLLocationCoordinate2D?
    var initialDestination: JourneyPlace? = nil
    var showStopsInitially = false
    var onTab: ((TuJuTab) -> Void)? = nil
    let onClose: () -> Void

    @ObservedObject private var history = JourneyHistory.shared
    @State private var query = ""
    @State private var destination: JourneyPlace?
    @State private var results: [JourneyPlace] = []
    @State private var searching = false
    @State private var searchIssue: String?
    @State private var savedOnly = false
    @State private var demo = false
    @State private var avoidTolls = false
    @State private var stop: JourneyPlace?
    @State private var plans: [JourneyPlan] = []
    @State private var planIndex = 0
    @State private var calculating = false
    @State private var routeIssue: String?
    @State private var attempts = 0
    @State private var sheet: JourneySheet?
    @State private var driving = false
    @State private var roadEstimate: JourneyEstimate?
    @State private var startedID: UUID?
    @State private var openStopsAfterRouting = false
    @State private var stopDetailName: String?
    @State private var initialized = false
    @State private var mapsIssue = false
    @FocusState private var typing: Bool
    @AppStorage("tuju.mapStyle") private var mapStyle = "Daylight"
    @AppStorage("tuju.mapTheme") private var mapTheme = "TuJu Blue"

    private var queryText: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var plan: JourneyPlan? { plans.indices.contains(planIndex) ? plans[planIndex] : nil }
    private var source: JourneyPlace {
        guard let origin else { return .klSentral }
        return JourneyPlace(name: "Your location", subtitle: "", latitude: origin.latitude, longitude: origin.longitude)
    }
    private var region: MKCoordinateRegion {
        .init(center: source.coordinate, latitudinalMeters: 30000, longitudinalMeters: 30000)
    }
    private var routeKey: String { "\(destination?.id ?? "")|\(demo)|\(stop?.id ?? "")|\(avoidTolls)|\(attempts)" }
    private var localCategory: [JourneyPlace]? {
        func amenity(_ name: String, _ note: String) -> JourneyPlace {
            JourneyPlace(name: name, subtitle: note, latitude: 3.14, longitude: 101.62)
        }
        switch queryText.lowercased() {
        case "fuel", "petrol", "petrol station", "petrol stations", "gas station", "ev charging", "ev charger", "ev charging stations":
            return [amenity("PETRONAS", "R&R Sungai Buloh · Concept fuel stop"), amenity("JomCharge", "R&R Sungai Buloh · Concept EV charging")]
        case "food", "restaurants", "coffee", "café", "cafe", "cafes":
            return [amenity("Café Mesra", "R&R Sungai Buloh · Concept food stop"), .oneUtama]
        case "r&r", "rest stops", "rest areas", "rest stop", "rest area":
            return [amenity("R&R Sungai Buloh", "Concept rest stop · 12 km"), amenity("R&R USJ", "Concept rest stop · 21 km")]
        default: return nil
        }
    }
    private var searchKey: String { destination == nil && !savedOnly && localCategory == nil ? queryText : "" }

    var body: some View {
        Group {
            if driving, let plan, let destination {
                JourneyDriveView(plan: plan, destination: destination, demo: demo, onRoad: { estimate in roadEstimate = estimate; sheet = .road },
                                 onDetails: { sheet = .details }, onStops: { stopDetailName = nil; sheet = .stops }, onMaps: openMaps,
                                 onExit: { driving = false }, onFinish: {
                    if demo, let startedID { TuJuRewardsLedger.creditCompletedJourney(id: startedID, destination: destination.name) }
                    driving = false
                    onClose()
                })
            } else {
                GeometryReader { bounds in
                    ZStack {
                        mapLayer.ignoresSafeArea()
                        VStack(spacing: 10) {
                            if let destination { routeHeader(destination) } else { searchHeader }
                            Spacer(minLength: 0)
                            if destination != nil {
                                ScrollView { routePanel }.scrollIndicators(.hidden)
                                    .frame(height: min(plan?.hasTolls == false && demo ? 365 : 475, max(200, bounds.size.height * 0.65)))
                            } else {
                                searchPanel.frame(height: min(345, max(150, bounds.size.height * (typing ? 0.77 : 0.48))))
                            }
                            if !typing, let onTab { TuJuTabBar(selected: .home, onSelect: onTab) }
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 4)
                    }
                }
            }
        }
        .foregroundStyle(JourneyInk.navy)
        .buttonStyle(HeroUIGlassButtonStyle())
        .tint(JourneyInk.blue)
        .preferredColorScheme(.light)
        .onAppear {
            guard !initialized else { return }
            initialized = true
            query = initialQuery
            if initialQuery.caseInsensitiveCompare("Saved") == .orderedSame { query = ""; savedOnly = true }
            if showStopsInitially {
                openStopsAfterRouting = true
                choose(.oneUtama)
            } else if let initialDestination { choose(initialDestination) }
        }
        .task(id: searchKey) { await search(searchKey) }
        .task(id: routeKey) { await route() }
        .sheet(item: $sheet) { item in
            switch item {
            case .ride: TuJuRideView(destination: destination?.name ?? "One Utama")
            case .road:
                if let plan, let roadEstimate {
                    TuJuRoadPreviewView(estimate: roadEstimate, startAtFlyover: plan.name != "LDP")
                }
            case .details:
                if let plan, let destination {
                    JourneyDetailsView(plan: plan, destination: destination, demo: demo, onClose: { sheet = nil })
                }
            case .stops:
                if let plan {
                    JourneyStopsView(plan: plan, demo: demo, selected: stop, initialName: stopDetailName) { proposed in
                        stop = proposed
                        driving = false
                        sheet = nil
                    }
                }
            }
        }
        .alert("Apple Maps could not open", isPresented: $mapsIssue) {
            Button("OK", role: .cancel) {}
        }
    }

    @ViewBuilder private var mapLayer: some View {
        if demo || (destination == nil && origin == nil) {
            GeometryReader { bounds in
                ZStack {
                    Image("KualaLumpurMap").resizable().scaledToFill()
                    if let plan, destination != nil {
                        Image(plan.hasTolls ? "JourneySamplePath" : "JourneyTollFreePath").resizable().scaledToFill()
                        Text(shortTime(plan.duration) + " · " + (plan.hasTolls ? sampleFare(plan).replacingOccurrences(of: " toll", with: "") : "No toll"))
                            .font(.caption2.weight(.semibold)).foregroundStyle(JourneyInk.blue)
                            .padding(.horizontal, 12).padding(.vertical, 5).background(.white, in: Capsule())
                            .position(x: bounds.size.width * (plan.hasTolls ? 0.45 : 0.67), y: bounds.size.height * (plan.hasTolls ? 0.3 : 0.39))
                    }
                }
                .frame(width: bounds.size.width, height: bounds.size.height).clipped()
            }.accessibilityHidden(true)
        } else {
            JourneyMap(region: region, plans: plans, selected: plan, source: source, destination: destination, stop: stop,
                       style: mapStyle, night: mapTheme == "Night Blue")
        }
    }

    private var searchHeader: some View {
        HStack(spacing: 10) {
            backButton(action: onClose)
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                TextField("Search places or addresses", text: $query)
                    .textInputAutocapitalization(.words).submitLabel(.search).focused($typing)
                    .onSubmit { typing = false }
                if !query.isEmpty {
                    Button { query = ""; savedOnly = false } label: { Image(systemName: "xmark.circle.fill") }
                        .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 15).frame(minHeight: 46).heroGlass(.field, radius: 30, focused: typing)
        }
        .padding(.horizontal, 10)
    }

    private var visiblePlaces: [JourneyPlace] {
        if savedOnly { return history.saved }
        if let localCategory { return localCategory }
        if queryText.isEmpty {
            return history.recent.isEmpty ? JourneyPlace.suggestions : history.recent
        }
        let suggestions = JourneyPlace.suggestions.filter {
            ($0.name + " " + $0.subtitle).localizedCaseInsensitiveContains(queryText)
        }
        return suggestions + results.filter { place in !suggestions.contains(where: { $0.name.caseInsensitiveCompare(place.name) == .orderedSame }) }
    }

    private var searchPanel: some View {
        VStack(spacing: 8) {
            Capsule().fill(.blue.opacity(0.7)).frame(width: 34, height: 4)
            Text("Find your next destination").font(.title3.bold())
            HStack {
                category("R&R", "signpost.right", active: queryText == "R&R") { setQuery("R&R") }
                category("Fuel", "fuelpump", active: queryText == "Petrol station") { setQuery("Petrol station") }
                category("Saved", "heart", active: savedOnly) { query = ""; savedOnly = true; typing = false }
            }
            let heading = savedOnly ? "Saved places" : (queryText.isEmpty ? (history.recent.isEmpty ? "Suggested places" : "Recent searches") : "Search results")
            Text(heading).font(.subheadline.weight(.semibold))
            ScrollView {
                VStack(spacing: 0) {
                    if searching { ProgressView("Searching Apple Maps…").font(.footnote).padding(.vertical, 6) }
                    ForEach(visiblePlaces.prefix(12)) { place in
                        Button {
                            if place.subtitle.localizedCaseInsensitiveContains("Concept") {
                                stopDetailName = place.name == "R&R USJ" ? place.name : "R&R Sungai Buloh"
                                openStopsAfterRouting = true
                                choose(.oneUtama)
                            } else { choose(place) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: savedOnly ? "heart" : "mappin.and.ellipse").foregroundStyle(JourneyInk.blue)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(place.name).font(.subheadline.bold())
                                    if !place.subtitle.isEmpty { Text(place.subtitle).font(.caption).foregroundStyle(.secondary) }
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption2)
                            }.padding(.vertical, 9).padding(.horizontal, 5).contentShape(Rectangle())
                        }.buttonStyle(HeroUIGlassButtonStyle())
                    }
                    if !searching && visiblePlaces.isEmpty {
                        Text(savedOnly ? "Save a destination using its heart button." : (searchIssue ?? "No places found. Try a different name."))
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).padding()
                    }
                    if !queryText.isEmpty || savedOnly {
                        Button("Explore the One Utama concept route") { choose(.oneUtama) }
                            .font(.footnote.weight(.semibold)).padding(.vertical, 8)
                    }
                }
            }.scrollDismissesKeyboard(.interactively)
        }
        .padding(.horizontal, 17).padding(.vertical, 13).journeyPanel()
    }

    private func category(_ title: String, _ icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.caption.weight(.semibold)).frame(maxWidth: .infinity)
                .frame(minHeight: 40).background(active ? JourneyInk.line : .white.opacity(0.86), in: Capsule())
                .overlay(Capsule().strokeBorder(JourneyInk.line))
        }.buttonStyle(HeroUIGlassButtonStyle())
    }

    private func routeHeader(_ destination: JourneyPlace) -> some View {
        VStack(spacing: 7) {
            HStack {
                backButton { self.destination = nil; stop = nil; plans = []; demo = false; startedID = nil }
                VStack(spacing: 5) {
                    Text(demo ? "Your location · Concept" : (origin == nil ? "From KL Sentral" : "Your location"))
                        .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 38).journeyCard(22)
                    Text(demo ? "One Utama · East Entrance" : destination.name).font(.subheadline.bold()).lineLimit(2).frame(maxWidth: .infinity, minHeight: 42).journeyCard(22)
                }.frame(maxWidth: .infinity)
                let saved = history.saved.contains { $0.id == destination.id }
                Button { history.toggleSaved(destination) } label: {
                    Image(systemName: saved ? "heart.fill" : "heart").frame(width: 44, height: 44).journeyCard(22)
                }.accessibilityLabel(saved ? "Remove saved place" : "Save place")
            }
            HStack(spacing: 10) {
                Text("Drive").foregroundStyle(JourneyInk.blue).padding(.horizontal, 30).frame(minHeight: 32)
                    .background(JourneyInk.sky, in: Capsule()).overlay(Capsule().strokeBorder(Color.blue.opacity(0.35)))
                if demo {
                    Button("Ride options") { sheet = .ride }.padding(.horizontal, 17).frame(minHeight: 32).journeyCard(18)
                }
            }.font(.caption.weight(.semibold))
        }.padding(.horizontal, 6)
    }

    private var routePanel: some View {
        VStack(spacing: 8) {
            Capsule().fill(JourneyInk.blue.opacity(0.8)).frame(width: 34, height: 4)
            Text("Choose your route").font(.title3.bold())
            Button(avoidTolls ? "Show all routes" : "Avoid tolls") { avoidTolls.toggle() }.font(.caption.weight(.semibold))
            if calculating {
                ProgressView("Finding routes…").padding()
            } else if let plan {
                HStack(spacing: 6) {
                    ForEach(Array(plans.enumerated()), id: \.element.id) { index, option in
                        Button { planIndex = index } label: {
                            VStack(spacing: 3) {
                                Text(optionTitle(index, option)).font(.caption2.weight(.semibold))
                                Text(shortTime(option.duration)).font(.headline.bold())
                                Text("\(JourneyFormat.distance(option.distance)) · \(option.name)").lineLimit(1).font(.caption2)
                                Text(demo ? sampleFare(option) : (option.hasTolls ? "Includes tolls" : "No tolls"))
                                    .font(.caption2.weight(.semibold)).foregroundStyle(JourneyInk.blue)
                            }
                            .padding(.vertical, 9).frame(maxWidth: .infinity)
                            .background(index == planIndex ? JourneyInk.sky : .white, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(index == planIndex ? .blue : JourneyInk.line, lineWidth: index == planIndex ? 2 : 1))
                        }.buttonStyle(HeroUIGlassButtonStyle()).accessibilityAddTraits(index == planIndex ? .isSelected : [])
                    }
                }
                if demo && plan.hasTolls {
                    Button { sheet = .details } label: {
                        VStack(spacing: 4) {
                            Label("Traffic now · +8 min delay", systemImage: "trafficlight").font(.caption.weight(.semibold))
                            HStack(spacing: 2) {
                                ForEach(Array([Color.green, .orange, .red, .green].enumerated()), id: \.offset) { _, c in
                                    Capsule().fill(c).frame(height: 4)
                                }
                            }.padding(.horizontal, 30)
                            Text("Slow section · Sample traffic").font(.caption2).foregroundStyle(.secondary)
                        }.padding(8).frame(maxWidth: .infinity).journeyCard(16)
                    }.buttonStyle(HeroUIGlassButtonStyle())
                }
                Button { sheet = .details } label: {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Along your route").font(.subheadline.weight(.semibold))
                            Spacer(); Text("View details").font(.caption.weight(.semibold)).foregroundStyle(JourneyInk.blue)
                        }
                        if demo {
                            HStack {
                                metric("8 lights", "trafficlight")
                                metric("2 AES", "camera")
                                metric(plan.hasTolls ? "Rain likely" : "Dry forecast", plan.hasTolls ? "cloud.rain" : "sun.max")
                            }
                            HStack {
                                Text(plan.hasTolls ? "1 toll plaza" : "No tolls").font(.caption)
                                Spacer()
                                if plan.hasTolls {
                                    ForEach(["JourneyPayTNG", "JourneyPayRFID", "JourneyPayMC", "JourneyPayVisa"], id: \.self) { mark in
                                        Image(mark).resizable().scaledToFit().frame(width: mark == "JourneyPayRFID" ? 44 : 30, height: 15)
                                            .accessibilityHidden(true)
                                    }
                                }
                            }
                        } else {
                            Text(plan.name).font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }.padding(11).journeyCard(17)
                }.buttonStyle(HeroUIGlassButtonStyle())
                Button { stopDetailName = nil; sheet = .stops } label: {
                    HStack {
                        Image(systemName: "signpost.right")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stop?.name ?? (demo ? "2 R&R options to review" : "Find rest stops")).font(.subheadline.weight(.semibold))
                            Text(stop != nil ? "Added to your route" : (demo ? "R&R USJ · 42 spaces · Low crowd" : "Search near your route"))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer(); Image(systemName: "chevron.right").font(.caption)
                    }.padding(10).journeyCard(16)
                }.buttonStyle(HeroUIGlassButtonStyle())
                HStack(spacing: 8) {
                    Button(demo ? "Toll details" : "Steps") { sheet = .details }
                        .frame(maxWidth: .infinity, minHeight: 44).journeyCard(24)
                    Button(demo ? "Start · \(shortTime(plan.duration))" : "Preview route") {
                        if demo, startedID == nil { startedID = history.start(plan, to: destination ?? .oneUtama, demo: true) }
                        driving = true
                    }.frame(maxWidth: .infinity, minHeight: 44).background(Color(red: 0.31, green: 0.70, blue: 0.99), in: Capsule())
                }.font(.subheadline.bold())
                if !demo {
                    Button(stop == nil ? "Start navigation in Apple Maps" : "Navigate to stop in Apple Maps", action: openMaps)
                        .font(.subheadline.weight(.semibold)).frame(minHeight: 38)
                }
            } else if let routeIssue {
                Text(routeIssue).font(.subheadline).multilineTextAlignment(.center).padding(5)
                HStack {
                    Button("Retry") { attempts += 1 }
                    if stop != nil { Button("Remove stop") { stop = nil } }
                    Button("One Utama concept") { choose(.oneUtama) }
                }.font(.footnote.weight(.semibold))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12).journeyPanel()
    }

    private func metric(_ name: String, _ icon: String) -> some View {
        Label(name, systemImage: icon).font(.caption2.weight(.semibold)).lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 25).background(JourneyInk.sky, in: RoundedRectangle(cornerRadius: 8))
    }

    private func backButton(action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: "chevron.left").frame(width: 44, height: 44).journeyCard(22) }
            .accessibilityLabel("Back")
    }

    private func setQuery(_ value: String) { query = value; savedOnly = false; typing = false }

    private func choose(_ place: JourneyPlace) {
        typing = false
        demo = place.id == JourneyPlace.oneUtama.id
        destination = place; stop = nil; avoidTolls = false; planIndex = 0; plans = []; routeIssue = nil; startedID = nil
        history.visit(place)
    }

    private func search(_ value: String) async {
        results = []; searchIssue = nil; searching = !value.isEmpty
        guard !value.isEmpty else { return }
        do {
            try await Task.sleep(for: .milliseconds(350))
            let found = try await JourneyService.search(value, around: region)
            try Task.checkCancellation()
            results = found
        } catch {
            guard !Task.isCancelled else { return }
            searchIssue = "Search is unavailable. Check the connection and try again."
        }
        searching = false
    }

    private func route() async {
        guard let destination else { return }
        planIndex = 0; routeIssue = nil
        if demo {
            plans = JourneyPlan.samples(via: stop, avoidingTolls: avoidTolls)
            calculating = false
            if openStopsAfterRouting {
                openStopsAfterRouting = false
                sheet = .stops
            }
            return
        }
        calculating = true; plans = []
        do {
            let options = try await JourneyService.routes(from: source, to: destination, via: stop, avoidingTolls: avoidTolls)
            try Task.checkCancellation()
            plans = Array(options.prefix(3))
            if plans.isEmpty { routeIssue = "Apple Maps has no driving route for this journey." }
        } catch {
            guard !Task.isCancelled else { return }
            routeIssue = "Directions are unavailable for this journey. Check the connection or choose another destination."
        }
        calculating = false
    }

    private func openMaps() {
        guard let destination, let plan, !demo else { return }
        let target = stop ?? destination
        let sourceItem = origin == nil ? source.mapItem : MKMapItem.forCurrentLocation()
        let success = MKMapItem.openMaps(with: [sourceItem, target.mapItem], launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
        if success {
            if startedID == nil { startedID = history.start(plan, to: destination) }
        } else { mapsIssue = true }
    }

    private func optionTitle(_ index: Int, _ option: JourneyPlan) -> String {
        if demo { return option.name == "LDP" ? "Recommended" : (option.hasTolls ? "Less toll" : "No toll") }
        return index == 0 ? "Recommended" : "Alternative \(index)"
    }
    private func sampleFare(_ option: JourneyPlan) -> String {
        "RM" + (option.name == "LDP" ? "9.60" : (option.hasTolls ? "2.20" : "0.00")) + " toll"
    }
    private func shortTime(_ duration: TimeInterval) -> String {
        JourneyFormat.time(duration).replacingOccurrences(of: " min", with: duration >= 3600 ? "" : " min")
    }
}

private enum JourneySheet: String, Identifiable {
    case details, stops, ride, road
    var id: Self { self }
}

struct JourneyMap: View {
    let region: MKCoordinateRegion
    let plans: [JourneyPlan]
    let selected: JourneyPlan?
    let source: JourneyPlace
    let destination: JourneyPlace?
    let stop: JourneyPlace?
    let style: String
    let night: Bool
    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position) {
            UserAnnotation()
            Marker(source.name, coordinate: source.coordinate).tint(.teal)
            if let destination { Marker(destination.name, coordinate: destination.coordinate).tint(.blue) }
            if let stop { Marker(stop.name, systemImage: "signpost.right", coordinate: stop.coordinate).tint(.orange) }
            ForEach(plans.filter { $0.id != selected?.id }) { option in
                ForEach(option.paths.indices, id: \.self) { i in
                    MapPolyline(option.paths[i]).stroke(.gray.opacity(0.65), lineWidth: 4)
                }
            }
            if let selected {
                ForEach(selected.paths.indices, id: \.self) { i in
                    MapPolyline(selected.paths[i]).stroke(.blue, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .mapStyle(.standard(elevation: style == "Daylight" ? .flat : .realistic, emphasis: style == "Terrain" ? .muted : .automatic))
        .environment(\.colorScheme, night ? .dark : .light)
        .onChange(of: selected?.id, initial: true) { _, _ in
            if let rect = selected?.bounds, !rect.isNull {
                // Leave room beneath the polyline for the route chooser.
                let w = max(1800, rect.width), h = max(1800, rect.height)
                position = .rect(MKMapRect(x: rect.midX - w * 0.8, y: rect.minY - h * 0.8, width: w * 1.6, height: h * 4))
            } else { position = .region(region) }
        }
    }
}
