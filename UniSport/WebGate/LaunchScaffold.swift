import SwiftUI

struct LaunchScaffold<Inner: View>: View {
    @AppStorage("gate.consentSealed") private var consentSealed = false
    @State private var phase: Phase = .preparing
    @State private var showPledge = false
    @ViewBuilder var inner: () -> Inner

    var body: some View {
        Group {
            if consentSealed {
                inner()
            } else {
                switch phase {
                case .preparing:
                    ZStack {
                        Color(.systemBackground).ignoresSafeArea()
                        ProgressView().scaleEffect(1.4)
                    }
                    .task { await calibrate() }
                case .shifted(let url):
                    GateFrame(target: url, sterile: false)
                        .ignoresSafeArea()
                case .pledging:
                    Color(.systemBackground).ignoresSafeArea()
                        .fullScreenCover(isPresented: $showPledge) {
                            ConsentPanel(notice: AppConfig.calibrationAnchor) {
                                consentSealed = true
                                showPledge = false
                                phase = .clear
                            }
                        }
                case .clear:
                    inner()
                }
            }
        }
    }

    @MainActor
    private func calibrate() async {
        let verdict = await GateLedger.calibrate()
        switch verdict {
        case .shifted(let url):
            phase = .shifted(url)
        case .aligned:
            phase = .pledging
            DispatchQueue.main.async { showPledge = true }
        case .blank:
            phase = .clear
        }
    }

    private enum Phase: Equatable {
        case preparing
        case shifted(URL)
        case pledging
        case clear
    }
}
