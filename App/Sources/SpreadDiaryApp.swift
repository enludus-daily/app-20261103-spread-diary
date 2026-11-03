import SwiftUI

@main
struct SpreadDiaryApp: App {
    @State private var store = DiaryStore()
    private let corrector: any SentenceCorrector = OnDeviceCorrector()

    var body: some Scene {
        WindowGroup {
            ContentView(corrector: corrector)
                .environment(store)
        }
    }
}
