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

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TuJuTab.allCases, id: \.self) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.icon).font(.system(size: 22, weight: .semibold))
                        Text(tab.rawValue).font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(tab == selected ? Color(red: 0, green: 0.32, blue: 0.61) : .black.opacity(0.9))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(tab == selected ? Color.cyan.opacity(0.16) : .clear, in: Capsule())
                }
                .accessibilityAddTraits(tab == selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule())
        .background(.white.opacity(0.65), in: Capsule())
        .overlay { Capsule().stroke(.white.opacity(0.85), lineWidth: 1) }
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        .buttonStyle(.plain)
        .padding(.horizontal, 15)
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
}

struct RootView: View {
    @State private var tab = TuJuTab.home
    @State private var sheet: HomeSheet?
    @State private var launch: JourneyLaunch?
    @State private var pendingLaunch: JourneyLaunch?
    @State private var cardExpanded = true
    @State private var camera: MapCameraPosition = .region(Self.kualaLumpur)
    @StateObject private var location = ExploreLocation()
    @ObservedObject private var history = JourneyHistory.shared
    @AppStorage("tuju.displayName") private var name = "Amir"
    @AppStorage("tuju.mapStyle") private var mapStyle = "Daylight"
    @AppStorage("tuju.mapTheme") private var theme = "TuJu Blue"
    @AppStorage(TuJuRewardsLedger.storageKey) private var ledger = Data()
    @AppStorage("tuju.homePlace") private var homeData = Data()
    @AppStorage("tuju.workPlace") private var workData = Data()

    private static let kualaLumpur = MKCoordinateRegion(center: .init(latitude: 3.150, longitude: 101.707),
                                                      latitudinalMeters: 4500, longitudinalMeters: 4500)
    private var recent: JourneyPlace { history.recent.first ?? .klSentral }

