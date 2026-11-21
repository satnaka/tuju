import CoreLocation
import MapKit
import SwiftUI

enum TuJuTab: String, CaseIterable {
    case home = "Home", map = "Map", trips = "Trips", profile = "Profile"

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .map: "map.fill"
        case .trips: "car.fill"
        case .profile: "person.crop.circle.fill"
        }
    }
}

struct TuJuTabBar: View {
    let selected: TuJuTab
    let onSelect: (TuJuTab) -> Void
    @State private var controlHeight: CGFloat = 56
    @State private var useSwiftUITabs = false

    var body: some View {
        Group {
            if useSwiftUITabs {
                nativeTabs
            } else {
                ReactNativeControlSurface(
                    state: HeroUIState(surface: "tabs", selected: selected.rawValue),
                    onAction: { action in
                        if let tab = TuJuTab.allCases.first(where: { "tab" + $0.rawValue == action }) {
                            onSelect(tab)
                        }
                    },
                    onHeight: { controlHeight = $0 },
                    onUnavailable: { useSwiftUITabs = true }
                )
                .frame(height: controlHeight)
            }
        }
        .heroGlass(.floating, radius: controlHeight / 2)
        .frame(maxWidth: 440)
        .padding(.horizontal, 15)
    }

    private var nativeTabs: some View {
        HStack(spacing: 0) {
            ForEach(TuJuTab.allCases, id: \.self) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.icon).font(.system(size: 22, weight: .semibold))
                        Text(tab.rawValue).font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(tab == selected ? JourneyInk.blue : Color.tujuInk)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(tab == selected ? JourneyInk.blue.opacity(0.12) : .clear, in: Capsule())
                }
                .accessibilityAddTraits(tab == selected ? .isSelected : [])
            }
        }
        .padding(4)
        .buttonStyle(.plain)
    }
}

private enum HomeSheet: String, Identifiable {
    case profile, rewards, layers, saved, home, work
    var id: Self { self }
}

private struct JourneyLaunch: Identifiable {
    let id = UUID()
    var query = ""
    var destination: JourneyPlace?
    var showStops = false
    var previewConcept = false
}

struct RootView: View {
    @State private var tab = TuJuTab.home
    @State private var sheet: HomeSheet?
    @State private var launch: JourneyLaunch?
    @State private var pendingLaunch: JourneyLaunch?
    @State private var pendingTab: TuJuTab?
    @State private var cardExpanded = true
    @State private var panelHeight: CGFloat = 289
    @State private var useSwiftUIPanel = false
    @State private var camera: MapCameraPosition = .region(Self.kualaLumpur)
    @State private var visibleRegion = Self.kualaLumpur
    @State private var configuredCamera = false
    @State private var locateRequest: UUID?
    @State private var locateIssue: ExploreLocationIssue?
    @StateObject private var location = ExploreLocation()
    @ObservedObject private var history = JourneyHistory.shared
    @EnvironmentObject private var session: TuJuSession
    @AppStorage("tuju.displayName") private var localName = ""
    private var name: String { session.displayName ?? (localName.isEmpty ? "Guest" : localName) }
    @AppStorage("tuju.mapStyle") private var mapStyle = "Daylight"
    @AppStorage("tuju.mapTheme") private var theme = "TuJu Blue"
    @AppStorage(TuJuRewardsLedger.storageKey) private var ledger = Data()
    @AppStorage("tuju.homePlace") private var homeData = Data()
    @AppStorage("tuju.workPlace") private var workData = Data()

    private static let kualaLumpur = MKCoordinateRegion(center: .init(latitude: 3.150, longitude: 101.707),
                                                      latitudinalMeters: 4500, longitudinalMeters: 4500)
    private var xp: Int { TuJuRewardsLedger.decode(ledger)?.xp ?? 120 }
    private var recent: JourneyPlace { history.recent.first ?? .klSentral }

