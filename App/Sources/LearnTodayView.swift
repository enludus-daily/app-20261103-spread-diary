import SwiftUI

/// 今日の 3 枚をめくって覚える：表（日本語）→ めくる → 裏（英語・言い方の違い・単語）。
/// 最後に「リングに通す」と「済」の判子を押し、そのまま練習へ進める。
struct LearnTodayView: View {
    @Environment(PhraseStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let cards: [BankPhrase]
    var demoFlipped = false
    /// 終わったとき：練習へ進むならリングに通したカードの ID
    let onFinish: ([UUID]) -> Void

    @State private var index = 0
    @State private var flipped = false
    @State private var done = false
    @State private var learnedIDs: [UUID] = []
    @State private var flips = 0
    @State private var stamped = false

    init(cards: [BankPhrase], demoFlipped: Bool = false, onFinish: @escaping ([UUID]) -> Void) {
        self.cards = cards
        self.demoFlipped = demoFlipped
        self.onFinish = onFinish
        _flipped = State(initialValue: demoFlipped)
    }

    var body: some View {
        ZStack {
            RuledPaper()
            VStack(spacing: Space.xl) {
                topBar
                Spacer(minLength: 0)
                if done { finished } else if index < cards.count { cardArea(cards[index]) }
                Spacer(minLength: 0)
            }
            .padding(Space.xl)
            .frame(maxWidth: horizontalSizeClass == .regular ? 900 : Space.readable)
        }
        .sensoryFeedback(trigger: flips) { _, _ in Feel.hapticsOn ? .selection : nil }
        .sensoryFeedback(trigger: done) { _, new in new && Feel.hapticsOn ? .success : nil }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(Ink.text)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("とじる")
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<cards.count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < index || done ? Ink.marker : (i == index ? Ink.pen : Ink.rule))
                        .frame(width: 26, height: 6)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(min(index + 1, cards.count)) 枚目 / \(cards.count) 枚")
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
    }

    @ViewBuilder
    private func cardArea(_ card: BankPhrase) -> some View {
        let layout = horizontalSizeClass == .regular ? AnyLayout(HStackLayout(alignment: .center, spacing: Space.xxl)) : AnyLayout(VStackLayout(spacing: Space.xl))
        layout {
            FlipCard(flipped: flipped) {
                CardFace(scene: card.sceneKind) {
                    VStack(alignment: .leading, spacing: Space.m) {
                        Label(card.sceneKind.title, systemImage: card.sceneKind.symbol)
                            .font(Typo.label(.footnote))
                            .foregroundStyle(card.sceneKind.swatch.deep)
                        Spacer(minLength: 0)
                        Text(card.ja)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Ink.text)
                            .minimumScaleFactor(0.7)
                        Spacer(minLength: 0)
                        Text("タップしてめくる")
                            .font(Typo.label(.caption))
                            .foregroundStyle(Ink.sub)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } back: {
                CardFace(scene: card.sceneKind) {
                    VStack(alignment: .leading, spacing: Space.m) {
                        Text(card.ja)
                            .font(.footnote)
                            .foregroundStyle(Ink.sub)
                        HStack(alignment: .top) {
                            MarkedText(text: card.en, font: Typo.english(.title2))
                                .minimumScaleFactor(0.7)
                            Spacer(minLength: 0)
                            SpeakButton(text: card.en)
                        }
                        Spacer(minLength: 0)
                        HStack(spacing: Space.s) {
                            ForEach(card.words, id: \.self) { word in
                                Text("\(word.en)＝\(word.ja)")
                                    .font(Typo.label(.caption))
                                    .foregroundStyle(card.sceneKind.swatch.deep)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(height: 260)
            .frame(maxWidth: 440)
            .onTapGesture { flip(card) }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("ダブルタップでめくります")

            VStack(alignment: .leading, spacing: Space.m) {
                if flipped {
                    VariantLine(label: "丁寧", text: card.polite, scene: card.sceneKind)
                    VariantLine(label: "くだけた", text: card.casual, scene: card.sceneKind)
                        .padding(.bottom, Space.s)
                    Button {
                        next()
                    } label: {
                        Label(nextTitle, systemImage: index + 1 < cards.count ? "arrow.right" : "link")
                    }
                    .buttonStyle(InkButtonStyle(color: card.sceneKind.swatch.deep, deep: Ink.text))
                } else {
                    Button {
                        flip(card)
                    } label: {
                        Label("めくる", systemImage: "hand.tap")
                    }
                    .buttonStyle(InkButtonStyle())
                }
            }
            .frame(maxWidth: 440)
        }
        .id(index)
        .transition(.opacity)
    }

    private var finished: some View {
        VStack(spacing: Space.xl) {
            ZStack {
                ForEach(Array(cards.enumerated()), id: \.element.id) { i, card in
                    CardFace(scene: card.sceneKind, ruled: false) {
                        Text(card.en).font(Typo.english(.body)).foregroundStyle(Ink.text).lineLimit(2)
                    }
                    .frame(width: 220, height: 120)
                    .rotationEffect(.degrees(Double(i - 1) * 2))
                    .offset(y: CGFloat(i) * -8)
                }
                Hanko(text: "済", size: 96)
                    .rotationEffect(.degrees(-8))
                    .scaleEffect(stamped || reduceMotion ? 1 : 0.96)
                    .opacity(stamped || reduceMotion ? 1 : 0)
                    .offset(x: 90, y: 40)
            }
            .frame(height: 200)
            Text("\(cards.count) 枚をリングに通しました")
                .font(Typo.heading(.title2))
                .foregroundStyle(Ink.text)
            Text("このまま 1 回練習すると、ぐっと残ります。")
                .font(.callout)
                .foregroundStyle(Ink.sub)
            Button {
                onFinish(learnedIDs)
            } label: {
                Label("このまま練習する（\(cards.count) 枚）", systemImage: "play.fill")
            }
            .buttonStyle(InkButtonStyle())
            Button("あとで") { onFinish([]) }
                .buttonStyle(OutlineButtonStyle())
        }
        .frame(maxWidth: 440)
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35).delay(0.15)) { stamped = true }
        }
    }

    private var nextTitle: String {
        index + 1 < cards.count ? "次のカード" : "リングに通す"
    }

    private func flip(_ card: BankPhrase) {
        flipped.toggle()
        flips += 1
        if flipped { Speaker.shared.speak(card.en) }
    }

    private func next() {
        if index + 1 < cards.count {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                index += 1
                flipped = false
            }
        } else {
            learnedIDs = store.learnToday(cards)
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { done = true }
        }
    }
}

/// 言い方の違いの 1 行（付箋の見出し＋英語＋読み上げ）
struct VariantLine: View {
    let label: String
    let text: String
    let scene: SceneKind

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s) {
            Text(label)
                .font(Typo.label(.caption))
                .foregroundStyle(scene.swatch.deep)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Rectangle().fill(scene.swatch.tape))
            Text(text)
                .font(Typo.english(.body))
                .foregroundStyle(Ink.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            SpeakButton(text: text)
        }
    }
}
