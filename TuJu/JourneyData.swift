import CoreLocation
import Foundation
import MapKit

struct JourneyPlace: Identifiable, Codable, Hashable {
    var name: String
    var subtitle: String
    var latitude: Double
    var longitude: Double

    var id: String { "\(name.lowercased())|\(Int((latitude * 10000).rounded()))|\(Int((longitude * 10000).rounded()))" }
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    var mapItem: MKMapItem {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = name
        return item
    }

    static let klSentral = Self(name: "KL Sentral", subtitle: "Brickfields · Kuala Lumpur", latitude: 3.1342, longitude: 101.6861)
    static let oneUtama = Self(name: "One Utama", subtitle: "East Entrance · Petaling Jaya", latitude: 3.1492, longitude: 101.6155)
    static let suggestions = [oneUtama, klSentral, Self(name: "Suria KLCC", subtitle: "Kuala Lumpur City Centre", latitude: 3.1576, longitude: 101.7122)]

    init(name: String, subtitle: String, latitude: Double, longitude: Double) {
        self.name = name
        self.subtitle = subtitle
        self.latitude = latitude
        self.longitude = longitude
    }

    init?(_ item: MKMapItem) {
        guard let name = item.name, !name.isEmpty, CLLocationCoordinate2DIsValid(item.placemark.coordinate) else { return nil }
        self.init(name: name, subtitle: [item.placemark.thoroughfare, item.placemark.locality].compactMap { $0 }.joined(separator: " · "),
                  latitude: item.placemark.coordinate.latitude, longitude: item.placemark.coordinate.longitude)
    }
}

struct JourneyTrip: Identifiable, Codable {
    var id: UUID
    var destination: JourneyPlace
    var date: Date
    var distance: Double
    var duration: TimeInterval
    var isDemo: Bool
}

@MainActor
final class JourneyHistory: ObservableObject {
    static let shared = JourneyHistory()
    @Published private(set) var recent: [JourneyPlace]
    @Published private(set) var saved: [JourneyPlace]
    @Published private(set) var trips: [JourneyTrip]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        func read<T: Decodable>(_ key: String, _ type: T.Type) -> T? {
            defaults.data(forKey: "tuju.journey." + key).flatMap { try? JSONDecoder().decode(type, from: $0) }
        }
        recent = read("recent", [JourneyPlace].self) ?? []
        saved = read("saved", [JourneyPlace].self) ?? []
        trips = read("trips", [JourneyTrip].self) ?? []
    }

    func visit(_ place: JourneyPlace) {
        recent = [place] + recent.filter { $0.id != place.id }.prefix(11)
        write(recent, to: "recent")
    }

    func toggleSaved(_ place: JourneyPlace) {
        if saved.contains(where: { $0.id == place.id }) { saved.removeAll { $0.id == place.id } }
        else { saved.insert(place, at: 0) }
        write(saved, to: "saved")
    }

    func start(_ plan: JourneyPlan, to place: JourneyPlace, demo: Bool = false) -> UUID {
        let id = UUID()
        let trip = JourneyTrip(id: id, destination: place, date: .now, distance: plan.distance, duration: plan.duration, isDemo: demo)
        trips = [trip] + trips.prefix(99)
        write(trips, to: "trips")
        return id
    }

    private func write<T: Encodable>(_ value: T, to key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: "tuju.journey." + key) }
    }
}

struct JourneyStep: Identifiable {
    let id = UUID()
    let instruction: String
    let distance: Double
    let path: MKPolyline?
}

struct JourneyPlan: Identifiable {
    let id = UUID()
    var name: String
    var distance: Double
    var duration: TimeInterval
    var hasTolls: Bool
    var paths: [MKPolyline]
    var steps: [JourneyStep]
    var notices: [String]

    init(legs: [MKRoute]) {
        name = legs.map(\.name).filter { !$0.isEmpty }.joined(separator: " → ")
        distance = legs.reduce(0) { $0 + $1.distance }
        duration = legs.reduce(0) { $0 + $1.expectedTravelTime }
        hasTolls = legs.contains(where: \.hasTolls)
        paths = legs.map(\.polyline)
        notices = legs.flatMap(\.advisoryNotices)
        steps = legs.flatMap { route in
            route.steps.compactMap { step in
                guard !step.instructions.isEmpty else { return nil }
                return JourneyStep(instruction: step.instructions, distance: step.distance, path: step.polyline)
            }
        }
    }

    static func samples(via stop: JourneyPlace?, avoidingTolls: Bool) -> [Self] {
        let samples = [("LDP", 55.0, 72.0, true), ("MEX", 63.0, 85.0, true), ("MRR2", 76.0, 105.0, false)]
        return samples.filter { !avoidingTolls || !$0.3 }.map { road, km, minutes, tolls in
            var plan = Self(legs: [])
            plan.name = road
            plan.distance = (km + (stop == nil ? 0 : 3)) * 1000
            plan.duration = (minutes + (stop == nil ? 0 : 8)) * 60
            plan.hasTolls = tolls
            var instructions = [("Continue straight", 1500.0), ("Keep left at the exit", 800.0)]
            if let stop { instructions.append(("Take the exit for \(stop.name)", 600)) }
            instructions.append(("Arrive at One Utama", 150))
            plan.steps = instructions.map { JourneyStep(instruction: $0.0, distance: $0.1, path: nil) }
            return plan
        }
    }

