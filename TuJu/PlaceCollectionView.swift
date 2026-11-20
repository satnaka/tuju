import SwiftUI

struct PlaceCollectionView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let places: [JourneyPlace]
    let isSaved: Bool
    let select: (JourneyPlace) -> Void
    let browse: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if places.isEmpty {
                    ContentUnavailableView("No saved places", systemImage: "star",
                                           description: Text("Save a destination using the heart on its route screen."))
                    Button("Explore places", action: browse)
                } else {
                    Section(isSaved ? "Your destinations" : "Choose a destination for this shortcut") {
                        ForEach(places) { place in
                            Button { select(place) } label: {
                                Label {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(place.name).font(.headline)
                                        Text(place.subtitle).font(.caption).foregroundStyle(.secondary)
                                    }
                                } icon: { Image(systemName: isSaved ? "star.fill" : "mappin.circle") }
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }.presentationDragIndicator(.visible)
    }
}

struct TripHistoryView: View {
    let trips: [JourneyTrip]
    let plan: (JourneyPlace) -> Void
    var body: some View {
        NavigationStack {
            Group {
                if trips.isEmpty {
                    ContentUnavailableView {
                        Label("Your trips", systemImage: "car.fill")
                    } description: {
                        Text("Journeys you start in TuJu will appear here.")
                    } actions: {
                        Button("Preview the One Utama trip") { plan(.oneUtama) }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List(trips) { trip in
                        Button { plan(trip.destination) } label: {
                            HStack {
                                Image(systemName: "car.fill").foregroundStyle(.blue)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(trip.destination.name).font(.headline)
                                    Text((trip.isDemo ? "Concept trip · " : "") + trip.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(String(format: "%.0f km", trip.distance / 1000)).font(.caption)
                            }.padding(.vertical, 6)
                        }
                    }
                }
            }.navigationTitle("Trips").padding(.bottom, 62)
        }.foregroundStyle(Color.tujuNavy)
    }
}
