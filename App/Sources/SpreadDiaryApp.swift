import SwiftUI

@main
struct SpreadDiaryApp: App {
    @State private var store: PhraseStore
    private let generator: any PhraseGenerator = OnDeviceGenerator()

    init() {
        if let scene = ScreenshotScene.current {
            // CI のスクリーンショット：見本の記録を別の保存場所に入れて、毎回同じ画面にする
            let suite = "screenshot-demo"
            UserDefaults().removePersistentDomain(forName: suite)
            let defaults = UserDefaults(suiteName: suite) ?? .standard
            let store = PhraseStore(defaults: defaults)
            store.applyDemo(bank: .shared, now: .now, calendar: .current)
            UserDefaults.standard.set(scene != .onboarding, forKey: "onboarding.done")
            _store = State(initialValue: store)
        } else {
            _store = State(initialValue: PhraseStore())
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(generator: generator)
                .environment(store)
        }
    }
}
