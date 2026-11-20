import SwiftUI

/// A self-contained walkthrough of the toll and flyover designs.
struct TuJuRoadPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let estimate: JourneyEstimate
    @State private var scene: Scene

    init(estimate: JourneyEstimate, startAtFlyover: Bool) {
        self.estimate = estimate
        _scene = State(initialValue: startAtFlyover ? .flyover(nil) : .approach)
    }

    private enum Level: CaseIterable {
        case flyover, lower
        var title: String { self == .flyover ? "Flyover" : "Road below" }
        var side: String { self == .flyover ? "Above" : "Below" }
        var icon: String { self == .flyover ? "arrow.up" : "arrow.down" }
    }

    private enum Scene: Equatable {
        case approach, toll, flyover(Level?)

        var background: String {
            switch self {
            case .approach: return "JourneySampleRoad"
            case .toll: return "RoadTollApproach"
            case .flyover(.lower): return "RoadUnderpass"
            case .flyover: return "RoadFlyover"
            }
        }
    }

    private let navy = Color(red: 0.065, green: 0.17, blue: 0.27)
    private let ink = Color(red: 0.045, green: 0.18, blue: 0.34)
    private let pale = Color(red: 0.87, green: 0.96, blue: 1)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 0.77, green: 0.85, blue: 0.91).ignoresSafeArea()
                Image(scene.background)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width,
                           height: geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom)
                    .clipped()
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                ScrollView {
                    VStack(spacing: 10) {
                        HStack {
                            Label("Navigation preview", systemImage: "play.rectangle")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Button { dismiss() } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                            }
                            .accessibilityLabel("Close navigation preview")
                        }
                        .foregroundStyle(ink)

                        guidance

                        Spacer(minLength: 28)
                        HStack {
                            VStack(spacing: 0) {
                                Text("60").font(.headline)
                                Text("km/h").font(.caption2)
                            }
                            .padding(8)
                            .foregroundStyle(Color(red: 0.025, green: 0.40, blue: 0.19))
                            .background(.white, in: RoundedRectangle(cornerRadius: 12))
                            .accessibilityLabel("Preview speed, 60 kilometres per hour")
                            Spacer()
                        }
                        tripCard
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
                    .frame(minHeight: geometry.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var guidance: some View {
        switch scene {
        case .approach:
            banner(icon: "arrow.up", title: "Continue straight", detail: "LDP toll plaza ahead")
        case .toll:
            VStack(spacing: 12) {
                headline(icon: "creditcard", title: "500 m", detail: "LDP toll plaza · Centre lane for RFID")
                Image("RoadLaneGuide")
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel("Touch ’n Go on the left, MyRFID in the centre, and card payment on the right.")
            }
            .padding(12)
            .background(navy.opacity(0.96), in: RoundedRectangle(cornerRadius: 20))
        case .flyover(let selected):
            banner(icon: selected?.icon ?? "arrow.up.arrow.down",
                   title: selected.map { $0.title + " confirmed" } ?? "Which road are you on?",
                   detail: selected.map { $0 == .flyover ? "Guidance continues on the flyover." : "Guidance continues on the lower road." } ?? "Two roads overlap here. Select your current road.")
            VStack(spacing: 7) {
                ForEach(Level.allCases, id: \.self) { level in
                    Button {
                        scene = .flyover(level)
                    } label: {
                        HStack {
                            Label(level.side, systemImage: level.icon).font(.caption.weight(.semibold))
                            Spacer()
                            Text(level.title).font(.headline)
                            Spacer()
                            Image(systemName: selected == level ? "checkmark" : "chevron.right")
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 45)
                        .foregroundStyle(ink)
                        .background(selected == level ? Color(red: 0.85, green: 0.96, blue: 0.85) : pale,
                                    in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected == level ? .isSelected : [])
                }
            }
            .padding(10)
            .background(navy, in: RoundedRectangle(cornerRadius: 18))
            if let selected {
                HStack {
                    Text(selected == .flyover ? "You're on the flyover" : "You're on the road below")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button("Change road") { scene = .flyover(nil) }
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(14)
                .background(navy.opacity(0.94), in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func banner(icon: String, title: String, detail: String) -> some View {
        headline(icon: icon, title: title, detail: detail)
            .padding(16)
            .background(navy.opacity(0.90), in: RoundedRectangle(cornerRadius: 20))
    }

    private func headline(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .center, spacing: 15) {
            Image(systemName: icon).font(.title2.weight(.semibold))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title3.bold()).accessibilityAddTraits(.isHeader)
                Text(detail).font(.subheadline)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tripCard: some View {
        VStack(spacing: 6) {
            Text(JourneyFormat.time(estimate.duration)).font(.title2.bold())
            Text(JourneyFormat.distance(estimate.distance) + " · Arrive by " + estimate.sampleArrival).font(.subheadline)
            ProgressView(value: estimate.progress)
                .accessibilityLabel("Sample journey").accessibilityValue(estimate.progress.formatted(.percent))
            switch scene {
            case .approach:
                action("Preview toll lanes") { scene = .toll }
            case .toll:
                action("Preview flyover") { scene = .flyover(nil) }
            case .flyover(nil):
                EmptyView()
            case .flyover:
                action("Finish preview") { dismiss() }
            }
        }
        .padding(14)
        .foregroundStyle(ink)
        .background(pale.opacity(0.96), in: RoundedRectangle(cornerRadius: 22))
    }

    private func action(_ text: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Text(text).font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 42)
                .foregroundStyle(.white)
                .background(ink, in: Capsule())
        }
        .buttonStyle(.plain)
        .padding(.top, 3)
    }
}
