import SwiftUI

private enum RideProvider: String, CaseIterable {
    case grab = "Grab", maxim = "Maxim", inDrive
    var fare: String {
        switch self { case .grab: "RM18–25"; case .maxim: "RM15–22"; case .inDrive: "RM16–23" }
    }
    var logo: String {
        switch self { case .grab: "RideGrab"; case .maxim: "RideMaxim"; case .inDrive: "RideInDrive" }
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
