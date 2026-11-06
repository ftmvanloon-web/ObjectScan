import SwiftUI

@main
@MainActor
struct ObjectScanApp: App {
    var body: some Scene {
        WindowGroup {
            LibraryView()
                .tint(.teal)
        }
    }
}
