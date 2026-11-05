import SwiftUI
import Translation

/// 全体：オンボーディング → 4 つのタブ（きょう・カード・きろく・せってい）。
/// タブは iPhone Duo の内側の画面ではサイドバーになる（sidebarAdaptable）。
struct ContentView: View {
    @Environment(PhraseStore.self) private var store
    let generator: any PhraseGenerator
    @AppStorage("onboarding.done") private var onboardingDone = false
    @State private var tab: AppTab = ScreenshotScene.current?.tab ?? .today
    @State private var reminder = Reminder()

    var body: some View {
        TabView(selection: $tab) {
            Tab("きょう", systemImage: "rectangle.portrait.on.rectangle.portrait", value: AppTab.today) {
                TodayView(generator: generator)
            }
            Tab("カード", systemImage: "square.stack.3d.up", value: AppTab.decks) {
                DecksView()
            }
            Tab("きろく", systemImage: "calendar", value: AppTab.record) {
                RecordView()
            }
            Tab("せってい", systemImage: "slider.horizontal.3", value: AppTab.settings) {
                SettingsView(reminder: reminder)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(Ink.pen)
        .fullScreenCover(isPresented: Binding(get: { !onboardingDone }, set: { onboardingDone = !$0 })) {
            OnboardingView { onboardingDone = true }
        }
        .onAppear { reminder.refresh() }
    }
}

enum AppTab: Hashable {
    case today, decks, record, settings
}

/// CI のスクリーンショットで開く画面（起動引数 -screenshotScene は UserDefaults の引数ドメインに入る）
enum ScreenshotScene: String {
    case onboarding, home, learn, drill, scramble, result, decks, deck, record, settings, share, compose

    static var current: ScreenshotScene? {
        UserDefaults.standard.string(forKey: "screenshotScene").flatMap(ScreenshotScene.init(rawValue:))
    }

    var tab: AppTab {
        switch self {
        case .decks, .deck: .decks
        case .record, .share: .record
        case .settings: .settings
        default: .today
        }
    }
}

/// 英語を作る途中の状態（翻訳の閉包から MainActor に安全に戻すためのクラス）
@MainActor
@Observable
final class ComposeModel {
    var isGenerating = false
    var draft: PhraseDraft?
    var notice: String?
    var translatingText = ""

    func finishGeneration(_ result: PhraseDraft) {
        notice = nil
        draft = result
        isGenerating = false
    }

    func finishTranslation(text: String, outcome: Result<String, any Error>) {
        switch outcome {
        case .success(let english):
            if let cleaned = try? DraftCleaner.clean(japanese: text, english: english, variants: [], words: [], source: .translation) {
                notice = nil
                draft = cleaned
            } else {
                fallBackToManual(text)
            }
        case .failure:
            fallBackToManual(text)
        }
        isGenerating = false
    }

    private func fallBackToManual(_ text: String) {
        notice = "翻訳できませんでした。英語を自分で書いて保存できます。"
        draft = PhraseDraft(japanese: text, english: "", variants: [], words: [], source: .manual)
    }
}

struct DrillRequest: Identifiable {
    let id = UUID()
    let ids: [UUID]
    var demo: DrillDemo?
}

/// スクリーンショット用に、ドリルの途中の場面を開く
enum DrillDemo {
    case recallPulled
    case scramblePartial
    case result
}

