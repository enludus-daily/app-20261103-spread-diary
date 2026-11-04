import SwiftUI
import Translation

/// ホーム。左に「日本語で言いたいこと」と一覧、右（または次の画面）にフレーズの中身。
/// iPhone Duo の内側の画面では 2 列に並び、閉じると 1 列に重なる（NavigationSplitView。
/// Apple Tech Talk「Prepare your app for iPhone Duo」：列は閉じると 1 つのスタックになる）。
struct ContentView: View {
    @Environment(PhraseStore.self) private var store
    let generator: any PhraseGenerator

    @State private var selection: UUID?
    @State private var japanese = ""
    @State private var compose = ComposeModel()
    @State private var translationConfig: TranslationSession.Configuration?
    @State private var drillPhraseIDs: DrillRequest?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    ComposeCard(
                        japanese: $japanese,
                        isGenerating: compose.isGenerating,
                        status: generator.status,
                        onSubmit: makeEnglish
                    )
                }
                Section {
                    TodayCard(
                        dueCount: store.dueCount(),
                        streak: store.streak(),
                        total: store.phrases.count,
                        mastered: store.masteredCount,
                        onStart: startTodayDrill
                    )
                }
                Section("フレーズ") {
                    ForEach(store.sortedPhrases) { phrase in
                        NavigationLink(value: phrase.id) {
                            PhraseRow(phrase: phrase)
                        }
                    }
                    .onDelete { offsets in
                        let sorted = store.sortedPhrases
                        store.delete(ids: offsets.map { sorted[$0].id })
                    }
                }
            }
            .navigationTitle("言いたい英語ドリル")
            .overlay {
                if store.phrases.isEmpty {
                    ContentUnavailableView(
                        "まだフレーズがありません",
                        systemImage: "text.bubble",
                        description: Text("上の欄に、日本語で言いたいことを書いてみましょう。")
                    )
                    .padding(.top, 240)
                }
            }
        } detail: {
            if let id = selection, store.phrase(id: id) != nil {
                PhraseDetailView(phraseID: id) { drillPhraseIDs = DrillRequest(ids: [id]) }
            } else {
                ContentUnavailableView(
                    "フレーズを選んでください",
                    systemImage: "rectangle.and.text.magnifyingglass",
                    description: Text("左の一覧から選ぶと、英語・言い方の違い・単語が見られます。")
                )
            }
        }
        .sheet(item: $compose.draft) { item in
            DraftSheet(draft: item, notice: compose.notice) { saved in
                let id = store.add(saved)
                selection = id
                japanese = ""
            }
        }
        .fullScreenCover(item: $drillPhraseIDs) { request in
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
        drillPhraseIDs = DrillRequest(ids: ids)
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

// MARK: - 入力

private struct ComposeCard: View {
    @Binding var japanese: String
    let isGenerating: Bool
    let status: GeneratorStatus
    let onSubmit: () -> Void

    private var buttonTitle: String {
        isGenerating ? "英語にしています…" : "英語にしてドリルを作る"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("日本語で言いたいこと", systemImage: "character.bubble")
                .font(.headline)
            TextField("例：明日の会議、少し遅らせてもらえますか？", text: $japanese, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
                .onChange(of: japanese) { _, newValue in
                    if newValue.count > Phrase.maxJapaneseLength {
                        japanese = String(newValue.prefix(Phrase.maxJapaneseLength))
                    }
                }
            Button(action: onSubmit) {
                HStack {
                    if isGenerating {
                        ProgressView()
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(buttonTitle)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isGenerating || japanese.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            switch status {
            case .available:
                Text("Apple Intelligence が端末の中で、言い方の違いと単語も作ります（通信しません）。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .unavailable(let reason):
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 今日の復習

private struct TodayCard: View {
    let dueCount: Int
    let streak: Int
    let total: Int
    let mastered: Int
    let onStart: () -> Void

    private var startTitle: String {
        dueCount > 0 ? "ドリルを始める（\(dueCount) 問）" : "今日の復習は終わりました"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                stat(value: "\(dueCount)", label: "今日の復習", icon: "rectangle.stack", color: .blue)
                stat(value: "\(streak)", label: "続けた日", icon: "flame.fill", color: .orange)
                stat(value: "\(mastered)/\(total)", label: "覚えた", icon: "checkmark.seal.fill", color: .green)
            }
            Button(action: onStart) {
                Label(startTitle, systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(dueCount == 0)
        }
        .padding(.vertical, 4)
    }

    private func stat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(value, systemImage: icon)
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct PhraseRow: View {
    let phrase: Phrase

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(phrase.japanese)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(phrase.english)
                .font(.body.weight(.medium))
                .lineLimit(2)
            MasteryDots(box: phrase.review.box)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    ContentView(generator: UnavailableGenerator(reason: "プレビュー"))
        .environment(PhraseStore(defaults: UserDefaults(suiteName: "preview")!))
}
