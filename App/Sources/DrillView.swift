import SwiftUI

/// ドリル。並べ替え → 穴埋め → 言ってみる → 聞き取り、を覚えた度合いに合わせて出す。
/// iPhone Duo の内側の画面（horizontal size class が regular）では、左に問題、右に答える所を並べる。
struct DrillView: View {
    @Environment(PhraseStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var scheme

    @State private var queue: [UUID]
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

    init(phraseIDs: [UUID]) {
        _queue = State(initialValue: phraseIDs)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if finished {
                summary
            } else if let current {
                Group {
                    if horizontalSizeClass == .regular {
                        HStack(alignment: .top, spacing: 28) {
                            promptCard(current.phrase, current.question)
                                .frame(maxWidth: .infinity)
                            ScrollView { answerArea(current.phrase, current.question).padding(.bottom, 24) }
                                .frame(maxWidth: .infinity)
                        }
                        .padding(28)
                    } else {
                        ScrollView {
                            VStack(spacing: 22) {
                                promptCard(current.phrase, current.question)
                                answerArea(current.phrase, current.question)
                            }
                            .padding(20)
                        }
                    }
                }
                .id(index)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            } else {
                Spacer()
                ProgressView()
                Spacer()
            }
        }
        .background(Theme.background(scheme).ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            if let result, let current, !finished {
                feedbackBar(current.phrase, correct: result)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sensoryFeedback(trigger: result) { _, new in
            guard let new else { return nil }
            return new ? .success : .error
        }
        .onAppear { prepare() }
    }

    // MARK: - 上の帯

    private var topBar: some View {
        HStack(spacing: 14) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 36, height: 36)
                    .background(Color.primary.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("閉じる")
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(Theme.brand)
                        .frame(width: max(12, proxy.size.width * progress))
                        .animation(.spring(duration: 0.5), value: progress)
                }
            }
            .frame(height: 12)
            Text(counterText)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var counterText: String {
        finished ? "完了" : "\(min(index + 1, queue.count)) / \(queue.count)"
    }

    private var progress: Double {
        guard !queue.isEmpty else { return 0 }
        if finished { return 1 }
        return Double(index + (result == nil ? 0 : 1)) / Double(queue.count)
    }

    // MARK: - 問題

    private func promptCard(_ phrase: Phrase, _ question: Question) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(kindLabel(question.kind), systemImage: kindIcon(question.kind))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.pink)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.pink.opacity(0.12), in: Capsule())
            if question.kind == .listening {
                Button {
                    Speaker.shared.speak(phrase.english)
                } label: {
                    Label("もう一度聞く", systemImage: "speaker.wave.3.fill")
                        .font(.title3.weight(.semibold))
                }
                .buttonStyle(BrandButtonStyle(fill: AnyShapeStyle(Theme.indigo)))
                if result != nil {
                    Text(phrase.japanese)
                        .font(.title3.weight(.semibold))
                }
            } else {
                Text(phrase.japanese)
                    .font(.title.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(instruction(question.kind))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .card()
    }

    private func kindLabel(_ kind: QuizKind) -> String {
        switch kind {
        case .scramble: "並べ替え"
        case .cloze: "穴埋め"
        case .recall: "言ってみる"
        case .listening: "聞き取り"
        }
    }

    private func kindIcon(_ kind: QuizKind) -> String {
        switch kind {
        case .scramble: "square.grid.3x1.below.line.grid.1x2"
        case .cloze: "square.dashed"
        case .recall: "mic.fill"
        case .listening: "ear.fill"
        }
    }

    private func instruction(_ kind: QuizKind) -> String {
        switch kind {
        case .scramble: "単語をタップして、正しい順に並べましょう。"
        case .cloze: "空いている所に入る単語を選びましょう。"
        case .recall: "英語で声に出して言ってから、答えを見ましょう。"
        case .listening: "聞こえた英語を、単語をタップして並べましょう。"
        }
    }

    // MARK: - 答える所

    @ViewBuilder
    private func answerArea(_ phrase: Phrase, _ question: Question) -> some View {
        switch question {
        case .scramble(let scramble), .listening(let scramble):
            scrambleArea(scramble)
        case .cloze(let cloze):
            clozeArea(cloze)
        case .recall:
            recallArea(phrase)
        }
    }

    private func scrambleArea(_ question: ScrambleQuestion) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            WordFlowLayout(spacing: 8, lineSpacing: 10) {
                ForEach(Array(picked.enumerated()), id: \.element) { position, pieceIndex in
                    Button(question.pieces[pieceIndex]) {
                        guard result == nil else { return }
                        withAnimation(.snappy) { _ = picked.remove(at: position) }
                    }
                    .buttonStyle(TileButtonStyle(selected: true))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .topLeading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(answerBorder, style: StrokeStyle(lineWidth: 2, dash: result == nil ? [7] : []))
            )
            WordFlowLayout(spacing: 8, lineSpacing: 10) {
                ForEach(question.pieces.indices.filter { !picked.contains($0) }, id: \.self) { pieceIndex in
                    Button(question.pieces[pieceIndex]) {
                        guard result == nil else { return }
                        withAnimation(.snappy) { picked.append(pieceIndex) }
                        if picked.count == question.pieces.count {
                            answer(question.isCorrect(picked.map { question.pieces[$0] }))
                        }
                    }
                    .buttonStyle(TileButtonStyle())
                }
            }
            if result == nil, !picked.isEmpty {
                Button("やり直す") {
                    withAnimation(.snappy) { picked.removeAll() }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var answerBorder: Color {
        switch result {
        case .some(true): Theme.mint
        case .some(false): Theme.coral
        case .none: Color.primary.opacity(0.2)
        }
    }

    private func clozeArea(_ question: ClozeQuestion) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(question.displayTokens.joined(separator: " "))
                .font(.title2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .card()
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(question.choices, id: \.self) { choice in
                    Button {
                        guard result == nil else { return }
                        chosen = choice
                        answer(question.isCorrect(choice))
                    } label: {
                        Text(choice)
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .foregroundStyle(choiceForeground(question, choice))
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(choiceBackground(question, choice))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func choiceBackground(_ question: ClozeQuestion, _ choice: String) -> Color {
        guard result != nil else { return scheme == .dark ? Color(white: 0.16) : .white }
        if question.isCorrect(choice) { return Theme.mint }
        if chosen == choice { return Theme.coral }
        return scheme == .dark ? Color(white: 0.16) : .white
    }

    private func choiceForeground(_ question: ClozeQuestion, _ choice: String) -> Color {
        guard result != nil else { return .primary }
        return question.isCorrect(choice) || chosen == choice ? .white : .secondary
    }

    @ViewBuilder
    private func recallArea(_ phrase: Phrase) -> some View {
        VStack(spacing: 16) {
            if revealed {
                answerCard(phrase)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                if result == nil {
                    HStack(spacing: 12) {
                        Button {
                            answer(false)
                        } label: {
                            Label("まだ", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(BrandButtonStyle(fill: AnyShapeStyle(Color.gray.opacity(0.6))))
                        Button {
                            answer(true)
                        } label: {
                            Label("言えた！", systemImage: "checkmark")
                        }
                        .buttonStyle(BrandButtonStyle(fill: AnyShapeStyle(Theme.mint)))
                    }
                }
            } else {
                Button {
                    withAnimation(.spring(duration: 0.4)) { revealed = true }
                    Speaker.shared.speak(phrase.english)
                } label: {
                    Label("答えを見る", systemImage: "eye.fill")
                }
                .buttonStyle(BrandButtonStyle())
            }
        }
    }

    private func answerCard(_ phrase: Phrase) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(phrase.english)
                    .font(.title3.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                SpeakButton(text: phrase.english)
                    .font(.title3)
            }
            ForEach(phrase.words) { word in
                HStack(spacing: 6) {
                    Text(word.english).font(.callout.weight(.semibold))
                    if !word.japanese.isEmpty {
                        Text(word.japanese).font(.callout).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .card()
    }

    // MARK: - 答えたあと

    private func feedbackBar(_ phrase: Phrase, correct: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: correct ? "checkmark.circle.fill" : "arrow.uturn.backward.circle.fill")
                    .font(.title)
                Text(feedbackTitle(correct))
                    .font(.title3.weight(.bold))
                Spacer()
                SpeakButton(text: phrase.english)
                    .font(.title3)
                    .foregroundStyle(.white)
            }
            if !(current?.question.kind == .recall) {
                Text(phrase.english)
                    .font(.body.weight(.semibold))
            }
            Button {
                withAnimation(.snappy) { next() }
            } label: {
                Text(nextTitle)
                    .foregroundStyle(correct ? Theme.mint : Theme.coral)
            }
            .buttonStyle(BrandButtonStyle(fill: AnyShapeStyle(Color.white)))
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(correct ? Theme.mint : Theme.coral)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func feedbackTitle(_ correct: Bool) -> String {
        correct ? "正解！" : "おしい。あとでもう一度出します"
    }

    private var nextTitle: String {
        index + 1 < queue.count ? "次へ" : "結果を見る"
    }

    // MARK: - 結果

    private var summary: some View {
        ZStack {
            if answeredCount > 0, Double(correctCount) / Double(answeredCount) >= 0.6 {
                Confetti()
            }
            ScrollView {
                VStack(spacing: 22) {
                    ZStack {
                        GoalRing(progress: store.goalProgress(), lineWidth: 14)
                        VStack(spacing: 2) {
                            Text("\(correctCount)/\(answeredCount)")
                                .font(.system(size: 40, weight: .heavy, design: .rounded))
                                .monospacedDigit()
                            Text("正解").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 170, height: 170)
                    .padding(.top, 24)
                    Text(summaryTitle)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                    HStack(spacing: 12) {
                        stat(icon: "flame.fill", value: "\(store.streak())", label: "日連続", color: Theme.coral)
                        stat(icon: "target", value: "\(store.answeredCount())", label: "今日の問題", color: Theme.pink)
                        stat(icon: "checkmark.seal.fill", value: "\(store.masteredCount)", label: "覚えた", color: Theme.mint)
                    }
                    Text("できなかったフレーズは、また今日の復習に出ます。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    let extra = DrillPlanner.extraPractice(store.phrases, now: .now)
                    if !extra.isEmpty {
                        Button {
                            restart(with: extra.map(\.id))
                        } label: {
                            Label("もっと練習する（\(extra.count) 問）", systemImage: "bolt.fill")
                        }
                        .buttonStyle(BrandButtonStyle(fill: AnyShapeStyle(Theme.indigo)))
                    }
                    Button("おわる") { dismiss() }
                        .buttonStyle(BrandButtonStyle())
                }
                .padding(24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var summaryTitle: String {
        if store.answeredCount() >= PhraseStore.dailyGoal {
            return "今日の目標、達成！"
        }
        return correctCount == answeredCount ? "全問正解！" : "おつかれさま！"
    }

    private func stat(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(color)
            Text(value).font(.title2.weight(.bold)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    // MARK: - 進め方

    private func prepare() {
        while index < queue.count {
            if let phrase = store.phrase(id: queue[index]) {
                let pool = DrillPlanner.distractorPool(store.phrases, excluding: phrase.id)
                let question = DrillPlanner.makeQuestion(for: phrase, pool: pool, using: &rng)
                current = (phrase, question)
                if question.kind == .listening {
                    Speaker.shared.speak(phrase.english)
                }
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
        if current.question.kind != .recall {
            Speaker.shared.speak(current.phrase.english)
        }
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

    private func restart(with ids: [UUID]) {
        withAnimation(.snappy) {
            queue = ids
            index = 0
            correctCount = 0
            answeredCount = 0
            finished = false
            result = nil
            picked = []
            chosen = nil
            revealed = false
        }
        prepare()
    }
}
