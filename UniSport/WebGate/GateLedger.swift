import Foundation
import UIKit
@preconcurrency import WebKit

enum GateVerdict: Equatable {
    case shifted(URL)
    case aligned
    case blank
}

enum GateLedger {
    static func fingerprint(_ url: URL) -> String {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return url.absoluteString.lowercased()
        }
        parts.fragment = nil
        parts.scheme = parts.scheme?.lowercased()
        parts.host = parts.host?.lowercased()
        if parts.path.count > 1, parts.path.hasSuffix("/") {
            parts.path.removeLast()
        }
        return parts.url?.absoluteString ?? url.absoluteString.lowercased()
    }

    @MainActor
    static func calibrate() async -> GateVerdict {
        await GateProbe().run()
    }
}

@MainActor
final class GateProbe: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<GateVerdict, Never>?
    private var probe: WKWebView?
    private var settled = false
    private var watchdog: Task<Void, Never>?

    func run() async -> GateVerdict {
        await withCheckedContinuation { cont in
            continuation = cont
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = .nonPersistent()
            let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 4, height: 4), configuration: configuration)
            view.alpha = 0.02
            view.navigationDelegate = self
            view.load(URLRequest(url: AppConfig.calibrationAnchor))
            probe = view
            watchdog = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                await MainActor.run { self?.resolve(.blank) }
            }
        }
    }

    private func resolve(_ verdict: GateVerdict) {
        guard !settled else { return }
        settled = true
        watchdog?.cancel()
        probe?.navigationDelegate = nil
        probe?.stopLoading()
        probe = nil
        continuation?.resume(returning: verdict)
        continuation = nil
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let target = navigationAction.request.url else {
            decisionHandler(.allow); return
        }
        let anchor = AppConfig.calibrationAnchor
        if GateLedger.fingerprint(target) != GateLedger.fingerprint(anchor) {
            decisionHandler(.cancel)
            resolve(.shifted(target))
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard let self = self, !self.settled else { return }
            self.resolve(.aligned)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        _ = error
        resolve(.blank)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        _ = error
        resolve(.blank)
    }
}