    func estimate(atStep index: Int) -> JourneyEstimate {
        let intervals = max(1, steps.count - 1)
        let progress = min(1, max(0, Double(index) / Double(intervals)))
        return JourneyEstimate(distance: distance * (1 - progress), duration: duration * (1 - progress),
                               progress: progress, sampleArrival: JourneyFormat.sampleArrival(after: duration))
    }

    var bounds: MKMapRect {
        paths.reduce(MKMapRect.null) { $0.union($1.boundingMapRect) }
    }
}

enum JourneyService {
    static func search(_ query: String, around region: MKCoordinateRegion) async throws -> [JourneyPlace] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        request.resultTypes = [.address, .pointOfInterest]
        let search = MKLocalSearch(request: request)
        let response = try await withTaskCancellationHandler {
            try await search.start()
        } onCancel: { search.cancel() }
        var seen = Set<String>()
        return response.mapItems.compactMap(JourneyPlace.init).filter { seen.insert($0.id).inserted }
    }

    static func routes(from origin: JourneyPlace, to destination: JourneyPlace, via stop: JourneyPlace?, avoidingTolls: Bool) async throws -> [JourneyPlan] {
        func leg(_ from: JourneyPlace, _ to: JourneyPlace, alternatives: Bool) async throws -> [MKRoute] {
            let request = MKDirections.Request()
            request.source = from.mapItem
            request.destination = to.mapItem
            request.transportType = .automobile
            request.requestsAlternateRoutes = alternatives
            request.tollPreference = avoidingTolls ? .avoid : .any
            let directions = MKDirections(request: request)
            let response = try await withTaskCancellationHandler {
                try await directions.calculate()
            } onCancel: { directions.cancel() }
            return response.routes.sorted { $0.expectedTravelTime < $1.expectedTravelTime }
        }
        guard let stop else { return try await leg(origin, destination, alternatives: true).map { JourneyPlan(legs: [$0]) } }
        guard let first = try await leg(origin, stop, alternatives: false).first else { return [] }
        try Task.checkCancellation()
        guard let second = try await leg(stop, destination, alternatives: false).first else { return [] }
        return [JourneyPlan(legs: [first, second])]
    }

    static func stops(along plan: JourneyPlan) async throws -> [JourneyPlace] {
        var results: [JourneyPlace] = []
        var seen = Set<String>()
        var successes = 0
        for path in plan.paths {
            guard path.pointCount > 1 else { continue }
            // A narrow search along the selected road avoids unrelated stops across the city.
            for fraction in [0.25, 0.65] {
                try Task.checkCancellation()
                let center = path.points()[Int(Double(path.pointCount - 1) * fraction)].coordinate
                let region = MKCoordinateRegion(center: center, latitudinalMeters: 18000, longitudinalMeters: 18000)
                do {
                    let found = try await search("R&R rest area", around: region)
                    let nearRoute = found.filter { candidate in
                        distanceToPath(MKMapPoint(candidate.coordinate), path: path) < 3500
                    }
                    results += nearRoute.filter { seen.insert($0.id).inserted }
                    successes += 1
                } catch {
                    try Task.checkCancellation()
                    if let error = error as? MKError, error.code == .placemarkNotFound { successes += 1 }
                }
            }
        }
        if successes == 0 { throw URLError(.cannotLoadFromNetwork) }
        return results
    }

    static func distanceToPath(_ point: MKMapPoint, path: MKPolyline) -> Double {
        guard path.pointCount > 1 else { return .infinity }
        let points = path.points()
        var closest = Double.infinity
        for index in 1..<path.pointCount {
            let a = points[index - 1], b = points[index]
            let dx = b.x - a.x, dy = b.y - a.y
            let length = dx * dx + dy * dy
            guard length > 0 else { continue }
            let t = min(1, max(0, ((point.x - a.x) * dx + (point.y - a.y) * dy) / length))
            let projected = MKMapPoint(x: a.x + t * dx, y: a.y + t * dy)
            closest = min(closest, point.distance(to: projected))
        }
        return closest
    }
}

struct JourneyEstimate {
    let distance: Double
    let duration: TimeInterval
    let progress: Double
    let sampleArrival: String
}

enum JourneyFormat {
    static func time(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int((seconds / 60).rounded()))
        return minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
    }

    // The concept starts at the 9:41 AM departure shown on the design board.
    static func sampleArrival(after duration: TimeInterval) -> String {
        let clockMinutes = (9 * 60 + 41 + Int((duration / 60).rounded())) % (24 * 60)
        let hour = clockMinutes / 60
        let minute = String(format: "%02d", clockMinutes % 60)
        return "\(hour % 12 == 0 ? 12 : hour % 12):\(minute) " + (hour < 12 ? "AM" : "PM")
    }

    static func distance(_ meters: Double) -> String {
        if meters < 1000 { return "\(Int(meters.rounded())) m" }
        return "\((meters / 1000).formatted(.number.precision(.fractionLength(0...1)))) km"
    }
}
