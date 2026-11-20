import SwiftUI
import WebKit

struct HeroUIState: Encodable, Equatable {
    var surface: String
    var expanded = true
    var recentName = ""
    var recentDetail = ""
    var selected = "Home"
    var fontScale = 1.0
}

struct HeroUIControlSurface: UIViewRepresentable {
    let state: HeroUIState
    let onAction: (String) -> Void
    var onHeight: (CGFloat) -> Void = { _ in }
    var onUnavailable: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.userContentController.add(context.coordinator, name: "tuju")
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.backgroundColor = .clear
        view.scrollView.isScrollEnabled = state.surface == "journey"
        view.scrollView.bounces = false
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.allowsLinkPreview = false
        context.coordinator.attach(view)
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.update(self)
    }

    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        coordinator.detach(view)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        private var surface: HeroUIControlSurface
        private weak var webView: WKWebView?
        private let page = Bundle.main.url(forResource: "HeroUIControls", withExtension: "html")?.standardizedFileURL
        private var isReady = false
        private var isUnavailable = false
        private var needsReload = false
        private var rendered: HeroUIState?
        private var lastHeight: CGFloat?
        private var generation = 0

        init(_ surface: HeroUIControlSurface) { self.surface = surface }

        func attach(_ view: WKWebView) {
            webView = view
            view.navigationDelegate = self
            NotificationCenter.default.addObserver(self, selector: #selector(becameActive),
                                                   name: UIApplication.didBecomeActiveNotification, object: nil)
            load()
        }

        func update(_ next: HeroUIControlSurface) {
            if next.state.surface != surface.state.surface {
                webView?.scrollView.isScrollEnabled = next.state.surface == "journey"
            }
            surface = next
            render()
        }

        func detach(_ view: WKWebView) {
            webView = nil
            generation += 1
            NotificationCenter.default.removeObserver(self)
            view.navigationDelegate = nil
            view.configuration.userContentController.removeScriptMessageHandler(forName: "tuju")
            view.stopLoading()
        }

        private func load() {
            guard let view = webView else { return }
            generation += 1
            needsReload = false
            isReady = false
            rendered = nil
            lastHeight = nil
            guard let page else { unavailable(); return }
            // All scripts, styles and artwork are in the signed app's single HTML file.
            view.loadFileURL(page, allowingReadAccessTo: page)
        }

        private func isLocalPage(_ url: URL?) -> Bool {
            guard let page, let url, url.isFileURL else { return false }
            return url.standardizedFileURL == page
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let local = action.targetFrame?.isMainFrame == true && isLocalPage(action.request.url)
            decisionHandler(local ? .allow : .cancel)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let view = webView, message.webView === view, !isUnavailable, message.name == "tuju",
                  message.frameInfo.isMainFrame, isLocalPage(message.frameInfo.request.url) else { return }
            if let command = message.body as? String {
                if command == "ready" { isReady = true; render(); return }
                guard isReady else { return }
                let allowed: Set<String>
                switch surface.state.surface {
                case "journey": allowed = ["toggle", "search", "home", "work", "saved", "changeHome", "changeWork", "recent", "stops"]
                case "tabs": allowed = ["tabHome", "tabMap", "tabTrips", "tabProfile"]
                default: return
                }
                if allowed.contains(command) { surface.onAction(command) }
            } else if let object = message.body as? [String: Any], let value = object["height"] as? NSNumber {
                let height = CGFloat(value.doubleValue)
                guard height.isFinite, height > 0, height <= 2048, lastHeight != height else { return }
                lastHeight = height
                surface.onHeight(height)
            }
        }

        private func render() {
            guard isReady, !isUnavailable, let view = webView, rendered != surface.state else { return }
            let state = surface.state
            do {
                let payload = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))
                let currentGeneration = generation
                rendered = state
                view.callAsyncJavaScript("window.renderTuJu(state)", arguments: ["state": payload], in: nil,
                                         in: .page) { [weak self] result in
                    guard let self, self.generation == currentGeneration, self.rendered == state else { return }
                    if case .failure = result { self.unavailable() }
                }
            } catch { unavailable() }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !isReady, !isUnavailable else { return }
            let currentGeneration = generation
            webView.evaluateJavaScript("typeof window.renderTuJu === 'function'") { [weak self] value, _ in
                guard let self, self.generation == currentGeneration, !self.isReady else { return }
                guard value as? Bool == true else { self.unavailable(); return }
                self.isReady = true
                self.render()
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code != NSURLErrorCancelled { unavailable() }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code != NSURLErrorCancelled { unavailable() }
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            generation += 1
            isReady = false
            needsReload = true
            if UIApplication.shared.applicationState == .active { load() }
        }

        @objc private func becameActive() {
            if needsReload { load() }
        }

        private func unavailable() {
            guard !isUnavailable, webView != nil else { return }
            isUnavailable = true
            DispatchQueue.main.async { [weak self] in
                guard let self, self.webView != nil else { return }
                self.surface.onUnavailable()
            }
        }
    }
}
