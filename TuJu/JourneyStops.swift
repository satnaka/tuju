import SwiftUI
import MapKit

private struct ConceptStop: Identifiable {
    let name: String
    let capacity: String
    let crowd: String
    let color: Color
    let travel: String
    var id: String { name }
    var place: JourneyPlace { .init(name: name, subtitle: "Concept stop", latitude: 3.14, longitude: 101.62) }

    static let siteA = Self(name: "R&R Sungai Buloh", capacity: "8 / 120 spaces", crowd: "Almost full", color: Color(red: 0.65, green: 0.08, blue: 0.17), travel: "12 km · 15 min")
    static let siteB = Self(name: "R&R USJ", capacity: "42 / 100 spaces", crowd: "Plenty of spaces", color: Color(red: 0.02, green: 0.39, blue: 0.25), travel: "21 km · 25 min")
    static let siteC = Self(name: "R&R Beranang", capacity: "23 spaces", crowd: "Moderate", color: Color(red: 0.60, green: 0.25, blue: 0.02), travel: "27 km · 31 min")
}

struct JourneyStopsView: View {
    let plan: JourneyPlan
    let demo: Bool
    let selected: JourneyPlace?
    var initialName: String? = nil
    let onSelect: (JourneyPlace?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var detail: ConceptStop?
    @State private var compare = false
    @State private var filter = "All stops"
    @State private var rates = false
    @State private var places: [JourneyPlace] = []
    @State private var loading = false
    @State private var failed = false
    @State private var retry = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if demo {
                        Image("JourneyStopMap").resizable().scaledToFill().frame(height: 118).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 22)).accessibilityHidden(true)
                        if let detail, !compare { detailView(detail) } else { conceptList }
                    } else { liveList }
                    if selected != nil {
                        Button("Remove current stop") { onSelect(nil) }.font(.subheadline).frame(minHeight: 44)
                    }
                }.padding(.horizontal, 17).padding(.top, 7).padding(.bottom)
            }
            .background(LinearGradient(colors: [Color(red: 0.84, green: 0.91, blue: 0.99), .white], startPoint: .top, endPoint: .bottom))
            .navigationTitle(compare ? "Alternative stops" : (detail?.name ?? "R&R on your route"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if compare { compare = false }
                        else if detail != nil { detail = nil; rates = false }
                        else { dismiss() }
                    } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Back")
                }
                if demo { ToolbarItem(placement: .topBarTrailing) { Text("Concept").font(.caption2).foregroundStyle(.secondary) } }
            }
            .onAppear {
                if let initialName { detail = initialName == ConceptStop.siteB.name ? .siteB : .siteA }
            }
            .task(id: retry) {
                guard !demo else { return }
                loading = true; failed = false
                do {
                    let found = try await JourneyService.stops(along: plan)
                    try Task.checkCancellation()
                    places = found
                } catch {
                    guard !Task.isCancelled else { return }
                    failed = true
                }
                loading = false
            }
        }.foregroundStyle(JourneyInk.navy).tint(JourneyInk.blue)
    }

    private var conceptList: some View {
        VStack(spacing: 14) {
            VStack(spacing: 12) {
                Capsule().fill(.secondary.opacity(0.25)).frame(width: 36, height: 4)
                Text(compare ? "Compare nearby alternatives" : "Stops along your route").font(.title3.bold())
                if !compare {
                    Text("Parking and crowd conditions").font(.caption).foregroundStyle(.secondary)
                    Picker("Stops", selection: $filter) {
                        ForEach(["All stops", "Low crowd", "Facilities"], id: \.self) { Text($0) }
                    }.pickerStyle(.segmented)
                }
                let stops: [ConceptStop] = compare ? [.siteB, .siteC] : (filter == "Low crowd" ? [.siteB] : [.siteA, .siteB])
                ForEach(stops) { stop in
                    Button {
                        detail = stop; compare = false; rates = false
                    } label: {
                        VStack(alignment: .leading, spacing: 9) {
                            Label(stop.name, systemImage: "mappin").font(.headline)
                            capacity(stop)
                            Text(stop.travel + " · Concept estimate").font(.caption).frame(maxWidth: .infinity)
                            if filter == "Facilities" || stop.name == ConceptStop.siteA.name {
                                facilities.font(.caption2)
                            }
                        }.padding(12).journeyCard(18)
                    }.buttonStyle(.plain)
                }
            }.padding(14).background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 23))
            primary(compare ? "Choose R&R USJ" : "Compare stops") {
                if compare { onSelect(ConceptStop.siteB.place) } else { compare = true }
            }
        }
    }

    private func detailView(_ stop: ConceptStop) -> some View {
        VStack(spacing: 11) {
            VStack(alignment: .leading, spacing: 10) {
                Label("Parking availability", systemImage: "parkingsign.square.fill").font(.headline)
                capacity(stop)
                Text(stop.travel + " detour · Concept estimate").font(.caption)
            }.padding().frame(maxWidth: .infinity, alignment: .leading)
                .background(JourneyInk.blue, in: RoundedRectangle(cornerRadius: 19)).foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 9) {
                Text("Facilities").font(.headline); facilities
            }.padding(12).journeyCard(16)
            if stop.name == ConceptStop.siteA.name {
                VStack(alignment: .leading, spacing: 6) {
                    Label("EV charging", systemImage: "bolt.car.fill").font(.headline)
                    Text("Up to 180 kW (180,000 W)").font(.headline)
                    Text("CCS2 fast-charging plug · JomCharge").font(.caption)
                    Button(rates ? "Hide rates" : "RM1.50/kWh · View rates") { rates.toggle() }.font(.subheadline.weight(.semibold))
                    if rates { Text("10 kWh · RM15.00    20 kWh · RM30.00").font(.caption) }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(12).journeyCard(16)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tenants at this stop").font(.headline)
                    Label("PETRONAS · Fuel station", systemImage: "fuelpump")
                    Label("Café Mesra · Food & drinks", systemImage: "cup.and.saucer")
                }.font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).padding(12).journeyCard(16)
            }
            if stop.crowd == "Almost full" { primary("Choose a quieter stop") { compare = true } }
            primary("Add stop to route") { onSelect(stop.place) }
        }
    }

    private var facilities: some View {
        HStack(spacing: 7) {
            ForEach([["Food", "fork.knife"], ["Toilets", "figure.stand"], ["Surau", "house"], ["Petrol", "fuelpump"], ["EV", "bolt.car"]], id: \.first) { item in
                VStack(spacing: 3) { Image(systemName: item[1]); Text(item[0]).font(.caption2) }
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func capacity(_ stop: ConceptStop) -> some View {
        HStack {
            Image(systemName: "parkingsign.square.fill"); Text(stop.crowd); Spacer(); Text(stop.capacity)
        }.font(.caption.weight(.semibold)).padding(8).foregroundStyle(.white)
            .background(stop.color, in: RoundedRectangle(cornerRadius: 9))
    }

    @ViewBuilder private var liveList: some View {
        if loading { ProgressView("Looking for rest stops along the route…").padding() }
        else if failed {
            ContentUnavailableView("Rest stop search is unavailable", systemImage: "wifi.exclamationmark")
            Button("Try again") { retry += 1 }
        } else if places.isEmpty {
            ContentUnavailableView("No nearby rest stops", systemImage: "signpost.right", description: Text("Apple Maps returned no stops close to this route."))
        } else {
            ForEach(places) { place in
                Button { onSelect(place) } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(place.name).font(.headline); Text(place.subtitle).font(.caption)
                        }
                        Spacer(); Image(systemName: "plus.circle")
                    }.padding().journeyCard()
                }.buttonStyle(.plain).accessibilityHint("Adds this stop and recalculates the route")
            }
        }
    }

    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 46).background(JourneyInk.blue, in: Capsule())
        }.buttonStyle(.plain)
    }
}

