import SwiftUI
import Translation

/// ホーム。左に「日本語で言いたいこと」と一覧、右（または次の画面）にフレーズの中身。
/// iPhone Duo の内側の画面では 2 列に並び、閉じると 1 列に重なる（NavigationSplitView。
/// Apple Tech Talk「Prepare your app for iPhone Duo」：列は閉じると 1 つのスタックになる）。
struct ContentView: View {
    @Environment(PhraseStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    let generator: any PhraseGenerator

    @State private var selection: UUID?
    @State private var japanese = ""
    @State private var compose = ComposeModel()
    @State private var translationConfig: TranslationSession.Configuration?
    @State private var drillRequest: DrillRequest?
    @State private var handledScene = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    HeroHeader(
                        answered: store.answeredCount(),
                        progress: store.goalProgress(),
                        streak: store.streak(),
                        week: store.week()
                    )
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                .listRowSeparator(.hidden)

                Section {
                    TodayCard(
                        dueCount: store.dueCount(),
                        extraCount: DrillPlanner.extraPractice(store.phrases, now: .now).count,
                        nextReview: nextReviewText,
                        mastered: store.masteredCount,
                        total: store.phrases.count,
                        onStart: startTodayDrill,
                        onExtra: startExtraDrill
                    )
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                .listRowSeparator(.hidden)

                Section {
                    ComposeCard(
                        japanese: $japanese,
                        isGenerating: compose.isGenerating,
                        status: generator.status,
                        onSubmit: makeEnglish
                    )
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                .listRowSeparator(.hidden)

                Section {
                    ForEach(store.sortedPhrases) { phrase in
                        NavigationLink(value: phrase.id) {
                            PhraseRow(phrase: phrase)
                        }
                    }
                    .onDelete { offsets in
                        let sorted = store.sortedPhrases
                        store.delete(ids: offsets.map { sorted[$0].id })
                    }
                } header: {
                    Text("わたしのフレーズ（\(store.phrases.count)）")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .textCase(nil)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background(scheme).ignoresSafeArea())
            .navigationTitle("言いたい英語ドリル")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .bottom) {
                if store.phrases.isEmpty {
                    Text("上の欄に、日本語で言いたいことを書いてみましょう。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 40)
                }
            }
        } detail: {
            if let id = selection, store.phrase(id: id) != nil {
                PhraseDetailView(phraseID: id) { drillRequest = DrillRequest(ids: [id]) }
            } else {
                ContentUnavailableView(
                    "フレーズを選んでください",
                    systemImage: "text.bubble",
                    description: Text("左の一覧から選ぶと、英語・言い方の違い・単語が見られます。")
                )
                .background(Theme.background(scheme).ignoresSafeArea())
            }
        }
        .tint(Theme.pink)
        .sheet(item: $compose.draft) { item in
            DraftSheet(draft: item, notice: compose.notice) { saved in
                let id = store.add(saved)
                selection = id
                japanese = ""
            }
        }
        .fullScreenCover(item: $drillRequest) { request in
            DrillView(phraseIDs: request.ids)
        }
        .translationTask(translationConfig) { @Sendable [compose] session in
            // session はこの閉包の中だけで使う（ほかの actor に渡さない）
            let text = await compose.translatingText
            let outcome: Result<String, any Error>
            do {
                outcome = .success(try await session.translate(text).targetText)
            } catch {
                outcome = .failure(error)
            }
            await compose.finishTranslation(text: text, outcome: outcome)
        }
        .onAppear(perform: openScreenshotScene)
    }

    private var nextReviewText: String? {
        let upcoming = store.phrases.map(\.review.due).filter { $0 > .now }.min()
        guard let upcoming else { return nil }
        let count = store.phrases.filter { Calendar.current.isDate($0.review.due, inSameDayAs: upcoming) }.count
        let day = Calendar.current.isDateInTomorrow(upcoming) ? "明日" : upcoming.formatted(.dateTime.month().day())
        return "次の復習：\(day) \(count) 問"
    }

    private func makeEnglish() {
        let text = String(japanese.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Phrase.maxJapaneseLength))
        guard !text.isEmpty, !compose.isGenerating else { return }
        compose.isGenerating = true
        switch generator.status {
        case .available:
            Task {
                do {
                    let result = try await generator.generate(japanese: text)
                    compose.finishGeneration(result)
                } catch {
                    // モデルが断った・失敗したときは翻訳に回す
                    translate(text)
                }
            }
        case .unavailable:
            translate(text)
        }
    }

    private func translate(_ text: String) {
        compose.translatingText = text
        if translationConfig == nil {
            translationConfig = TranslationSession.Configuration(
                source: Locale.Language(identifier: "ja"),
                target: Locale.Language(identifier: "en")
            )
        } else {
            translationConfig?.invalidate()
        }
    }

    private func startTodayDrill() {
        let ids = DrillPlanner.duePhrases(store.phrases, now: .now).map(\.id)
        guard !ids.isEmpty else { return }
        drillRequest = DrillRequest(ids: ids)
    }

    private func startExtraDrill() {
        let ids = DrillPlanner.extraPractice(store.phrases, now: .now).map(\.id)
        guard !ids.isEmpty else { return }
        drillRequest = DrillRequest(ids: ids)
    }

    /// CI のスクリーンショット用：起動引数 -screenshotScene <名前> で画面を開く
    private func openScreenshotScene() {
        guard !handledScene else { return }
        handledScene = true
        switch ScreenshotScene.current {
        case .drill:
            let ids = store.sortedPhrases.map(\.id)
            if !ids.isEmpty { drillRequest = DrillRequest(ids: ids) }
        case .detail:
            selection = store.sortedPhrases.first?.id
        case .compose:
            if let sample = Phrase.samples(now: .now).first {
                compose.draft = PhraseDraft(
                    japanese: sample.japanese, english: sample.english,
                    variants: sample.variants, words: sample.words, source: .model
                )
            }
        case nil:
            break
        }
    }
}

/// CI のスクリーンショットで開く画面（起動引数 -screenshotScene は UserDefaults の引数ドメインに入る）
enum ScreenshotScene: String {
    case drill, detail, compose

    static var current: ScreenshotScene? {
        UserDefaults.standard.string(forKey: "screenshotScene").flatMap(ScreenshotScene.init(rawValue:))
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
}

