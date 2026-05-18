import Foundation
import Combine

@MainActor
final class LiveRefreshManager: ObservableObject {
    private var task: Task<Void, Never>?

    func start(interval: TimeInterval, action: @escaping @Sendable () async -> Void) {
        stop()
        task = Task {
            while !Task.isCancelled {
                await action()
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    deinit {
        task?.cancel()
    }
}
