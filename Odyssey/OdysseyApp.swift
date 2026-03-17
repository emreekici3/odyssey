import SwiftUI

@main
struct OdysseyApp: App {
    @StateObject private var installer = DependencyInstaller()

    var body: some Scene {
        WindowGroup {
            Group {
                if installer.isComplete {
                    ContentView()
                        .frame(minWidth: 720, minHeight: 560)
                        .transition(.opacity)
                } else {
                    SetupView(installer: installer)
                        .frame(width: 520)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: installer.isComplete)
            .task { await installer.runIfNeeded() }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands { CommandGroup(replacing: .newItem) {} }
    }
}
