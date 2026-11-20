import SwiftUI

struct ReactNativeControlSurface: UIViewRepresentable {
    let state: HeroUIState
    let onAction: (String) -> Void
    var onHeight: (CGFloat) -> Void = { _ in }
    var onUnavailable: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIView {
        let coordinator = context.coordinator
        if let root = TuJuReactHost.mount(coordinator.properties, action: { [weak coordinator] action in
            coordinator?.receive(action)
        }, height: { [weak coordinator] height in
            guard height.isFinite, (1...2048).contains(height) else { return }
            coordinator?.surface.onHeight(CGFloat(height))
        }) {
            return root
        }
        DispatchQueue.main.async { [weak coordinator] in coordinator?.surface.onUnavailable() }
        return UIView()
    }

    func updateUIView(_ view: UIView, context: Context) {
        let coordinator = context.coordinator
        let changed = coordinator.surface.state != state
        coordinator.surface = self
        if changed { TuJuReactHost.update(view, props: coordinator.properties) }
    }

    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) {
        TuJuReactHost.unmount(coordinator.id)
    }

    @MainActor
    final class Coordinator {
        let id = UUID().uuidString
        var surface: ReactNativeControlSurface
        init(_ surface: ReactNativeControlSurface) { self.surface = surface }

        var properties: [String: Any] {
            let state = surface.state
            return ["surfaceId": id, "surface": state.surface, "expanded": state.expanded,
                    "recentName": state.recentName, "recentDetail": state.recentDetail,
                    "selected": state.selected]
        }

        func receive(_ action: String) {
            let allowed = surface.state.surface == "tabs"
                ? ["tabHome", "tabMap", "tabTrips", "tabProfile"]
                : ["toggle", "search", "home", "work", "saved", "changeHome", "changeWork", "recent", "stops"]
            if allowed.contains(action) { surface.onAction(action) }
        }
    }
}