struct JourneyDetailsView: View {
    let plan: JourneyPlan
    let destination: JourneyPlace
    let demo: Bool
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(destination.name + " · " + plan.name).font(.subheadline).foregroundStyle(.secondary)
                    if demo {
                        detail("trafficlight", "8 traffic lights", "4 in the first 12 km · 4 near the destination")
                        detail("camera", "2 AES speed cameras", "First camera in 16 km · Second in 42 km")
                        detail(plan.hasTolls ? "cloud.rain" : "sun.max", plan.hasTolls ? "Rain likely on part of the route" : "Dry forecast", plan.hasTolls ? "Light rain between km 18 and 27 · Dry elsewhere" : "Dry conditions along the concept route")
                        detail("building.columns", plan.hasTolls ? "1 toll plaza · RM" + (plan.name == "LDP" ? "9.60" : "2.20") + " total" : "No tolls", plan.hasTolls ? plan.name + " toll plaza" : "No toll plazas on this route.")
                        if plan.hasTolls {
                            HStack {
                                Text("Payment").font(.caption)
                                Spacer()
                                ForEach(["JourneyPayTNG", "JourneyPayRFID", "JourneyPayMC", "JourneyPayVisa"], id: \.self) { mark in
                                    Image(mark).resizable().scaledToFit().frame(width: 42, height: 18).accessibilityHidden(true)
                                }
                            }.padding(12).journeyCard(14).accessibilityLabel("Payment by Touch ’n Go, MyRFID, Mastercard or Visa")
                        }
                        Text("Concept conditions for the One Utama route.").font(.footnote).foregroundStyle(.secondary)
                    } else {
                        detail("car", JourneyFormat.time(plan.duration) + " · " + JourneyFormat.distance(plan.distance),
                               plan.hasTolls ? "Includes toll roads" : "No tolls on this route")
                        ForEach(plan.notices, id: \.self) { notice in Label(notice, systemImage: "exclamationmark.triangle").font(.footnote) }
                        ForEach(Array(plan.steps.enumerated()), id: \.element.id) { i, step in
                            detail("arrow.triangle.turn.up.right.diamond", "\(i + 1). " + step.instruction, JourneyFormat.distance(step.distance))
                        }
                    }
                    Button("Back to map preview", action: onClose).font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 48).background(JourneyInk.sky, in: Capsule())
                }.padding()
            }.background(JourneyInk.sky.opacity(0.5)).navigationTitle("Route details")
        }.foregroundStyle(JourneyInk.navy)
    }

    private func detail(_ symbol: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: symbol).frame(width: 36, height: 36).background(JourneyInk.sky, in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline); Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }; Spacer()
        }.padding(10).journeyCard(17)
    }
}
