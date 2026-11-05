import SwiftUI
import Translation

/// きょう：ノートの今日のページ。今日の 3 枚・復習・言いたいことをカードにする
struct TodayView: View {
    @Environment(PhraseStore.self) private var store
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let generator: any PhraseGenerator

    @AppStorage("settings.dailyCards") private var dailyCards = 3
    @AppStorage("settings.scenes") private var scenesCSV = ""
    @State private var japanese = ""
    @State private var compose = ComposeModel()
    @State private var translationConfig: TranslationSession.Configuration?
    @State private var drillRequest: DrillRequest?
    @State private var learnRequest: LearnRequest?
    @State private var handledScene = false

    private var enabledScenes: Set<String> {
        let picked = Set(scenesCSV.split(separator: ",").map(String.init))
        return picked.isEmpty ? Set(SceneKind.bankScenes.map(\.rawValue)) : picked
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if horizontalSizeClass == .regular {
                        HStack(alignment: .top, spacing: Space.xxl) {
                            VStack(spacing: Space.xl) { heading; todayCards; review }
                            VStack(spacing: Space.xl) { Spacer().frame(height: 60); composeBlock; week }
                        }
                        .frame(maxWidth: 1000)
                    } else {
                        VStack(spacing: Space.xl) { heading; todayCards; review; composeBlock; week }
                            .frame(maxWidth: Space.readable)
                    }
                }
                .padding(.leading, 52)
                .padding(.trailing, Space.xl)
                .padding(.vertical, Space.xl)
                .frame(maxWidth: .infinity)
            }
            .background(RuledPaper())
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(item: $compose.draft) { item in
            DraftSheet(draft: item, notice: compose.notice) { saved in
                store.add(saved)
                japanese = ""
            }
        }
        .fullScreenCover(item: $learnRequest) { request in
            LearnTodayView(cards: request.cards, demoFlipped: request.demoFlipped) { ids in
                learnRequest = nil
                if !ids.isEmpty {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(450))
                        drillRequest = DrillRequest(ids: ids)
                    }
                }
            }
        }
        .fullScreenCover(item: $drillRequest) { request in
            DrillView(phraseIDs: request.ids, demo: request.demo)
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

    // MARK: - 見出し

    private var heading: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            PageHeading(title: "今日のページ", caption: Date.now.formatted(.dateTime.month().day().weekday(.wide)))
            HStack(spacing: Space.m) {
                Hanko(text: "\(min(store.streak(), 99))", size: 46, color: store.streak() > 0 ? Ink.redPen : Ink.sub)
                VStack(alignment: .leading, spacing: 2) {
                    Text(StreakMessage.text(streak: store.streak(), totalDays: store.totalDays,
                                            practicedToday: store.answeredCount() > 0 || store.isTodayLearned()))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Ink.text)
                    GoalLine(answered: store.answeredCount(), goal: PhraseStore.dailyGoal)
                }
            }
        }
    }

    // MARK: - 今日の 3 枚

    @ViewBuilder
    private var todayCards: some View {
        let cards = store.todayCards(bank: .shared, count: dailyCards, scenes: enabledScenes)
        let learned = store.isTodayLearned()
        VStack(alignment: .leading, spacing: Space.l) {
            SectionMark(title: "今日の \(dailyCards) 枚", color: SceneKind.daily.swatch.accent)
            if PhraseBank.shared.phrases.isEmpty {
                StickyNote(color: SceneKind.feelings.swatch.soft) {
                    Text("カードの束を読み込めませんでした。").font(.headline)
                    Text("アプリを入れ直すと直ります。じぶんのカードは下の欄から作れます。").font(.callout)
                }
            } else if cards.isEmpty {
                StickyNote {
                    Text("用意したカードは、すべてリングに通しました。").font(.headline)
                    Text("下の欄で、言いたいことをじぶんのカードにしましょう。").font(.callout)
                }
            } else {
                CardFan(cards: cards, learned: learned)
                    .frame(height: 210)
                    .frame(maxWidth: .infinity)
                    .onTapGesture { if !learned { learnRequest = LearnRequest(cards: cards) } }
                if learned {
                    Text("\(cards.count) 枚をリングに通しました。忘れかけたころに、復習に出てきます。")
                        .font(.callout)
                        .foregroundStyle(Ink.sub)
                } else {
                    Button {
                        learnRequest = LearnRequest(cards: cards)
                    } label: {
                        Label("めくって覚える", systemImage: "hand.tap")
                    }
                    .buttonStyle(InkButtonStyle())
                }
            }
        }
    }

    // MARK: - 復習

    @ViewBuilder
    private var review: some View {
        let due = store.dueCount()
        let extra = DrillPlanner.extraPractice(store.phrases, now: .now)
        VStack(alignment: .leading, spacing: Space.l) {
            SectionMark(title: "復習", color: SceneKind.work.swatch.accent)
            HStack(alignment: .center, spacing: Space.l) {
                CardBoxIcon(count: due)
                VStack(alignment: .leading, spacing: Space.xs) {
                    if store.phrases.isEmpty {
                        Text("今日の 3 枚をめくると、ここに復習が出てきます。")
                            .font(.callout)
                            .foregroundStyle(Ink.text)
                    } else if due > 0 {
                        Text("忘れかけたカードが \(due) 枚")
                            .font(.headline)
                            .foregroundStyle(Ink.text)
                        Text("約 \(max(1, (due * 20 + 59) / 60)) 分。赤シートで思い出します。")
                            .font(.callout)
                            .foregroundStyle(Ink.sub)
                    } else {
                        Text("今日の復習はおわり")
                            .font(.headline)
                            .foregroundStyle(Ink.text)
                        Text(nextReviewText ?? "次の復習が来たら、ここに出ます。")
                            .font(.callout)
                            .foregroundStyle(Ink.sub)
                    }
                }
            }
            if due > 0 {
                Button {
                    drillRequest = DrillRequest(ids: DrillPlanner.duePhrases(store.phrases, now: .now).map(\.id))
                } label: {
                    Label("復習をはじめる", systemImage: "play.fill")
                }
                .buttonStyle(InkButtonStyle())
            } else if !extra.isEmpty {
                Button {
                    drillRequest = DrillRequest(ids: extra.map(\.id))
                } label: {
                    Label("先取りで \(extra.count) 枚", systemImage: "forward.fill")
                }
                .buttonStyle(OutlineButtonStyle())
            }
        }
    }

    private var nextReviewText: String? {
        let upcoming = store.phrases.map(\.review.due).filter { $0 > .now }.min()
        guard let upcoming else { return nil }
        let count = store.phrases.filter { Calendar.current.isDate($0.review.due, inSameDayAs: upcoming) }.count
        let day = Calendar.current.isDateInTomorrow(upcoming) ? "明日" : upcoming.formatted(.dateTime.month().day())
        return "次の復習は\(day)、\(count) 枚です。"
    }

    // MARK: - 言いたいことをカードにする

    private var composeBlock: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            SectionMark(title: "言いたいことをカードにする", color: SceneKind.feelings.swatch.accent)
            ComposeField(japanese: $japanese, isGenerating: compose.isGenerating, status: generator.status, onSubmit: makeEnglish)
        }
    }

    // MARK: - この 1 週間

    private var week: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionMark(title: "この 1 週間", color: Ink.marker)
            HStack(spacing: Space.s) {
                ForEach(Array(store.week().enumerated()), id: \.offset) { _, day in
                    VStack(spacing: Space.xs) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(MarkerLevel.color(HeatLevel.level(day.count)))
                            .frame(height: 28)
                        Text(day.date.formatted(.dateTime.weekday(.narrow)))
                            .font(Typo.label(.caption2))
                            .foregroundStyle(Ink.sub)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("この 1 週間で練習した日は \(store.week().filter { $0.count > 0 }.count) 日")
        }
    }

    // MARK: - 動き

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

    private func openScreenshotScene() {
        guard !handledScene else { return }
        handledScene = true
        switch ScreenshotScene.current {
        case .learn:
            learnRequest = LearnRequest(cards: store.todayCards(bank: .shared, count: dailyCards, scenes: enabledScenes), demoFlipped: true)
        case .drill:
            let ids = store.phrases.filter { $0.review.box == 2 }.map(\.id)
            drillRequest = DrillRequest(ids: Array(ids.prefix(5)), demo: .recallPulled)
        case .scramble:
            let ids = store.phrases.filter { $0.review.box == 0 && Tokenizer.tokens($0.english).count >= 4 }.map(\.id)
            drillRequest = DrillRequest(ids: Array(ids.prefix(5)), demo: .scramblePartial)
        case .result:
            drillRequest = DrillRequest(ids: Array(store.phrases.prefix(3).map(\.id)), demo: .result)
        case .compose:
            if let card = PhraseBank.shared.phrases.first(where: { $0.scene == "feelings" }) {
                var draft = card.draft
                draft.source = .model
                compose.draft = draft
            }
        default:
            break
        }
    }
}

