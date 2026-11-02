import SwiftUI

@main
struct HelyiIdegenvezetoApp: App {
    @StateObject private var guide = TourGuide()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(guide)
        }
    }
}
