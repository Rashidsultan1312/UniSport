import Foundation
import SwiftUI
import WebKit

actor UniSportLaunchGateProbe {
    func shouldOpenLaunchWeb() async -> Bool {
        let launchAddress = UniSportWebGateConfig.launchAddress
        let blockedAddress = UniSportWebGateConfig.blockedAddress
        guard !launchAddress.isEmpty, !blockedAddress.isEmpty, let startURL = URL(string: launchAddress) else {
            return false
        }

        let redirectCollector = UniSportRedirectCollector()
        let session = URLSession(configuration: .ephemeral, delegate: redirectCollector, delegateQueue: nil)
        var request = URLRequest(url: startURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 20

        do {
            let (_, response) = try await session.data(for: request, delegate: redirectCollector)
            var targets = redirectCollector.redirectURLs
            if let resolved = response.url {
                targets.append(resolved)
            }
            targets.append(startURL)
            return !UniSportLaunchGateProbe.containsBlockedAddress(in: targets, blockedAddress: blockedAddress)
        } catch {
            return false
        }
    }

    private static func containsBlockedAddress(in urls: [URL], blockedAddress: String) -> Bool {
        let needle = blockedAddress.lowercased()
        return urls.contains { $0.absoluteString.lowercased().contains(needle) }
    }
}

final class UniSportRedirectCollector: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private(set) var redirectURLs: [URL] = []

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        if let redirectedURL = request.url {
            redirectURLs.append(redirectedURL)
        }
        completionHandler(request)
    }
}

struct UniSportLaunchWebSurface: UIViewRepresentable {
    let onBlockedAddressDetected: () -> Void

    init(onBlockedAddressDetected: @escaping () -> Void) {
        self.onBlockedAddressDetected = onBlockedAddressDetected
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onBlockedAddressDetected: onBlockedAddressDetected)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        context.coordinator.attach(webView: webView)
        if let launchURL = URL(string: UniSportWebGateConfig.launchAddress) {
            webView.load(URLRequest(url: launchURL))
        } else {
            context.coordinator.triggerNativeFallback()
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onBlockedAddressDetected: () -> Void
        private weak var webView: WKWebView?
        private var fallbackTriggered = false

        init(onBlockedAddressDetected: @escaping () -> Void) {
            self.onBlockedAddressDetected = onBlockedAddressDetected
        }

        func attach(webView: WKWebView) {
            self.webView = webView
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if shouldBlock(url: navigationAction.request.url) {
                decisionHandler(.cancel)
                triggerNativeFallback()
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if shouldBlock(url: navigationResponse.response.url) {
                decisionHandler(.cancel)
                triggerNativeFallback()
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
            if shouldBlock(url: webView.url) {
                triggerNativeFallback()
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if shouldBlock(url: webView.url) {
                triggerNativeFallback()
            }
        }

        func triggerNativeFallback() {
            guard !fallbackTriggered else { return }
            fallbackTriggered = true
            DispatchQueue.main.async { [onBlockedAddressDetected] in
                onBlockedAddressDetected()
            }
        }

        private func shouldBlock(url: URL?) -> Bool {
            guard let url else { return false }
            let blockedAddress = UniSportWebGateConfig.blockedAddress.lowercased()
            guard !blockedAddress.isEmpty else { return false }
            return url.absoluteString.lowercased().contains(blockedAddress)
        }
    }
}

struct UniSportPrivacyPolicyPanel: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            UniSportDirectLaunchWebSurface()
                .ignoresSafeArea()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

struct UniSportDirectLaunchWebSurface: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.allowsBackForwardNavigationGestures = true
        if let launchURL = URL(string: UniSportWebGateConfig.launchAddress) {
            webView.load(URLRequest(url: launchURL))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
