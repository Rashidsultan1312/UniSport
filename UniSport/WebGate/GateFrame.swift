import SwiftUI
import Combine
@preconcurrency import WebKit

struct GateFrame: View {
    let target: URL
    var sterile: Bool = true
    @StateObject private var bridge = ProbeBridge()

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                GatePane(target: target, sterile: sterile, bridge: bridge)
                if bridge.loading && bridge.progress < 1.0 {
                    ProgressView(value: bridge.progress)
                        .progressViewStyle(.linear)
                        .tint(.white)
                }
            }
            HStack(spacing: 0) {
                navButton(systemImage: "chevron.left") { bridge.pane?.goBack() }
                navButton(systemImage: "chevron.right") { bridge.pane?.goForward() }
                navButton(systemImage: "arrow.clockwise") { bridge.pane?.reload() }
                navButton(systemImage: "house.fill") { bridge.pane?.load(URLRequest(url: target)) }
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
        }
        .ignoresSafeArea(edges: .top)
    }

    private func navButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.plain)
    }
}

@MainActor
final class ProbeBridge: ObservableObject {
    @Published var loading = false
    @Published var progress: Double = 0
    weak var pane: WKWebView?
    private var observers: [NSKeyValueObservation] = []

    func attach(_ web: WKWebView) {
        pane = web
        observers = [
            web.observe(\.estimatedProgress, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in self?.progress = view.estimatedProgress }
            },
            web.observe(\.isLoading, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in self?.loading = view.isLoading }
            }
        ]
    }
}

final class CleanWebView: WKWebView {
    override var inputAccessoryView: UIView? { nil }
}

private struct GatePane: UIViewRepresentable {
    let target: URL
    var sterile: Bool
    var bridge: ProbeBridge

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.websiteDataStore = sterile ? .nonPersistent() : .default()
        let view = CleanWebView(frame: .zero, configuration: cfg)
        view.allowsBackForwardNavigationGestures = true
        view.scrollView.bounces = true
        view.load(URLRequest(url: target))
        DispatchQueue.main.async { bridge.attach(view) }
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
