import SwiftUI

@main
struct SpreadDiaryApp: App {
    @State private var store = PhraseStore()
    private let generator: any PhraseGenerator = OnDeviceGenerator()

    var body: some Scene {
        WindowGroup {
            ContentView(generator: generator)
                .environment(store)
        }
    }
}
