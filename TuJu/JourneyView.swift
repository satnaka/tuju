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
    @ObservedObject var location: ExploreLocation
    let searchRegion: MKCoordinateRegion
    var initialDestination: JourneyPlace? = nil
    var showStopsInitially = false
    var previewConcept = false
    var onTab: ((TuJuTab) -> Void)? = nil
    let onClose: () -> Void

    @ObservedObject private var history = JourneyHistory.shared
    @State private var query = ""
    @State private var destination: JourneyPlace?
    @State private var results: [JourneyPlace] = []
    @State private var searching = false
    @State private var searchIssue: String?
    @State private var searchAttempt = 0
    @State private var savedOnly = false
    @State private var demo = false
    @State private var avoidTolls = false
    @State private var stop: JourneyPlace?
    @State private var plans: [JourneyPlan] = []
    @State private var planIndex = 0
    @State private var calculating = false
    @State private var locating = false
    @State private var openingMaps = false
    @State private var routeIssue: String?
    @State private var attempts = 0
    @State private var sheet: JourneySheet?
    @State private var driving = false
    @State private var choosingMode = false
    @State private var roadEstimate: JourneyEstimate?
    @State private var startedID: UUID?
    @State private var openStopsAfterRouting = false
    @State private var initialized = false
    @State private var mapsIssue = false
    @FocusState private var typing: Bool
    @AppStorage("tuju.mapStyle") private var mapStyle = "Daylight"
    @AppStorage("tuju.mapTheme") private var mapTheme = "TuJu Blue"

    private var queryText: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var plan: JourneyPlan? { plans.indices.contains(planIndex) ? plans[planIndex] : nil }
    private var region: MKCoordinateRegion {
        guard let fix = location.current else { return searchRegion }
        return .init(center: fix.coordinate, latitudinalMeters: 30000, longitudinalMeters: 30000)
    }
    private var routeKey: String { "\(destination?.id ?? "")|\(demo)|\(stop?.id ?? "")|\(avoidTolls)|\(attempts)" }
    private var searchQuery: String { destination == nil && !savedOnly ? queryText : "" }
    private var searchKey: String { "\(searchAttempt)|\(searchQuery)" }

    var body: some View {
        Group {
            if choosingMode, let destination {
                TuJuJourneyChoiceView(destination: destination, pickup: location.current, plan: plan, calculating: calculating,
                                      onDrive: { choosingMode = false }, onBack: returnToSearch, onTab: onTab)
            } else if driving, let plan, let destination {
                JourneyDriveView(plan: plan, destination: destination, demo: demo, onRoad: { estimate in roadEstimate = estimate; sheet = .road },
                                 onDetails: { sheet = .details }, onStops: { sheet = .stops }, onMaps: openMaps,
                                 onExit: { driving = false }, onFinish: {
                    if demo, let startedID { TuJuRewardsLedger.creditCompletedJourney(id: startedID, destination: destination.name) }
                    driving = false
                    if demo { onClose() }
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
                                searchPanel.frame(height: min(448, max(150, bounds.size.height * (typing ? 0.77 : 0.59))))
                            }
                            if !typing, let onTab { TuJuTabBar(selected: destination == nil ? .home : .map, onSelect: onTab) }
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
        .tujuLightChrome()
        .onAppear {
            guard !initialized else { return }
            initialized = true
            query = initialQuery
            if initialQuery.caseInsensitiveCompare("Saved") == .orderedSame { query = ""; savedOnly = true }
            if showStopsInitially || previewConcept {
                openStopsAfterRouting = showStopsInitially
                choose(.oneUtama, concept: true)
            } else if let initialDestination { choose(initialDestination) }
        }
        .onChange(of: query) { _, value in
            if !value.isEmpty { savedOnly = false }
        }
        .onChange(of: location.authorization) { previous, _ in
            if previous != .notDetermined, destination != nil, !demo { attempts += 1 }
        }
        .task(id: searchKey) { await search(searchQuery) }
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
            case .traffic:
                trafficOverview
                    .presentationDetents([.medium, .large])
            case .stops:
                if let plan {
                    JourneyStopsView(plan: plan, demo: demo, selected: stop) { proposed in
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
        if demo {
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
            JourneyMap(region: region, plans: plans, selected: plan, destination: destination, stop: stop,
                       style: mapStyle, theme: mapTheme, showUser: location.isAuthorized)
        }
    }

    private var searchHeader: some View {
        HStack(spacing: 10) {
            backButton(action: onClose)
            HStack(spacing: 12) {
                Image("HomeSearch").resizable().scaledToFit().frame(width: 20, height: 20)
                TextField("Search places or addresses", text: $query)
                    .textInputAutocapitalization(.words).submitLabel(.search).focused($typing)
                    .onSubmit { typing = false }
                if !query.isEmpty {
                    Button { query = ""; savedOnly = false } label: {
                        Image(systemName: "xmark.circle.fill").frame(minWidth: 44, minHeight: 44)
                    }
                        .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 15).frame(minHeight: 46).heroGlass(.floating, radius: 23, focused: typing)
        }
        .heroGlassGroup()
        .padding(.horizontal, 10)
    }

    private var visiblePlaces: [JourneyPlace] {
        if savedOnly { return history.saved }
        return queryText.isEmpty ? history.recent : results
    }

    private var searchPanel: some View {
        VStack(spacing: 8) {
            Capsule().fill(.blue.opacity(0.7)).frame(width: 34, height: 4)
            Text("Find your next destination").font(.title3.bold())
            HStack {
                category("R&R", "HomeRest", active: queryText == "R&R") { setQuery("R&R") }
                category("Fuel", "HomeFuel", active: ["fuel", "petrol station"].contains(queryText.lowercased())) { setQuery("Fuel") }
                category("Saved", "HomeSaved", active: savedOnly) { query = ""; savedOnly = true; typing = false }
                Menu {
                    ForEach(["Petrol", "Parking", "EV Charge", "Hotel", "Hospital", "Food"], id: \.self) { title in
                        Button(title) { setQuery(title) }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44)
                }.accessibilityLabel("More categories")
            }
            let heading = savedOnly ? "Saved places" : (queryText.isEmpty ? "Recent searches" : "Search results")
            Text(heading).font(.subheadline.weight(.semibold))
            ScrollView {
                VStack(spacing: 0) {
                    if searching { ProgressView("Searching Apple Maps…").font(.footnote).padding(.vertical, 6) }
                    ForEach(visiblePlaces.prefix(12)) { place in
                        Button { choose(place) } label: {
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
                        Text(savedOnly ? "Save a destination using its heart button." : (searchIssue ?? (queryText.isEmpty ? "Search Apple Maps for a place or address." : "No places found. Try a different name.")))
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).padding()
                        if searchIssue != nil { Button("Retry search") { searchAttempt += 1 } }
                    }
                    if queryText.isEmpty && !savedOnly {
                        Text("Plan a stop before you go").font(.subheadline.bold()).padding(.vertical, 6)
                        Button {
                            openStopsAfterRouting = true
                            choose(.oneUtama, concept: true)
                        } label: {
                            HStack(spacing: 12) {
                                Image("HomeStop").resizable().scaledToFit().frame(width: 22, height: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Preview R&R stops").font(.subheadline.weight(.semibold))
                                    Text("One Utama concept route · Offline preview").font(.caption)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption)
                            }.padding(12).journeyCard(17)
                        }
                    }
                    Button("Explore the One Utama concept route") { choose(.oneUtama, concept: true) }
                        .font(.footnote.weight(.semibold)).frame(minHeight: 44)
                }
            }.scrollDismissesKeyboard(.interactively)
        }
        .padding(.horizontal, 17).padding(.vertical, 13).journeyPanel()
    }

    private func category(_ title: String, _ icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(icon).resizable().scaledToFit().frame(width: 16, height: 16)
                Text(title)
            }.font(.caption.weight(.semibold)).frame(maxWidth: .infinity)
                .frame(minHeight: 44).background(active ? JourneyInk.line : .white.opacity(0.86), in: Capsule())
                .overlay(Capsule().strokeBorder(JourneyInk.line))
        }.buttonStyle(HeroUIGlassButtonStyle())
    }

    private func routeHeader(_ destination: JourneyPlace) -> some View {
        VStack(spacing: 7) {
            HStack {
                backButton { if demo { returnToSearch() } else { choosingMode = true } }
                VStack(spacing: 5) {
                    Text(demo ? "Sample departure · Concept" : "From your current location")
                        .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 38)
                        .heroGlass(.floating, radius: 22)
                    Text(demo ? "One Utama · East Entrance" : destination.name).font(.subheadline.bold()).lineLimit(2)
                        .frame(maxWidth: .infinity, minHeight: 42).heroGlass(.floating, radius: 22)
                }.frame(maxWidth: .infinity)
                let saved = history.saved.contains { $0.id == destination.id }
                Button { history.toggleSaved(destination) } label: {
                    Image(systemName: saved ? "heart.fill" : "heart").frame(width: 44, height: 44)
                        .heroGlass(.control, radius: 22)
                }.accessibilityLabel(saved ? "Remove saved place" : "Save place")
            }
            HStack(spacing: 10) {
                Text("Drive").foregroundStyle(JourneyInk.blue).padding(.horizontal, 30).frame(minHeight: 32)
                    .background(JourneyInk.sky, in: Capsule()).overlay(Capsule().strokeBorder(Color.blue.opacity(0.35)))
                Button { if demo { sheet = .ride } else { choosingMode = true } } label: {
                        Text(demo ? "Ride options" : "Change travel option").padding(.horizontal, 17).frame(minHeight: 32)
                            .heroGlass(.control, radius: 18)
                            .frame(minHeight: 44).contentShape(Rectangle())
                }
            }.font(.caption.weight(.semibold))
        }.heroGlassGroup().padding(.horizontal, 6)
    }

    private var routePanel: some View {
        VStack(spacing: 8) {
            Capsule().fill(JourneyInk.blue.opacity(0.8)).frame(width: 34, height: 4)
            Text(demo ? "Choose your route" : "Route preview").font(.title3.bold())
            if !demo {
                Button(action: openMaps) {
                    Text(navigationTitle).font(.subheadline.bold()).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 46).background(JourneyInk.blue, in: Capsule())
                }.disabled(openingMaps)
                if #unavailable(iOS 18.4, macCatalyst 18.4), avoidTolls {
                    Text("Select Avoid Tolls in Apple Maps for guidance.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Button(avoidTolls ? "Show all routes" : "Avoid tolls") { avoidTolls.toggle() }.font(.caption.weight(.semibold))
            if calculating {
                ProgressView(locating ? "Getting your location…" : "Finding routes…").padding()
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
                    Button { sheet = .traffic } label: {
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
                Button { sheet = .stops } label: {
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
                if demo {
                    HStack(spacing: 8) {
                        Button("Toll details") { sheet = .details }
                            .frame(maxWidth: .infinity, minHeight: 44).journeyCard(24)
                        Button("Start · \(shortTime(plan.duration))") {
                            if startedID == nil { startedID = history.start(plan, to: .oneUtama, demo: true) }
                            driving = true
                        }.frame(maxWidth: .infinity, minHeight: 44).background(Color(red: 0.31, green: 0.70, blue: 0.99), in: Capsule())
                    }.font(.subheadline.bold())
                } else {
                    Button("Preview route steps") { driving = true }
                        .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                }
            } else if let routeIssue {
                Text(routeIssue).font(.subheadline).multilineTextAlignment(.center).padding(5)
                HStack {
                    Button("Retry") { attempts += 1 }
                    if stop != nil { Button("Remove stop") { stop = nil } }
                    Button("One Utama concept") { choose(.oneUtama, concept: true) }
                }.font(.footnote.weight(.semibold))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12).journeyPanel()
    }

    private func metric(_ name: String, _ icon: String) -> some View {
        Label(name, systemImage: icon).font(.caption2.weight(.semibold)).lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 25).background(JourneyInk.sky, in: RoundedRectangle(cornerRadius: 8))
    }

    private var trafficOverview: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Traffic on your route").font(.title2.bold())
                Text("+8 min").font(.largeTitle.bold()).foregroundStyle(.orange)
                Text("Additional time from traffic").font(.subheadline).foregroundStyle(.secondary)
                VStack(spacing: 8) {
                    Text("Highway section · Slow traffic").font(.headline)
                    Text("A slower section adds about 5 min.").font(.subheadline)
                    Text("Approaching destination · Congestion").font(.headline)
                    Text("Local congestion adds about 3 min.").font(.subheadline)
                }.frame(maxWidth: .infinity).padding().journeyCard()
                Text("Simulated traffic on the One Utama concept route").font(.caption).foregroundStyle(.secondary)
                Button("Back to route choices") { sheet = nil }
                    .font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 48)
                    .background(JourneyInk.blue, in: Capsule())
            }.padding(20)
        }.presentationDragIndicator(.visible)
    }

    private func backButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "chevron.left").frame(width: 44, height: 44).heroGlass(.control, radius: 22)
        }.accessibilityLabel("Back")
    }

    private func setQuery(_ value: String) { query = value; savedOnly = false; typing = false }

    private func returnToSearch() {
        destination = nil; stop = nil; plans = []; driving = false
        demo = false; choosingMode = false; startedID = nil
    }

    private func choose(_ place: JourneyPlace, concept: Bool = false) {
        typing = false
        demo = concept
        choosingMode = !concept
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
            guard searchQuery == value else { return }
            results = found
        } catch {
            guard !Task.isCancelled, searchQuery == value else { return }
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
        calculating = true; locating = true; plans = []
        let key = routeKey
        let fix: CLLocation
        do {
            fix = try await location.currentFix()
            try Task.checkCancellation()
        } catch {
            guard !Task.isCancelled, key == routeKey else { return }
            routeIssue = error.localizedDescription
            calculating = false; locating = false
            return
        }
        guard key == routeKey else { return }
        locating = false
        let source = JourneyPlace(name: "Your location", subtitle: "", latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude)
        do {
            let options = try await JourneyService.routes(from: source, to: destination, via: stop, avoidingTolls: avoidTolls)
            try Task.checkCancellation()
            guard key == routeKey else { return }
            plans = Array(options.prefix(3))
            if plans.isEmpty { routeIssue = "Apple Maps has no driving route for this journey." }
        } catch {
            guard !Task.isCancelled, key == routeKey else { return }
            if let error = error as? MKError, error.code == .directionsNotFound {
                routeIssue = "Apple Maps has no driving route for this journey."
            } else {
                routeIssue = "Directions are unavailable for this journey. Check the connection or choose another destination."
            }
        }
        calculating = false
    }

    private var navigationTitle: String {
        if #unavailable(iOS 18.4, macCatalyst 18.4), let stop { return "Navigate to \(stop.name) first in Apple Maps" }
        return "Start navigation in Apple Maps"
    }

    private func openMaps() {
        guard let destination, !demo, !openingMaps else { return }
        let planAtLaunch = plan
        let key = routeKey
        openingMaps = true
        Task { @MainActor in
            let opened = await JourneyService.openMaps(to: destination, via: stop, avoidingTolls: avoidTolls)
            openingMaps = false
            guard key == routeKey else { return }
            if opened, startedID == nil {
                if #unavailable(iOS 18.4, macCatalyst 18.4), let stop {
                    startedID = history.start(nil, to: stop)
                } else {
                    startedID = history.start(planAtLaunch, to: destination)
                }
            } else if !opened { mapsIssue = true }
        }
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
    case details, traffic, stops, ride, road
    var id: Self { self }
}

struct JourneyMap: View {
    let region: MKCoordinateRegion
    let plans: [JourneyPlan]
    let selected: JourneyPlan?
    let destination: JourneyPlace?
    let stop: JourneyPlace?
    let style: String
    let theme: String
    let showUser: Bool
    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position) {
            if showUser { UserAnnotation { TuJuVehicleMarker() } }
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
        .mapStyle(style == "Terrain" ? .hybrid(elevation: .realistic) : .standard(elevation: style == "Default 3D" ? .realistic : .flat))
        .tujuMapColors(theme: theme)
        .onChange(of: "\(destination?.id ?? "")|\(selected?.id.uuidString ?? "")", initial: true) { _, _ in
            if let rect = selected?.bounds, !rect.isNull {
                // Leave room beneath the polyline for the route chooser.
                let w = max(1800, rect.width), h = max(1800, rect.height)
                position = .rect(MKMapRect(x: rect.midX - w * 0.8, y: rect.minY - h * 0.8, width: w * 1.6, height: h * 4))
            } else if let destination {
                position = .region(.init(center: destination.coordinate, latitudinalMeters: 3500, longitudinalMeters: 3500))
            } else { position = .region(region) }
        }
    }
}