    var body: some View {
        GeometryReader { viewport in
            mapAndControls(panelLimit: max(110, viewport.size.height - 245))
        }
        .tujuLightChrome()
        .buttonStyle(.plain)
        .sheet(item: $sheet, onDismiss: {
            if let pendingLaunch { launch = pendingLaunch; self.pendingLaunch = nil }
        }) { section in
            switch section {
            case .profile: TuJuProfileView()
            case .rewards: TuJuRewardsView()
            case .layers: TuJuMapAppearanceView()
            case .home, .work, .saved:
                PlaceCollectionView(title: section == .saved ? "Saved places" : "Choose " + section.rawValue,
                                    places: collection(for: section),
                                    isSaved: section == .saved,
                                    select: { place in select(place, for: section) },
                                    browse: {
                                        pendingLaunch = JourneyLaunch()
                                        sheet = nil
                                    })
            }
        }
        .fullScreenCover(item: $launch, onDismiss: {
            if let pendingTab { self.pendingTab = nil; selectTab(pendingTab) }
        }) { request in
            JourneyView(initialQuery: request.query, location: location, searchRegion: visibleRegion,
                        initialDestination: request.destination, showStopsInitially: request.showStops,
                        previewConcept: request.previewConcept, onTab: { newTab in
                            pendingTab = newTab
                            launch = nil
                        }, onClose: { launch = nil })
        }
        .onAppear {
            guard !configuredCamera else { return }
            configuredCamera = true
            if location.isAuthorized {
                camera = .userLocation(followsHeading: false, fallback: .region(visibleRegion))
            }
        }
        .task(id: locateRequest) {
            guard let request = locateRequest else { return }
            do {
                let fix = try await location.currentFix()
                guard !Task.isCancelled, locateRequest == request else { return }
                let nearby = MKCoordinateRegion(center: fix.coordinate, latitudinalMeters: 2200, longitudinalMeters: 2200)
                camera = .userLocation(followsHeading: false, fallback: .region(nearby))
            } catch let issue as ExploreLocationIssue {
                guard !Task.isCancelled, locateRequest == request else { return }
                locateIssue = issue
            } catch {}
            if locateRequest == request { locateRequest = nil }
        }
        .alert(item: $locateIssue) { issue in
            Alert(title: Text("Location unavailable"), message: Text(issue.localizedDescription), dismissButton: .default(Text("OK")))
        }
    }

    private var liveMap: some View {
        Map(position: $camera) {
            if location.isAuthorized { UserAnnotation { TuJuVehicleMarker() } }
            ForEach(JourneyPlace.suggestions) { place in
                Annotation(place.name, coordinate: place.coordinate) {
                    Button { launch = JourneyLaunch(destination: place) } label: {
                        Image(systemName: "mappin.circle.fill").font(.title).foregroundStyle(.white, .blue)
                    }.accessibilityLabel(place.name)
                }
            }
        }
        .mapStyle(mapStyle == "Terrain" ? .hybrid(elevation: .realistic) : .standard(elevation: mapStyle == "Default 3D" ? .realistic : .flat))
        .onMapCameraChange(frequency: .onEnd) { context in
            visibleRegion = context.region
            if camera.positionedByUser { locateRequest = nil }
        }
        .tujuMapColors(theme: theme)
        .ignoresSafeArea()
    }

