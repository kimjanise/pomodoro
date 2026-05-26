import SwiftUI

@main
struct PomodoroBarApp: App {
    @StateObject private var viewModel = PomodoroViewModel()

    init() {
        NotificationManager.shared.requestPermission()
    }

    var body: some Scene {
        MenuBarExtra {
            PomodoroMenuView()
                .environmentObject(viewModel)
        } label: {
            Text(viewModel.menuBarTitle)
        }
        .menuBarExtraStyle(.window)
    }
}
