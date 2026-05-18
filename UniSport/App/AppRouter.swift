import Foundation
import SwiftUI
import Combine

@MainActor
final class AppRouter: ObservableObject {
    @Published var bootstrapState: BootstrapState = .launching
    @Published var selectedTab: AppTab = .home
    @Published var selection: AppContextSelection = .empty

    private let settingsRepository: UserSettingsRepository

    init(settingsRepository: UserSettingsRepository) {
        self.settingsRepository = settingsRepository
    }

    func bootstrap() async {
        do {
            selection = try settingsRepository.getSelection()
            try? settingsRepository.setOnboardingCompleted(true)
            bootstrapState = .ready
        } catch {
            selection = .empty
            bootstrapState = .ready
        }
    }

    func completeOnboarding(selection: AppContextSelection) {
        do {
            self.selection = selection
            try settingsRepository.saveSelection(selection)
            try settingsRepository.setOnboardingCompleted(true)
            bootstrapState = .ready
        } catch {
            bootstrapState = .failed("The onboarding state could not be saved.")
        }
    }

    func updateSelection(_ selection: AppContextSelection) {
        self.selection = selection
        try? settingsRepository.saveSelection(selection)
    }
}
