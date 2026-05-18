import SwiftUI
import Combine

enum UniSportStartupGateRoute {
    case probing
    case nativeApp
    case launchWeb
}

@MainActor
final class UniSportStartupGateController: ObservableObject {
    @Published var route: UniSportStartupGateRoute = .probing

    func runInitialGateCheck() async {
        let probe = UniSportLaunchGateProbe()
        let shouldOpenWeb = await probe.shouldOpenLaunchWeb()
        route = shouldOpenWeb ? .launchWeb : .nativeApp
    }

    func forceNativeRoute() {
        route = .nativeApp
    }
}

struct UniSportStartupGatewayView: View {
    @ObservedObject var container: AppContainer
    @StateObject private var gateController = UniSportStartupGateController()

    var body: some View {
        ZStack {
            switch gateController.route {
            case .probing:
                LoadingPitchView()
                    .task {
                        await gateController.runInitialGateCheck()
                    }
            case .nativeApp:
                RootAppView(container: container)
            case .launchWeb:
                UniSportLaunchWebSurface {
                    gateController.forceNativeRoute()
                }
                .ignoresSafeArea()
            }
        }
    }
}