    var body: some View {
        ZStack {
            if tab == .trips {
                TripHistoryView(trips: history.trips) { place in launch = JourneyLaunch(destination: place) }
            } else {
                if tab == .map {
                    Map(position: $camera) {
                        UserAnnotation()
                        ForEach(JourneyPlace.suggestions) { place in
                            Annotation(place.name, coordinate: place.coordinate) {
                                Button { launch = JourneyLaunch(destination: place) } label: {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.title).foregroundStyle(.white, .blue)
                                }.accessibilityLabel(place.name)
                            }
                        }
                    }
                    .mapStyle(mapStyle == "Terrain" ? .hybrid(elevation: .realistic) : .standard(elevation: mapStyle == "Default 3D" ? .realistic : .flat))
                    .environment(\.colorScheme, theme == "Night Blue" ? .dark : .light)
                    .ignoresSafeArea()
                } else {
                    CityIllustration().ignoresSafeArea()
                }
                VStack(spacing: 0) {
                    categories.padding(.horizontal, 18).padding(.top, 10)
                    Spacer(minLength: 4)
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            floatingButton("HomeLayers", "Map appearance") { sheet = .layers }
                            floatingButton("HomeLocate", "Show my location") {
                                tab = .map
                                location.request()
                            }
                        }
                    }.padding(.horizontal, 18).padding(.bottom, 20)
                    if tab == .home { exploreCard }
                    else {
                        Button { launch = JourneyLaunch() } label: {
                            searchField.padding(.horizontal, 18)
                        }.accessibilityLabel("Search places or addresses")
                    }
                }
                .padding(.bottom, 72)
            }

            VStack {
                Spacer()
                TuJuTabBar(selected: tab, onSelect: selectTab)
            }
        }
        .preferredColorScheme(.light)
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
        .fullScreenCover(item: $launch) { request in
            JourneyView(initialQuery: request.query, origin: location.current?.coordinate,
                        initialDestination: request.destination, showStopsInitially: request.showStops, onTab: { newTab in
                            launch = nil
                            selectTab(newTab)
                        }, onClose: { launch = nil })
        }
        .onChange(of: location.current) { _, value in
            guard let value else { return }
            camera = .region(.init(center: value.coordinate, latitudinalMeters: 2200, longitudinalMeters: 2200))
        }
        .alert("Location unavailable", isPresented: $location.failed) {
            Button("OK") {}
        } message: { Text("You can continue exploring Kuala Lumpur or allow location access in Settings.") }
    }

    private var categories: some View {
        GeometryReader { geo in
            let chipWidth = max(46, min(64, (geo.size.width - 176) / 3))
            HStack(spacing: 6) {
                Button { sheet = .rewards } label: {
                    HStack(spacing: 3) {
                        ZStack {
                            Image("HomeRewardTrack").resizable()
                            Image("HomeRewardProgress").resizable()
                            Image("HomeTrophy").resizable().scaledToFit().padding(4)
                        }.frame(width: 26, height: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Rewards").font(.system(size: 11, weight: .semibold))
                            Text("\(TuJuRewardsLedger.decode(ledger)?.xp ?? 120) / 2K XP").font(.system(size: 9))
                        }
                    }.frame(width: min(102, geo.size.width * 0.28), height: 40).modifier(HomePill())
                }
                category("R&R", image: "HomeRest", query: "R&R", width: chipWidth)
                category("Food", image: "HomeFood", query: "Food", width: chipWidth)
                category("Fuel", image: "HomeFuel", query: "Fuel", width: chipWidth)
                Spacer(minLength: 0)
                Button { sheet = .profile } label: {
                    Text(String(name.prefix(1)).uppercased()).fontWeight(.semibold)
                        .frame(width: 40, height: 40).modifier(HomePill())
                }.accessibilityLabel("Profile")
            }.foregroundStyle(Color.tujuInk)
        }.frame(height: 40)
    }

    private func category(_ title: String, image: String, query: String, width: CGFloat) -> some View {
        Button { launch = JourneyLaunch(query: query) } label: {
            HStack(spacing: 3) {
                Image(image).resizable().scaledToFit().frame(width: 17, height: 17)
                Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
            }.frame(width: width, height: 40).modifier(HomePill())
        }
    }

    private func floatingButton(_ asset: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(asset).resizable().scaledToFit().frame(width: 22, height: 22)
                .frame(width: 46, height: 46)
                .background(.white.opacity(0.96), in: Circle())
                .overlay { Circle().stroke(.cyan.opacity(0.22), lineWidth: 1) }
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        }.accessibilityLabel(title)
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
            Button { launch = JourneyLaunch() } label: { searchField }
            if cardExpanded {
                HStack(spacing: 8) {
                    shortcut("Home", asset: "HomeHouse", section: .home, data: homeData)
                    shortcut("Work", asset: "HomeWork", section: .work, data: workData)
                    shortcut("Saved", asset: "HomeSaved", section: .saved, data: Data())
                }
                Button { launch = JourneyLaunch(destination: recent) } label: {
                    placeRow(asset: "HomeRecent", name: recent.name,
                             detail: history.recent.isEmpty ? "Recent destination · Kuala Lumpur" : recent.subtitle)
                }
                Button { launch = JourneyLaunch(destination: .oneUtama, showStops: true) } label: {
                    placeRow(asset: "HomeStop", name: "Plan your next R&R stop", detail: "Compare crowd & parking information")
                        .padding(.horizontal, 10).padding(.vertical, 7).modifier(HomePill(radius: 16))
                }
            }
        }
        .padding(.horizontal, 17).padding(.top, 10).padding(.bottom, 14)
        .background(LinearGradient(colors: [Color(red: 0.89, green: 0.96, blue: 0.98), Color.white.opacity(0.91)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 27))
        .overlay { RoundedRectangle(cornerRadius: 27).stroke(.white.opacity(0.95), lineWidth: 1.2) }
        .shadow(color: .black.opacity(0.06), radius: 9, y: 4)
        .padding(.horizontal, 10)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image("HomeSearch").resizable().scaledToFit().frame(width: 20, height: 20)
            Text("Search places or addresses").font(.subheadline)
            Spacer()
        }.foregroundStyle(Color(red: 0.25, green: 0.37, blue: 0.49))
            .padding(.horizontal, 15).frame(minHeight: 44)
            .background(LinearGradient(colors: [.white, Color(red: 0.92, green: 0.97, blue: 1)], startPoint: .top, endPoint: .bottom), in: Capsule())
            .overlay { Capsule().stroke(.blue.opacity(0.23), lineWidth: 1) }
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
        Button {
            if let place = try? JSONDecoder().decode(JourneyPlace.self, from: data) {
                launch = JourneyLaunch(destination: place)
            } else { sheet = section }
        } label: {
            HStack(spacing: 5) {
                Image(asset).resizable().scaledToFit().frame(width: 19, height: 19)
                Text(title).font(.system(size: 14, weight: .semibold))
            }.foregroundStyle(Color.tujuInk).frame(maxWidth: .infinity, minHeight: 44).modifier(HomePill(radius: 17))
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

private struct HomePill: ViewModifier {
    var radius: CGFloat = 24
    func body(content: Content) -> some View {
        content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius))
            .background(.white.opacity(0.45), in: RoundedRectangle(cornerRadius: radius))
            .overlay { RoundedRectangle(cornerRadius: radius).stroke(.white.opacity(0.9), lineWidth: 1) }
            .shadow(color: .black.opacity(0.04), radius: 3, y: 2)
    }
}

extension Color {
    static let tujuInk = Color(red: 0.04, green: 0.11, blue: 0.20)
    static let tujuNavy = Color(red: 0.06, green: 0.19, blue: 0.38)
}

private struct CityIllustration: View {
    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width / 402
            let h = geometry.size.height / 874
            ZStack(alignment: .topLeading) {
                Image("KualaLumpurMap").resizable().frame(width: geometry.size.width, height: geometry.size.height)
                label("KUALA LUMPUR", 15, x: 117 * w, y: 196 * h)
                label("Bukit Bintang", 12, x: 214 * w, y: 319 * h)
                label("KLCC", 12, x: 309 * w, y: 221 * h)
                label("Jalan Sultan Ismail", 10, x: 194 * w, y: 267 * h)
                label("Jalan Raja Chulan", 10, x: 36 * w, y: 365 * h)
                label("KL Forest Eco Park", 9, x: 106 * w, y: 281 * h)
                label("Preview location", 11, x: 161 * w, y: 424 * h)
            }
        }.accessibilityHidden(true)
    }
    private func label(_ text: String, _ size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Text(text).font(.system(size: size, weight: .semibold)).foregroundStyle(Color(red: 0.35, green: 0.43, blue: 0.49)).offset(x: x, y: y)
    }
}

private final class ExploreLocation: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var current: CLLocation?
    @Published var failed = false
    private let manager = CLLocationManager()
    private var requested = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    func request() {
        requested = true
        checkPermission()
    }
    private func checkPermission() {
        guard requested else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .notDetermined: manager.requestWhenInUseAuthorization()
        default: requested = false; failed = true
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { checkPermission() }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        requested = false
        current = locations.last
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard requested else { return }
        requested = false
        failed = true
    }
}
