import AVFoundation
import MapKit
import SwiftUI

struct JourneyDriveView: View {
    let plan: JourneyPlan
    let destination: JourneyPlace
    let demo: Bool
    let onRoad: (JourneyEstimate) -> Void
    let onDetails: () -> Void
    let onStops: () -> Void
    let onMaps: () -> Void
    let onExit: () -> Void
    let onFinish: () -> Void
    @AppStorage("tuju.simpleMode") private var simple = false
    @AppStorage("tuju.showSpeedLimit") private var speedLimit = true
    @AppStorage("tuju.showRoadNames") private var roadNames = true
    @AppStorage("tuju.voiceLanguage") private var language = "ms-MY"
    @AppStorage("tuju.voiceDetail") private var voiceDetail = "Essential directions"
    @State private var current = 0
    @State private var expanded = true
    @State private var event: DriveEvent?
    @State private var showMapSettings = false
    @State private var reporting = false
    @State private var reported = false
    @State private var narrator = AVSpeechSynthesizer()

    private var step: JourneyStep? { plan.steps.indices.contains(current) ? plan.steps[current] : nil }
    private var estimate: JourneyEstimate { plan.estimate(atStep: current) }

    private var cards: some View {
        VStack(spacing: 8) {
            Button { expanded.toggle() } label: {
                VStack(spacing: 4) {
                    Capsule().fill(JourneyInk.blue.opacity(0.42)).frame(width: 42, height: 4)
                    Text(JourneyFormat.time(estimate.duration)).font(.title.bold())
                    Text(JourneyFormat.distance(estimate.distance) + (demo ? " · Arrive by " + estimate.sampleArrival : " · Estimated journey"))
                        .font(.subheadline.weight(.semibold)).foregroundStyle(JourneyInk.navy.opacity(0.73))
                }.frame(maxWidth: .infinity).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityHint("Expand or collapse journey controls")
            if expanded {
                HStack { Text("\(Int((estimate.progress * 100).rounded()))% complete").font(.caption2); Spacer() }
                if demo {
                    GeometryReader { track in
                        ZStack(alignment: .leading) {
                            ProgressView(value: estimate.progress).tint(.blue).padding(.trailing, 19)
                            ForEach(Array(DriveEvent.allCases.enumerated()), id: \.element.id) { index, item in
                                Button { event = item } label: {
                                    Image(item.asset).resizable().scaledToFit().frame(width: 27, height: 27)
                                        .frame(width: 40, height: 40).contentShape(Rectangle())
                                }.accessibilityLabel(item.title)
                                    .position(x: track.size.width * [0.50, 0.65, 0.84][index], y: track.size.height / 2)
                            }
                            HStack { Spacer(); Image("JourneyEndFlag").resizable().frame(width: 14, height: 14) }
                                .allowsHitTesting(false)
                        }.frame(height: track.size.height)
                    }.frame(height: 27)
                } else { ProgressView(value: estimate.progress) }
                HStack(spacing: 8) {
                    driveButton("Exit", symbol: "xmark", action: onExit)
                    if demo {
                        driveButton("Report", symbol: "exclamationmark.bubble") { reporting = true }
                    } else {
                        driveButton("Apple Maps", symbol: "map", action: onMaps)
                    }
                }
                Button(action: advance) {
                    Label(current + 1 < plan.steps.count ? "Next preview step" : (demo ? "Complete concept trip" : "Finish preview"), systemImage: "chevron.right")
                        .font(.footnote.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 35)
                }
            }
        }.padding(.horizontal, 18).padding(.top, 10).padding(.bottom, expanded ? 2 : 12).journeyPanel()
    }

    var body: some View {
        Group {
            if simple { simpleView } else { standardView }
        }
        .foregroundStyle(JourneyInk.navy).tint(JourneyInk.blue)
        .onDisappear { narrator.stopSpeaking(at: .immediate) }
        .sheet(isPresented: $showMapSettings) { TuJuMapAppearanceView() }
        .alert(item: $event) { event in
            Alert(title: Text(event.title), message: Text(event.detail), dismissButton: .default(Text("Back to route")))
        }
        .confirmationDialog("Add a concept road report", isPresented: $reporting, titleVisibility: .visible) {
            ForEach(["Accident", "Traffic", "Road hazard"], id: \.self) { kind in
                Button(kind) {
                    var reports = UserDefaults.standard.stringArray(forKey: "tuju.conceptRoadReports") ?? []
                    reports.insert(kind, at: 0)
                    UserDefaults.standard.set(Array(reports.prefix(20)), forKey: "tuju.conceptRoadReports")
                    reported = true
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Reports in this walkthrough are stored on this device.") }
        .alert("Concept report saved", isPresented: $reported) { Button("Done") {} }
    }

    private var standardView: some View {
        GeometryReader { bounds in
            ZStack {
                map.ignoresSafeArea()
                VStack(spacing: 8) {
                    guidance
                    if demo {
                        Button { onRoad(estimate) } label: {
                            HStack(spacing: 15) {
                                Image("JourneyBestLane").resizable().scaledToFit().frame(width: 25, height: 25)
                                    .frame(width: 44, height: 44).background(.green.opacity(0.11), in: Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Best Lane").font(.headline)
                                    Text("Stay in the right lane").font(.subheadline)
                                    Text("Less Traffic · Faster").font(.caption.weight(.semibold)).foregroundStyle(.mint)
                                }
                                Spacer(); Image(systemName: "chevron.right").font(.caption)
                            }.padding(13).foregroundStyle(.white).background(JourneyInk.navy.opacity(0.95), in: RoundedRectangle(cornerRadius: 19))
                        }.buttonStyle(.plain).accessibilityHint("Open the toll and flyover preview")
                    }
                    Spacer(minLength: 10)
                    HStack(alignment: .bottom) {
                        if demo { speedBadge }
                        Spacer()
                        VStack(spacing: 8) {
                            control("speaker.wave.2", label: "Read this instruction", action: speak)
                            control("square.2.layers.3d", label: "Switch to Simple Mode") { simple = true }
                            control("gearshape", label: "Map appearance") { showMapSettings = true }
                        }
                    }.padding(.horizontal, 7)
                    cards
                }.padding(.horizontal, 11).padding(.vertical, 4)
            }.frame(width: bounds.size.width, height: bounds.size.height)
        }
    }

    private var simpleView: some View {
        VStack(spacing: 9) {
            HStack {
                Text("Simple Mode").font(.title2.bold())
                Spacer()
                Button("Standard mode") { simple = false }.font(.footnote.bold()).padding(10)
                    .background(JourneyInk.sky, in: Capsule())
            }
            guidance
            ZStack(alignment: .bottomLeading) {
                map.clipShape(RoundedRectangle(cornerRadius: 20))
                if demo { speedBadge.padding(10) }
            }
            HStack {
                simpleAction("R&R ahead", image: "JourneyRestSign", subtitle: demo ? "12 km to next stop" : "Find rest stops", action: onStops)
                simpleAction(demo ? "Road alerts" : "Steps", image: "JourneyWarningSign", subtitle: demo ? "Accident · +8 min" : "Review directions") {
                    if demo { event = .accident } else { onDetails() }
                }
            }
            cards
        }.padding(.horizontal, 16).padding(.vertical, 5)
            .background(LinearGradient(colors: [JourneyInk.sky.opacity(0.8), .white], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    }

    private var guidance: some View {
        HStack(spacing: 18) {
            Image(systemName: current == 0 ? "arrow.up" : (current + 1 >= plan.steps.count ? "flag.checkered" : "arrow.up.left"))
                .font(.system(size: 34, weight: .semibold))
            VStack(alignment: .leading, spacing: 2) {
                Text(JourneyFormat.distance(step?.distance ?? plan.distance)).font(.title.bold())
                Text(step?.instruction ?? destination.name).font(.subheadline.weight(.semibold)).lineLimit(3)
                if roadNames && current > 0 { Text(plan.name).font(.caption2).lineLimit(1) }
            }
            Spacer()
            Text(demo ? "Concept" : "Preview").font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.8))
        }.foregroundStyle(.white).padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.15, green: 0.24, blue: 0.34).opacity(0.97), in: RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder private var map: some View {
        if demo {
            GeometryReader { geometry in
                Image(simple ? "JourneySampleSimpleRoad" : "JourneySampleRoad").resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height).clipped().accessibilityHidden(true)
            }
        } else {
            Map(initialPosition: plan.bounds.isNull ? .automatic : .rect(plan.bounds)) {
                ForEach(plan.paths.indices, id: \.self) { i in MapPolyline(plan.paths[i]).stroke(.blue, lineWidth: 5) }
                if let path = step?.path { MapPolyline(path).stroke(.orange, lineWidth: 6) }
                Marker(destination.name, coordinate: destination.coordinate)
            }
        }
    }

    private var speedBadge: some View {
        VStack(spacing: 1) {
            if speedLimit {
                Text("80").font(.title3.bold()).foregroundStyle(.red).frame(width: 45, height: 40)
                    .background(.white, in: RoundedRectangle(cornerRadius: 13)).overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(.red, lineWidth: 3))
            }
            Text("60").font(.title3.bold()); Text("km/h").font(.caption2)
        }.padding(4).foregroundStyle(Color(red: 0.0, green: 0.42, blue: 0.23))
            .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 15))
            .accessibilityLabel("Illustrated speed 60 kilometres an hour" + (speedLimit ? ", sample speed limit 80" : ""))
    }

