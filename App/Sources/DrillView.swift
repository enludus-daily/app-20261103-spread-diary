import SwiftUI

/// ドリル：リングの単語カードに問題を出す。
/// 並べ替え → 穴埋め → めくって赤シートで思い出す → 聞き取り、を覚えた度合いに合わせて出す。
/// iPhone Duo の内側の画面（regular）では、左にカード、右に答える所を並べる。
struct DrillView: View {
    @Environment(PhraseStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var queue: [UUID]
    private let demo: DrillDemo?
    @State private var index = 0
    @State private var current: (phrase: Phrase, question: Question)?
    @State private var rng = SeededRandom(seed: UInt64.random(in: 0...UInt64.max))
    @State private var result: Bool?
    @State private var correctCount = 0
    @State private var answeredCount = 0
    @State private var combo = 0
    @State private var bestCombo = 0
    @State private var finished = false
    @State private var picked: [Int] = []
    @State private var chosen: String?
    @State private var flipped = false
    @State private var revealed = false
    // 手応えの合図
    @State private var selectTick = 0
    @State private var correctTick = 0
    @State private var comboTick = 0
    @State private var wrongTick = 0
    @State private var shareRequest: Phrase?

    init(phraseIDs: [UUID], demo: DrillDemo? = nil) {
        _queue = State(initialValue: phraseIDs)
        self.demo = demo
    }

    var body: some View {
        ZStack {
            RuledPaper()
            VStack(spacing: 0) {
                topBar
                if finished {
                    summary
                } else if let current {
                    questionArea(current.phrase, current.question)
                        .id(index)
                        .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                } else {
                    Spacer()
                }
            }
            if finished && !reduceMotion && (correctCount == answeredCount || store.answeredCount() >= PhraseStore.dailyGoal) {
                StickyConfetti()
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let result, let current, !finished {
                feedbackNote(current.phrase, correct: result)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sensoryFeedback(trigger: selectTick) { _, _ in Feel.hapticsOn ? .selection : nil }
        .sensoryFeedback(trigger: correctTick) { _, _ in Feel.hapticsOn ? .impact(weight: .light) : nil }
        .sensoryFeedback(trigger: comboTick) { _, _ in Feel.hapticsOn ? .impact(weight: .heavy) : nil }
        .sensoryFeedback(trigger: wrongTick) { _, _ in Feel.hapticsOn ? .error : nil }
        .sensoryFeedback(trigger: finished) { _, new in new && Feel.hapticsOn ? .success : nil }
        .sheet(item: $shareRequest) { phrase in
            ShareCardSheet(phrase: phrase)
        }
        .onAppear(perform: start)
    }

    // MARK: - 上の帯

    private var topBar: some View {
        HStack(spacing: Space.m) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(Ink.text)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("とじる")
            // 進み具合：カードの小さな札を並べ、済んだ札にマーカー
            HStack(spacing: 4) {
                ForEach(0..<queue.count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < index || finished ? Ink.marker : (i == index ? Ink.pen : Ink.rule))
                        .frame(height: 6)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: finished ? "おわり" : "\(min(index + 1, queue.count)) 問目 / \(queue.count) 問"))
            ComboBadge(combo: combo)
        }
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.s)
    }

    // MARK: - 問題

    @ViewBuilder
    private func questionArea(_ phrase: Phrase, _ question: Question) -> some View {
        let regular = horizontalSizeClass == .regular
        let layout = regular ? AnyLayout(HStackLayout(alignment: .top, spacing: Space.xxl)) : AnyLayout(VStackLayout(spacing: Space.xl))
        ScrollView {
            layout {
                questionCard(phrase, question)
                    .frame(maxWidth: 460)
                answerArea(phrase, question)
                    .frame(maxWidth: 460)
            }
            .padding(.horizontal, Space.xl)
            .padding(.top, Space.l)
            .padding(.bottom, 120)
            .frame(maxWidth: .infinity)
        }
    }

    private func kindTitle(_ kind: QuizKind) -> String {
        switch kind {
        case .scramble: "並べ替え"
        case .cloze: "穴埋め"
        case .recall: "めくって思い出す"
        case .listening: "聞き取り"
        }
    }

    private func kindHint(_ kind: QuizKind) -> String {
        switch kind {
        case .scramble: "単語の札をタップして、英語の順に並べます。"
        case .cloze: "空いている所に入る単語を選びます。"
        case .recall: "英語で声に出して言ってから、めくって赤シートをずらします。"
        case .listening: "聞こえた英語を、札で並べます。"
        }
    }

    private func questionCard(_ phrase: Phrase, _ question: Question) -> some View {
        let scene = phrase.sceneKind
        return VStack(alignment: .leading, spacing: Space.m) {
            Text(kindTitle(question.kind))
                .font(Typo.label(.caption))
                .kerning(0.6)
                .foregroundStyle(scene.swatch.deep)
            FlipCard(flipped: flipped) {
                CardFace(scene: scene) {
                    VStack(alignment: .leading, spacing: Space.m) {
                        Label(scene.title, systemImage: scene.symbol)
                            .font(Typo.label(.caption))
                            .foregroundStyle(scene.swatch.deep)
                        Spacer(minLength: 0)
                        if question.kind == .listening && result == nil {
                            Button {
                                Speaker.shared.speak(phrase.english)
                                selectTick += 1
                            } label: {
                                Label("もう一度聞く", systemImage: "speaker.wave.3.fill")
                            }
                            .buttonStyle(InkButtonStyle(color: scene.swatch.deep, deep: Ink.text))
                        } else if case .cloze(let cloze) = question {
                            Text(cloze.displayTokens.joined(separator: " "))
                                .font(Typo.english(.title3))
                                .foregroundStyle(Ink.text)
                                .minimumScaleFactor(0.7)
                            Text(phrase.japanese).font(.footnote).foregroundStyle(Ink.sub)
                        } else {
                            Text(phrase.japanese)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Ink.text)
                                .minimumScaleFactor(0.7)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } back: {
                CardFace(scene: scene) {
                    VStack(alignment: .leading, spacing: Space.m) {
                        Text(phrase.japanese).font(.footnote).foregroundStyle(Ink.sub)
                        Spacer(minLength: 0)
                        RedSheet(revealed: $revealed, initialPull: demo == .recallPulled ? 0.45 : 0, onReveal: {
                            selectTick += 1
                            Speaker.shared.speak(phrase.english)
                        }) {
                            MarkedText(text: phrase.english, font: Typo.english(.title2))
                                .minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, Space.s)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(height: 240)
            .overlay {
                if let result {
                    PenMark(kind: result ? .circle : .cross, size: 150)
                        .allowsHitTesting(false)
                }
            }
            .modifier(ShakeOnChange(trigger: wrongTick))
            if !(question.kind == .recall && flipped) {
                Text(kindHint(question.kind))
                    .font(.footnote)
                    .foregroundStyle(Ink.sub)
            }
        }
    }

    // MARK: - 答える所

    @ViewBuilder
    private func answerArea(_ phrase: Phrase, _ question: Question) -> some View {
        switch question {
        case .scramble(let scramble), .listening(let scramble):
            scrambleArea(scramble, scene: phrase.sceneKind)
        case .cloze(let cloze):
            clozeArea(cloze, scene: phrase.sceneKind)
        case .recall:
            recallArea(phrase)
        }
    }

    private func scrambleArea(_ question: ScrambleQuestion, scene: SceneKind) -> some View {
        VStack(alignment: .leading, spacing: Space.l) {
            // 答えを書く罫線
            WordFlowLayout(spacing: 6, lineSpacing: 8) {
                ForEach(Array(picked.enumerated()), id: \.element) { position, pieceIndex in
                    Button(question.pieces[pieceIndex]) {
                        guard result == nil else { return }
                        selectTick += 1
                        withAnimation(reduceMotion ? nil : .snappy) { _ = picked.remove(at: position) }
                    }
                    .buttonStyle(TileButtonStyle(fill: scene.swatch.soft, edge: scene.swatch.accent))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
            .padding(Space.s)
            .background(alignment: .bottom) {
                VStack(spacing: 28) {
                    Rectangle().fill(answerLineColor).frame(height: 2)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("並べた英語")
            WordFlowLayout(spacing: 8, lineSpacing: 10) {
                ForEach(question.pieces.indices.filter { !picked.contains($0) }, id: \.self) { pieceIndex in
                    Button(question.pieces[pieceIndex]) {
                        guard result == nil else { return }
                        selectTick += 1
                        withAnimation(reduceMotion ? nil : .snappy) { picked.append(pieceIndex) }
                        if picked.count == question.pieces.count {
                            answer(question.isCorrect(picked.map { question.pieces[$0] }))
                        }
                    }
                    .buttonStyle(TileButtonStyle())
                }
            }
            if result == nil, !picked.isEmpty {
                Button("並べ直す") {
                    withAnimation(reduceMotion ? nil : .snappy) { picked.removeAll() }
                }
                .buttonStyle(OutlineButtonStyle(color: Ink.sub))
            }
        }
    }

    private var answerLineColor: Color {
        switch result {
        case .some(true): Ink.marker
        case .some(false): Ink.redPen
        case .none: Ink.text.opacity(0.35)
        }
    }

    private func clozeArea(_ question: ClozeQuestion, scene: SceneKind) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.m), GridItem(.flexible(), spacing: Space.m)], spacing: Space.m) {
            ForEach(question.choices, id: \.self) { choice in
                Button {
                    guard result == nil else { return }
                    chosen = choice
                    answer(question.isCorrect(choice))
                } label: {
                    Text(choice)
                        .frame(maxWidth: .infinity)
                        .overlay(alignment: .trailing) {
                            if result != nil, question.isCorrect(choice) {
                                Image(systemName: "circle").font(.headline.weight(.heavy)).foregroundStyle(Ink.redPen)
                            } else if result == false, chosen == choice {
                                Image(systemName: "xmark").font(.headline.weight(.heavy)).foregroundStyle(Ink.redPen)
                            }
                        }
                }
                .buttonStyle(TileButtonStyle(
                    fill: result != nil && question.isCorrect(choice) ? Ink.marker.opacity(0.35) : Ink.card,
                    edge: result != nil && question.isCorrect(choice) ? Ink.marker : Ink.rule
                ))
            }
        }
    }

    @ViewBuilder
    private func recallArea(_ phrase: Phrase) -> some View {
        VStack(spacing: Space.m) {
            if !flipped {
                Button {
                    selectTick += 1
                    flipped = true
                } label: {
                    Label("言ってから、めくる", systemImage: "hand.tap")
                }
                .buttonStyle(InkButtonStyle())
            } else if !revealed {
                Text("赤シートを下へずらすと、答えが見えます。")
                    .font(.callout)
                    .foregroundStyle(Ink.sub)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if result == nil {
                HStack(spacing: Space.m) {
                    Button {
                        answer(false)
                    } label: {
                        Label("まだ", systemImage: "xmark")
                    }
                    .buttonStyle(InkButtonStyle(color: Ink.card, deep: Ink.rule, foreground: Ink.redPen))
                    Button {
                        answer(true)
                    } label: {
                        Label("言えた", systemImage: "circle")
                    }
                    .buttonStyle(InkButtonStyle(color: Ink.marker, deep: SceneKind.travel.swatch.deep, foreground: Ink.text))
                }
            }
        }
    }

    // MARK: - 答えたあと：付箋に正しい英語

    private func feedbackNote(_ phrase: Phrase, correct: Bool) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .firstTextBaseline) {
                Text(feedbackTitle(correct))
                    .font(Typo.heading(.title3))
                    .foregroundStyle(correct ? SceneKind.travel.swatch.deep : Ink.redPen)
                Spacer()
                SpeakButton(text: phrase.english)
            }
            Text(phrase.english)
                .font(Typo.english(.body))
                .foregroundStyle(Ink.text)
            if let word = phrase.words.first {
                Text("\(word.english)＝\(word.japanese)")
                    .font(.footnote)
                    .foregroundStyle(Ink.sub)
            }
            Button {
                withAnimation(reduceMotion ? nil : .snappy) { next() }
            } label: {
                Text(nextTitle)
            }
            .buttonStyle(InkButtonStyle())
        }
        .padding(Space.l)
        .frame(maxWidth: 520)
        .background(
            Rectangle()
                .fill(correct ? SceneKind.travel.swatch.soft : SceneKind.feelings.swatch.soft)
                .overlay(alignment: .top) { Rectangle().fill(.black.opacity(0.05)).frame(height: 10) }
        )
        .rotationEffect(.degrees(reduceMotion ? 0 : -1))
        .liftShadow()
        .padding(.horizontal, Space.l)
        .padding(.bottom, Space.s)
    }

    private func feedbackTitle(_ correct: Bool) -> String {
        if !correct { return "おしい。あとでもう一度" }
        switch combo {
        case 10...: return "\(combo) 連続！すごい"
        case 5...: return "\(combo) 連続正解"
        case 3...: return "\(combo) 連続！"
        default: return "正解"
        }
    }

    private var nextTitle: String {
        index + 1 < queue.count ? "次のカード" : "結果を見る"
    }

    // MARK: - 結果：ノートのページに判子

    private var summary: some View {
        ScrollView {
            VStack(spacing: Space.xl) {
                ZStack {
                    VStack(spacing: Space.xs) {
                        Text("\(correctCount)")
                            .font(.system(size: 76, weight: .bold, design: .serif))
                            .kerning(-3)
                            .monospacedDigit()
                            .foregroundStyle(Ink.text)
                        Text("/ \(answeredCount) 問 正解")
                            .font(Typo.label(.subheadline))
                            .foregroundStyle(Ink.sub)
                    }
                    Hanko(text: goalReached ? "済" : "◎", size: 96)
                        .rotationEffect(.degrees(-10))
                        .offset(x: 110, y: -20)
                }
                .padding(.top, Space.xl)
                Text(summaryTitle)
                    .font(Typo.heading(.title2))
                    .foregroundStyle(Ink.text)
                    .multilineTextAlignment(.center)
                HStack(spacing: Space.m) {
                    stat(value: "\(bestCombo)", label: "最高の連続", color: Ink.redPen)
                    stat(value: "\(store.answeredCount())", label: "今日の問題", color: Ink.pen)
                    stat(value: "\(store.spokenPhrases.count)", label: "言える英語", color: SceneKind.travel.swatch.deep)
                }
                Text(StreakMessage.text(streak: store.streak(), totalDays: store.totalDays, practicedToday: true))
                    .font(.callout)
                    .foregroundStyle(Ink.sub)
                if let best = store.spokenPhrases.first {
                    Button {
                        shareRequest = best
                    } label: {
                        Label("言えるようになった英語をカードで共有", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(OutlineButtonStyle())
                }
                let extra = DrillPlanner.extraPractice(store.phrases, now: .now)
                if !extra.isEmpty {
                    Button {
                        restart(with: extra.map(\.id))
                    } label: {
                        Label("先取りで \(extra.count) 枚", systemImage: "forward.fill")
                    }
                    .buttonStyle(OutlineButtonStyle())
                }
                Button("おわる") { dismiss() }
                    .buttonStyle(InkButtonStyle())
            }
            .padding(Space.xl)
            .frame(maxWidth: Space.readable)
            .frame(maxWidth: .infinity)
        }
    }

    private var goalReached: Bool { store.answeredCount() >= PhraseStore.dailyGoal }

    private var summaryTitle: String {
        if goalReached { return "今日の目標、済み！" }
        if answeredCount > 0 && correctCount == answeredCount { return "全部言えました" }
        return "おつかれさま。間違えたカードは、また出てきます"
    }

    private func stat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Typo.number(.title))
                .kerning(-1)
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label)
                .font(Typo.label(.caption))
                .foregroundStyle(Ink.sub)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.m)
        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Ink.card))
        .paperShadow()
        .accessibilityElement(children: .combine)
    }

