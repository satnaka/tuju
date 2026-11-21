import SwiftUI

@main
struct TuJuApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var session = TuJuSession()
    @AppStorage("tuju.completedWelcome") private var completedWelcome = false

    var body: some Scene {
        WindowGroup {
            Group {
                if completedWelcome {
                    RootView()
                } else {
                    TuJuWelcomeView { completedWelcome = true }
                }
            }
            .environmentObject(session)
            .onOpenURL { session.handleRedirect($0) }
            .task(id: scenePhase) {
                if scenePhase == .active { await session.restoreIfNeeded() }
            }
                #if targetEnvironment(macCatalyst)
                .padding(.vertical, 14)
                .background(PreviewWindow())
                #endif
        }
    }
}

#if targetEnvironment(macCatalyst)
/// Give the Mac preview the proportions of the reference iPhone artwork.
private struct PreviewWindow: UIViewRepresentable {
    final class WindowSizer: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let scene = window?.windowScene, let sizes = scene.sizeRestrictions else { return }
            scene.titlebar?.titleVisibility = .hidden
            let height = min(830, scene.screen.bounds.height - 64)
            sizes.minimumSize = CGSize(width: 402, height: min(660, height))
            sizes.maximumSize = CGSize(width: 402, height: height)
            scene.requestGeometryUpdate(.Mac(systemFrame: CGRect(origin: scene.effectiveGeometry.systemFrame.origin,
                                                                  size: CGSize(width: 402, height: height))))
        }
    }
    func makeUIView(context: Context) -> WindowSizer { WindowSizer() }
    func updateUIView(_ view: WindowSizer, context: Context) {}
}
#endif