    private func simpleAction(_ title: String, image: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Image(image).resizable().scaledToFit().frame(width: 19, height: 19)
                    Text(title).font(.subheadline.bold()); Spacer()
                    Image(systemName: "chevron.right").font(.caption2)
                }
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }.padding(10).frame(maxWidth: .infinity, minHeight: 64).journeyCard(16)
        }.buttonStyle(.plain)
    }

    private func control(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.title3).frame(width: 46, height: 46).journeyCard(15)
        }.accessibilityLabel(label)
    }

    private func driveButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 41).journeyCard(15)
        }.buttonStyle(.plain)
    }

    private func advance() {
        if current + 1 < plan.steps.count { current += 1; speak() }
        else { onFinish() }
    }

    private func speak() {
        guard voiceDetail != "Mute", let step else { return }
        let inMalay = demo && language == "ms-MY"
        let translated: [String: String] = ["Continue straight": "Teruskan perjalanan.", "Keep left at the exit": "Kekal di kiri di susur keluar.", "Arrive at One Utama": "Anda telah tiba di One Utama."]
        let instruction = inMalay ? (translated[step.instruction] ?? step.instruction) : step.instruction
        let words = voiceDetail == "Detailed directions" ? instruction + ", " + JourneyFormat.distance(step.distance) : instruction
        let speech = AVSpeechUtterance(string: words)
        speech.voice = AVSpeechSynthesisVoice(language: demo ? language : Locale.current.identifier.replacingOccurrences(of: "_", with: "-"))
        narrator.stopSpeaking(at: .immediate)
        narrator.speak(speech)
    }
}

private enum DriveEvent: String, CaseIterable, Identifiable {
    case lights, accident, camera
    var id: Self { self }
    var asset: String {
        switch self { case .lights: "JourneyEventLight"; case .accident: "JourneyEventAccident"; case .camera: "JourneyEventCamera" }
    }
    var title: String {
        switch self { case .lights: "Traffic lights"; case .accident: "Accident ahead"; case .camera: "AES speed camera" }
    }
    var detail: String {
        switch self {
        case .lights: "8 lights on the concept route. Four are in the first 12 km."
        case .accident: "The sample traffic report adds 8 minutes to this route."
        case .camera: "Two camera markers on the concept route, at 16 km and 42 km."
        }
    }
}
