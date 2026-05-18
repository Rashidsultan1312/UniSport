import SwiftUI
@preconcurrency import WebKit

struct ConsentPanel: View {
    let notice: URL
    let onAccept: () -> Void
    @State private var agreed = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Welcome")
                    .font(.system(size: 28, weight: .bold))
                Text("Review the privacy notice, then continue.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                NoticeWebView(url: notice)
                    .frame(minHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Button {
                    agreed.toggle()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: agreed ? "checkmark.square.fill" : "square")
                            .font(.system(size: 22))
                        Text("I agree to the Privacy Policy")
                            .font(.system(size: 15, weight: .medium))
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)
                Button {
                    onAccept()
                } label: {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .foregroundStyle(.white)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!agreed)
                .opacity(agreed ? 1 : 0.45)
            }
            .padding(20)
        }
        .interactiveDismissDisabled(true)
    }
}

private struct NoticeWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .nonPersistent()
        let v = WKWebView(frame: .zero, configuration: cfg)
        v.load(URLRequest(url: url))
        return v
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
