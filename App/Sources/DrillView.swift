import SwiftUI

/// ドリル。並べ替え → 穴埋め → 日本語を見て英語を言う、を覚えた度合いに合わせて出す。
/// iPhone Duo の内側の画面（horizontal size class が regular）では、左に問題、右に答える所を並べる。
struct DrillView: View {
    @Environment(PhraseStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let phraseIDs: [UUID]

    @State private var index = 0
    @State private var current: (phrase: Phrase, question: Question)?
    @State private var rng = SeededRandom(seed: UInt64.random(in: 0...UInt64.max))
    @State private var result: Bool?
    @State private var correctCount = 0
    @State private var answeredCount = 0
    @State private var finished = false
    @State private var picked: [Int] = []
    @State private var chosen: String?
    @State private var revealed = false

    var body: some View {
        NavigationStack {
            Group {
                if finished {
                    summary
                } else if let current {
                    if horizontalSizeClass == .regular {
                        HStack(alignment: .top, spacing: 24) {
                            promptPanel(current.phrase, current.question)
                                .frame(maxWidth: .infinity)
                            ScrollView { answerPanel(current.phrase, current.question) }
                                .frame(maxWidth: .infinity)
                        }
                        .padding(24)
                    } else {
                        ScrollView {
                            VStack(spacing: 20) {
                                promptPanel(current.phrase, current.question)
                                answerPanel(current.phrase, current.question)
                            }
                            .padding()
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .onAppear { prepare() }
    }

    private var title: String {
        finished ? "おつかれさま" : "\(min(index + 1, phraseIDs.count)) / \(phraseIDs.count)"
    }

    private var nextTitle: String {
        index + 1 < phraseIDs.count ? "次へ" : "結果を見る"
    }

    private func feedbackTitle(_ correct: Bool) -> String {
        correct ? "正解！" : "もう一度、あとで出します"
    }

    // MARK: - 問題

    private func promptPanel(_ phrase: Phrase, _ question: Question) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ProgressView(value: Double(index), total: Double(max(phraseIDs.count, 1)))
            Chip(text: kindLabel(question), color: .blue)
            Text(phrase.japanese)
                .font(.title2.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            Text(instruction(question))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 16))
    }

    private func kindLabel(_ question: Question) -> String {
        switch question {
        case .scramble: "並べ替え"
        case .cloze: "穴埋め"
        case .recall: "言ってみる"
        }
    }

    private func instruction(_ question: Question) -> String {
        switch question {
        case .scramble: "単語をタップして、正しい順に並べましょう。"
        case .cloze: "空いている所に入る単語を選びましょう。"
        case .recall: "英語で声に出して言ってから、答えを見ましょう。"
        }
    }

    // MARK: - 答える所

    @ViewBuilder
    private func answerPanel(_ phrase: Phrase, _ question: Question) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            switch question {
            case .scramble(let scramble):
                scrambleArea(scramble)
            case .cloze(let cloze):
                clozeArea(cloze)
            case .recall:
                recallArea(phrase)
            }
            if let result {
                feedback(phrase, correct: result)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func scrambleArea(_ question: ScrambleQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            WordFlowLayout {
                ForEach(Array(picked.enumerated()), id: \.offset) { position, pieceIndex in
                    Button(question.pieces[pieceIndex]) {
                        guard result == nil else { return }
                        withAnimation(.snappy) { _ = picked.remove(at: position) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [5])))
            WordFlowLayout {
                ForEach(question.pieces.indices.filter { !picked.contains($0) }, id: \.self) { pieceIndex in
                    Button(question.pieces[pieceIndex]) {
                        guard result == nil else { return }
                        withAnimation(.snappy) { picked.append(pieceIndex) }
                        if picked.count == question.pieces.count {
                            answer(question.isCorrect(picked.map { question.pieces[$0] }))
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func clozeArea(_ question: ClozeQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(question.displayTokens.joined(separator: " "))
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            ForEach(question.choices, id: \.self) { choice in
                Button {
                    guard result == nil else { return }
                    chosen = choice
                    answer(question.isCorrect(choice))
                } label: {
                    HStack {
                        Text(choice)
                        Spacer()
                        if result != nil, question.isCorrect(choice) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        } else if result == false, chosen == choice {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    @ViewBuilder
    private func recallArea(_ phrase: Phrase) -> some View {
        if revealed {
            if result == nil {
                HStack(spacing: 12) {
                    Button {
                        answer(false)
                    } label: {
                        Label("まだ", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    Button {
                        answer(true)
                    } label: {
                        Label("言えた", systemImage: "checkmark").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .controlSize(.large)
            }
        } else {
            Button {
                withAnimation { revealed = true }
            } label: {
                Label("答えを見る", systemImage: "eye").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        if revealed, result == nil {
            answerCard(phrase)
        }
    }

    private func feedback(_ phrase: Phrase, correct: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(feedbackTitle(correct), systemImage: correct ? "checkmark.circle.fill" : "arrow.uturn.backward.circle.fill")
                .font(.headline)
                .foregroundStyle(correct ? Color.green : Color.orange)
            answerCard(phrase)
            Button {
                next()
            } label: {
                Label(nextTitle, systemImage: "arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func answerCard(_ phrase: Phrase) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(phrase.english)
                    .font(.title3.weight(.bold))
                Spacer()
                SpeakButton(text: phrase.english)
            }
            ForEach(phrase.words) { word in
                Text("\(word.english)　\(word.japanese)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 結果

    private var summary: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: finished)
            Text("\(correctCount) / \(answeredCount) 問 正解")
                .font(.largeTitle.weight(.bold))
                .monospacedDigit()
            Label("\(store.streak()) 日続けています", systemImage: "flame.fill")
                .font(.title3)
                .foregroundStyle(.orange)
            Text("できなかったフレーズは、また今日の復習に出ます。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("閉じる") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding()
    }

    // MARK: - 進め方

    private func prepare() {
        while index < phraseIDs.count {
            if let phrase = store.phrase(id: phraseIDs[index]) {
                let pool = DrillPlanner.distractorPool(store.phrases, excluding: phrase.id)
                let question = DrillPlanner.makeQuestion(for: phrase, pool: pool, using: &rng)
                current = (phrase, question)
                return
            }
            index += 1 // 途中で消されたフレーズは飛ばす
        }
        finish()
    }

    private func answer(_ correct: Bool) {
        guard let current, result == nil else { return }
        store.record(id: current.phrase.id, correct: correct)
        answeredCount += 1
        if correct { correctCount += 1 }
        withAnimation(.snappy) { result = correct }
    }

    private func next() {
        result = nil
        picked = []
        chosen = nil
        revealed = false
        index += 1
        prepare()
    }

    private func finish() {
        current = nil
        if answeredCount > 0 {
            store.recordDrillFinished()
        }
        finished = true
    }
}