    // MARK: - 進め方

    private func start() {
        guard current == nil, !finished else { return }
        prepare()
        switch demo {
        case .recallPulled:
            flipped = true
        case .scramblePartial:
            if case .scramble(let q)? = current?.question {
                var used: [Int] = []
                for word in q.answer.prefix(3) {
                    if let i = q.pieces.indices.first(where: { q.pieces[$0] == word && !used.contains($0) }) { used.append(i) }
                }
                picked = used
            }
        case .result:
            correctCount = 3
            answeredCount = 3
            bestCombo = 3
            finished = true
        case nil:
            break
        }
    }

    private func prepare() {
        while index < queue.count {
            if let phrase = store.phrase(id: queue[index]) {
                let pool = DrillPlanner.distractorPool(store.phrases, excluding: phrase.id)
                let question = DrillPlanner.makeQuestion(for: phrase, pool: pool, using: &rng)
                current = (phrase, question)
                if question.kind == .listening { Speaker.shared.speak(phrase.english) }
                return
            }
            index += 1
        }
        finish()
    }

    private func answer(_ correct: Bool) {
        guard let current, result == nil else { return }
        store.record(id: current.phrase.id, correct: correct)
        answeredCount += 1
        if correct {
            correctCount += 1
            combo += 1
            bestCombo = max(bestCombo, combo)
            if [3, 5, 10].contains(combo) || combo > 10 && combo % 5 == 0 { comboTick += 1 } else { correctTick += 1 }
        } else {
            combo = 0
            wrongTick += 1
        }
        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7)) { result = correct }
        if current.question.kind != .recall { Speaker.shared.speak(current.phrase.english) }
    }

    private func next() {
        result = nil
        picked = []
        chosen = nil
        flipped = false
        revealed = false
        index += 1
        prepare()
    }

    private func finish() {
        current = nil
        if answeredCount > 0 { store.recordDrillFinished() }
        finished = true
    }

    private func restart(with ids: [UUID]) {
        queue = ids
        index = 0
        correctCount = 0
        answeredCount = 0
        combo = 0
        bestCombo = 0
        result = nil
        picked = []
        chosen = nil
        flipped = false
        revealed = false
        finished = false
        prepare()
    }
}

/// 連続正解の札：3 連続から出て、増えるたびに弾む
struct ComboBadge: View {
    let combo: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "flame.fill")
            Text("\(combo)")
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .font(.subheadline.weight(.bold))
        .foregroundStyle(combo >= 3 ? Ink.redPen : Ink.sub)
        .padding(.horizontal, Space.s)
        .frame(minWidth: 52, minHeight: 32)
        .background(Capsule().fill(combo >= 3 ? SceneKind.feelings.swatch.soft : Ink.card))
        .scaleEffect(combo >= 3 && !reduceMotion ? 1.08 : 1)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.45), value: combo)
        .opacity(combo > 0 ? 1 : 0.5)
        .accessibilityLabel("連続正解 \(combo)")
    }
}
