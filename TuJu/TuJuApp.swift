import SwiftUI

@main
struct TuJuApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
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