    private func mapAndControls(panelLimit: CGFloat) -> some View {
        ZStack {
            if tab == .trips {
                TripHistoryView(trips: history.trips) { place, isDemo in
                    launch = JourneyLaunch(destination: place, previewConcept: isDemo)
                }
            } else {
                liveMap
                VStack(spacing: 0) {
                    categories.padding(.horizontal, 18).padding(.top, 10)
                    Spacer(minLength: 4)
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            floatingButton("HomeLayers", "Map appearance") { sheet = .layers }
                            floatingButton("HomeLocate", "Show my location", loading: locateRequest != nil) {
                                locateRequest = UUID()
                            }
                            .accessibilityValue(locateRequest != nil ? "Locating" : camera.followsUserLocation ? "Following your location" : "Exploring map")
                        }
                        .heroGlassGroup()
                    }.padding(.horizontal, 18).padding(.bottom, 20)
                    if tab == .home { journeyControls(maxHeight: panelLimit) }
                    else {
                        Button { launch = JourneyLaunch() } label: {
                            searchField.heroGlass(.control, radius: 24)
                        }
                        .frame(maxWidth: 480)
                        .padding(.horizontal, 18)
                        .accessibilityLabel("Search places or addresses")
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 10) {
            TuJuTabBar(selected: tab, onSelect: selectTab)
                .padding(.bottom, 4)
        }
    }

    private var categories: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    rewardsButton
                    category("R&R", image: "HomeRest")
                    category("Food", image: "HomeFood")
                    category("Fuel", image: "HomeFuel")
                }
                .heroGlassGroup()
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            Button { sheet = .profile } label: {
                Text(String(name.prefix(1)).uppercased()).fontWeight(.semibold)
                    .frame(width: 44, height: 44)
                    .heroGlass(.control, radius: 22)
            }
            .accessibilityLabel("Profile")
            .help("Profile")
        }
        .foregroundStyle(Color.tujuInk)
        .frame(height: 52)
    }

    private var rewardsButton: some View {
        Button { sheet = .rewards } label: {
            HStack(spacing: 3) {
                ZStack {
                    Image("HomeRewardTrack").resizable()
                    if xp == 120 {
                        Image("HomeRewardProgress").resizable()
                            .frame(width: 4.86, height: 2.50).offset(x: 2.43, y: -12.72)
                    } else {
                        Circle().inset(by: 0.8)
                            .trim(from: 0, to: min(1, CGFloat(xp) / 2000))
                            .stroke(Color.blue, lineWidth: 1.6).rotationEffect(.degrees(-90))
                    }
                    Image("HomeTrophy").resizable().scaledToFit().frame(width: 21, height: 21)
                }.frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Rewards").font(.system(size: 11, weight: .semibold))
                    Text("\(xp) / 2K XP").font(.system(size: 9)).monospacedDigit()
                }
            }.padding(.horizontal, 7).frame(minHeight: 44).heroGlass(.control, radius: 22)
        }
    }

    private func category(_ title: String, image: String) -> some View {
        Button { launch = JourneyLaunch(query: title) } label: {
            HStack(spacing: 3) {
                Image(image).resizable().scaledToFit().frame(width: 17, height: 17)
                Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
            }.padding(.horizontal, 6).frame(minWidth: 44, minHeight: 44).heroGlass(.control, radius: 22)
        }
    }

    private func floatingButton(_ asset: String, _ title: String, loading: Bool = false,
                                action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if loading { ProgressView().controlSize(.small) }
                else { Image(asset).resizable().scaledToFit().frame(width: 22, height: 22) }
            }
            .frame(width: 46, height: 46)
            .heroGlass(.control, radius: 23)
        }.accessibilityLabel(title).help(title).disabled(loading)
    }

    private var recentDetail: String {
        history.recent.isEmpty ? "Suggested destination · Kuala Lumpur" : recent.subtitle
    }

    private func journeyControls(maxHeight: CGFloat) -> some View {
        Group {
            if useSwiftUIPanel {
                exploreCard
            } else {
                ReactNativeControlSurface(
                    state: HeroUIState(surface: "journey", expanded: cardExpanded, recentName: recent.name,
                                       recentDetail: recentDetail),
                    onAction: performHomeAction,
                    onHeight: { panelHeight = $0 },
                    onUnavailable: { useSwiftUIPanel = true }
                )
                .frame(height: min(panelHeight, maxHeight))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .heroGlass(.floating, radius: 30)
        .frame(maxWidth: 480)
        .padding(.horizontal, 10)
    }

    private func performHomeAction(_ action: String) {
        switch action {
        case "toggle": cardExpanded.toggle()
        case "search": launch = JourneyLaunch()
        case "home": openShortcut(.home, data: homeData)
        case "work": openShortcut(.work, data: workData)
        case "changeHome": sheet = .home
        case "changeWork": sheet = .work
        case "saved": sheet = .saved
        case "recent": launch = JourneyLaunch(destination: recent)
        case "stops": launch = JourneyLaunch(destination: .oneUtama, showStops: true)
        default: break
        }
    }

    private func openShortcut(_ section: HomeSheet, data: Data) {
        if let place = try? JSONDecoder().decode(JourneyPlace.self, from: data) {
            launch = JourneyLaunch(destination: place)
        } else { sheet = section }
    }

    private var exploreCard: some View {
        VStack(spacing: 9) {
            Button { withAnimation { cardExpanded.toggle() } } label: {
                VStack(spacing: 9) {
                    Capsule().fill(Color.blue.opacity(0.85)).frame(width: 34, height: 4)
                    Text("Where are we going?").font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(Color.tujuNavy).frame(minHeight: 30)
                }.frame(maxWidth: .infinity)
            }.accessibilityHint(cardExpanded ? "Collapse journey panel" : "Expand journey panel")
            Button { launch = JourneyLaunch() } label: {
                searchField.background(.quaternary, in: Capsule())
            }
            if cardExpanded {
                HStack(spacing: 8) {
                    shortcut("Home", asset: "HomeHouse", section: .home, data: homeData)
                    shortcut("Work", asset: "HomeWork", section: .work, data: workData)
                    shortcut("Saved", asset: "HomeSaved", section: .saved, data: Data())
                }
                Button { launch = JourneyLaunch(destination: recent) } label: {
                    placeRow(asset: "HomeRecent", name: recent.name, detail: recentDetail)
                }
                Button { launch = JourneyLaunch(destination: .oneUtama, showStops: true) } label: {
                    placeRow(asset: "HomeStop", name: "Preview R&R stops", detail: "One Utama concept route · Offline preview")
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .padding(.horizontal, 17).padding(.top, 10).padding(.bottom, 14)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image("HomeSearch").resizable().scaledToFit().frame(width: 20, height: 20)
            Text("Search places or addresses").font(.subheadline)
            Spacer()
        }.foregroundStyle(Color.tujuInk)
            .padding(.horizontal, 15).frame(minHeight: 44)
            .contentShape(Capsule())
    }

    private func placeRow(asset: String, name: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(asset).resizable().scaledToFit().frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(.system(size: 15, weight: .semibold))
                Text(detail).font(.caption).lineLimit(2)
            }
            Spacer(minLength: 0)
        }.frame(minHeight: 40).foregroundStyle(Color.tujuInk).contentShape(Rectangle())
    }

    private func shortcut(_ title: String, asset: String, section: HomeSheet, data: Data) -> some View {
        Button { openShortcut(section, data: data) } label: {
            HStack(spacing: 5) {
                Image(asset).resizable().scaledToFit().frame(width: 19, height: 19)
                Text(title).font(.system(size: 14, weight: .semibold))
            }.foregroundStyle(Color.tujuInk).frame(maxWidth: .infinity, minHeight: 44)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 17))
        }.contextMenu {
            if section != .saved { Button("Change " + section.rawValue + " address") { sheet = section } }
        }
    }

    private func collection(for section: HomeSheet) -> [JourneyPlace] {
        if section == .saved { return history.saved }
        var seen = Set<String>()
        return (history.saved + history.recent + JourneyPlace.suggestions).filter { seen.insert($0.id).inserted }
    }

    private func select(_ place: JourneyPlace, for section: HomeSheet) {
        let encoded = (try? JSONEncoder().encode(place)) ?? Data()
        if section == .home { homeData = encoded }
        if section == .work { workData = encoded }
        pendingLaunch = JourneyLaunch(destination: place)
        sheet = nil
    }

    private func selectTab(_ newTab: TuJuTab) {
        if newTab == .profile { sheet = .profile }
        else { tab = newTab }
    }
}

extension Color {
    static let tujuInk = Color(red: 0.04, green: 0.11, blue: 0.20)
    static let tujuNavy = Color(red: 0.06, green: 0.19, blue: 0.38)
}