struct LearnRequest: Identifiable {
    let id = UUID()
    let cards: [BankPhrase]
    var demoFlipped = false
}

/// 今日の目標の線（5 問）：罫線にマーカーを引いていく
struct GoalLine: View {
    let answered: Int
    let goal: Int

    var body: some View {
        HStack(spacing: Space.s) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Ink.rule).frame(height: 6)
                    Capsule().fill(Ink.marker)
                        .frame(width: proxy.size.width * min(Double(answered) / Double(max(goal, 1)), 1), height: 10)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 12)
            Text("今日 \(answered) / \(goal) 問")
                .font(Typo.label(.caption))
                .monospacedDigit()
                .foregroundStyle(Ink.sub)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今日の目標 \(goal) 問のうち \(answered) 問")
    }
}

/// 今日の 3 枚：リングに通ったカードを扇に開く（-6°・0°・+6°）
struct CardFan: View {
    let cards: [BankPhrase]
    let learned: Bool
    @State private var stamped = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                let middle = Double(cards.count - 1) / 2
                let offset = Double(index) - middle
                CardFace(scene: card.sceneKind) {
                    VStack(alignment: .leading, spacing: Space.s) {
                        Label(card.sceneKind.title, systemImage: card.sceneKind.symbol)
                            .font(Typo.label(.caption))
                            .foregroundStyle(card.sceneKind.swatch.deep)
                        Text(card.ja)
                            .font(.headline)
                            .foregroundStyle(Ink.text)
                            .lineLimit(3)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(width: 230, height: 150)
                .rotationEffect(.degrees(offset * 3), anchor: .bottom)
                .offset(x: offset * 46, y: abs(offset) * 10)
                .zIndex(Double(index))
            }
            if learned {
                Hanko(text: "済", size: 92)
                    .rotationEffect(.degrees(-8))
                    .scaleEffect(stamped || reduceMotion ? 1 : 0.96)
                    .opacity(stamped || reduceMotion ? 1 : 0)
                    .offset(x: 70, y: 30)
                    .zIndex(10)
                    .onAppear {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) { stamped = true }
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: learned ? "今日のカード \(cards.count) 枚、覚えました" : "今日のカード \(cards.count) 枚。\(cards.map(\.ja).joined(separator: "、"))"))
        .accessibilityAddTraits(.isButton)
    }
}

