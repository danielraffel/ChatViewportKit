import SwiftUI

@main
struct ChatViewportKitExampleApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                List {
                    NavigationLink("SwiftUI Backend (LazyVStack)") {
                        TranscriptLabView()
                    }
                    NavigationLink("UIKit Backend (UICollectionView)") {
                        UKTranscriptLabView()
                    }
                }
                .navigationTitle("ChatViewportKit")
            }
        }
    }
}