/// カード箱（覚えた順の仕切り）。中の枚数をセリフの数字で
struct CardBoxIcon: View {
    let count: Int

    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .fill(SceneKind.bankScenes[i].swatch.soft)
                    .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(SceneKind.bankScenes[i].swatch.accent.opacity(0.6)))
                    .frame(width: 58, height: 40)
                    .offset(y: -CGFloat(i) * 6 - 14)
            }
            UnevenRoundedRectangle(bottomLeadingRadius: Radius.tile, bottomTrailingRadius: Radius.tile, style: .continuous)
                .fill(Ink.penDeep)
                .frame(width: 72, height: 34)
            Text("\(count)")
                .font(Typo.number(.title2))
                .kerning(-1)
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.bottom, 2)
                .contentTransition(.numericText())
        }
        .frame(width: 76, height: 70)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("復習のカード \(count) 枚")
    }
}

/// 言いたいことの入力：罫線の上に書く
struct ComposeField: View {
    @Binding var japanese: String
    let isGenerating: Bool
    let status: GeneratorStatus
    let onSubmit: () -> Void

    private static let examples = [
        "明日の会議、少し遅らせてもらえますか？",
        "それ、すごくいいと思う！",
        "もう一度言ってもらえますか？",
        "今日は早めに帰ります",
    ]

    private var isEmpty: Bool { japanese.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var buttonTitle: String { isGenerating ? "英語のカードにしています…" : "英語のカードにする" }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            TextField("例：明日の会議、少し遅らせてもらえますか？", text: $japanese, axis: .vertical)
                .font(.body)
                .lineLimit(2...4)
                .padding(Space.m)
                .background(
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous).fill(Ink.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous).strokeBorder(Ink.rule, lineWidth: 1)
                )
                .onChange(of: japanese) { _, newValue in
                    if newValue.count > Phrase.maxJapaneseLength {
                        japanese = String(newValue.prefix(Phrase.maxJapaneseLength))
                    }
                }
            if isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.s) {
                        ForEach(Array(Self.examples.enumerated()), id: \.offset) { index, example in
                            let scene = SceneKind.bankScenes[index % SceneKind.bankScenes.count]
                            Button(example) { japanese = example }
                                .font(.footnote)
                                .foregroundStyle(Ink.text)
                                .padding(.horizontal, Space.m)
                                .frame(minHeight: 36)
                                .background(Rectangle().fill(scene.swatch.soft))
                                .overlay(alignment: .leading) { Rectangle().fill(scene.swatch.accent).frame(width: 4) }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
            }
            Button(action: onSubmit) {
                HStack(spacing: Space.s) {
                    if isGenerating { ProgressView().tint(.white) } else { Image(systemName: "rectangle.portrait.and.arrow.forward") }
                    Text(buttonTitle)
                }
            }
            .buttonStyle(InkButtonStyle())
            .disabled(isGenerating || isEmpty)
            HStack(alignment: .top, spacing: Space.s) {
                Image(systemName: status == .available ? "apple.intelligence" : "translate")
                switch status {
                case .available:
                    Text("Apple Intelligence が端末の中で、言い方の違いと単語のカードも作ります（通信しません）。")
                case .unavailable(let reason):
                    Text(reason)
                }
            }
            .font(.caption)
            .foregroundStyle(Ink.sub)
        }
    }
}
