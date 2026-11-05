import SwiftUI

/// カード：場面ごとの束（リングに通した数 / 束の数）と、じぶんのカード
struct DecksView: View {
    @Environment(PhraseStore.self) private var store
    @State private var path: [DeckRoute] = []
    @State private var handledScene = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    PageHeading(title: "カードの束", caption: "\(PhraseBank.shared.phrases.count) 枚の英語フレーズ・6 つの場面")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Space.l)], spacing: Space.xl) {
                        ForEach(SceneKind.bankScenes) { scene in
                            NavigationLink(value: DeckRoute.scene(scene)) {
                                DeckBundle(scene: scene,
                                           owned: store.phrases(in: scene).count,
                                           total: PhraseBank.shared.phrases(in: scene).count,
                                           mastered: store.phrases(in: scene).filter(\.review.isMastered).count)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    SectionMark(title: "じぶんのカード", color: SceneKind.mine.swatch.accent)
                    let mine = store.phrases(in: .mine)
                    if mine.isEmpty {
                        StickyNote {
                            Text("まだありません").font(.headline)
                            Text("「きょう」の「言いたいことをカードにする」で、自分の言いたいことを英語のカードにできます。")
                                .font(.callout)
                        }
                    } else {
                        ForEach(mine) { phrase in
                            NavigationLink(value: DeckRoute.phrase(phrase.id)) { PhraseRow(phrase: phrase) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.leading, 52)
                .padding(.trailing, Space.xl)
                .padding(.vertical, Space.xl)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
            .background(RuledPaper())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: DeckRoute.self) { route in
                switch route {
                case .scene(let scene): DeckDetailView(scene: scene)
                case .phrase(let id): PhraseDetailView(phraseID: id)
                }
            }
            .onAppear {
                guard !handledScene else { return }
                handledScene = true
                if ScreenshotScene.current == .deck { path = [.scene(.travel)] }
            }
        }
    }
}

enum DeckRoute: Hashable {
    case scene(SceneKind)
    case phrase(UUID)
}

/// 束の絵：リングに通ったカードが重なり、表に場面の名前
struct DeckBundle: View {
    let scene: SceneKind
    let owned: Int
    let total: Int
    let mastered: Int

    var body: some View {
        let swatch = scene.swatch
        VStack(alignment: .leading, spacing: Space.s) {
            ZStack(alignment: .topLeading) {
                ForEach(0..<3, id: \.self) { i in
                    CardShape()
                        .fill(i == 2 ? swatch.soft : swatch.accent.opacity(0.35 + Double(i) * 0.15), style: FillStyle(eoFill: true))
                        .frame(height: 96)
                        .rotationEffect(.degrees(Double(2 - i) * 4), anchor: .topLeading)
                        .offset(x: CGFloat(i) * 2, y: CGFloat(i) * 3)
                        .paperShadow()
                }
                VStack(alignment: .leading, spacing: Space.xs) {
                    Image(systemName: scene.symbol)
                        .font(.title3)
                        .foregroundStyle(swatch.deep)
                    Text(scene.title)
                        .font(Typo.heading(.title3))
                        .foregroundStyle(Ink.text)
                }
                .padding(.top, 30)
                .padding(.leading, Space.l)
                RingMetal().offset(x: 2, y: -31)
            }
            .frame(height: 110)
            // リングに通した割合をマーカーで
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Ink.rule).frame(height: 6)
                    Capsule().fill(swatch.accent)
                        .frame(width: proxy.size.width * (total > 0 ? Double(owned) / Double(total) : 0), height: 6)
                }
            }
            .frame(height: 6)
            Text("\(owned) / \(total) 枚・覚えた \(mastered)")
                .font(Typo.label(.caption))
                .monospacedDigit()
                .foregroundStyle(Ink.sub)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(scene.title)の束。\(total) 枚のうち \(owned) 枚をリングに通しました。覚えた \(mastered) 枚")
        .accessibilityAddTraits(.isButton)
    }
}

/// 束の中身：カードの一覧。リングに通していないカードは薄く、まとめて通して練習できる
struct DeckDetailView: View {
    @Environment(PhraseStore.self) private var store
    let scene: SceneKind
    @State private var drillRequest: DrillRequest?

    var body: some View {
        let cards = PhraseBank.shared.phrases(in: scene)
        let owned = store.ownedBankIDs
        let fresh = cards.filter { !owned.contains($0.id) }
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                PageHeading(title: scene.title, caption: "\(cards.count) 枚の束")
                if !fresh.isEmpty {
                    Button {
                        let ids = fresh.prefix(5).map { store.addFromBank($0) }
                        drillRequest = DrillRequest(ids: ids)
                    } label: {
                        Label("新しい 5 枚をリングに通して練習", systemImage: "link")
                    }
                    .buttonStyle(InkButtonStyle(color: scene.swatch.deep, deep: Ink.text))
                } else {
                    Text("この束は、すべてリングに通しました。")
                        .font(.callout)
                        .foregroundStyle(Ink.sub)
                }
                ForEach(cards) { card in
                    BankCardRow(card: card, phrase: store.phrases.first { $0.bankID == card.id })
                }
            }
            .padding(.leading, 52)
            .padding(.trailing, Space.xl)
            .padding(.vertical, Space.xl)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(RuledPaper())
        .navigationTitle(scene.title)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $drillRequest) { request in
            DrillView(phraseIDs: request.ids)
        }
    }
}

/// 束の 1 枚：日本語・英語・覚えた度合い（マーカーの濃さ）
struct BankCardRow: View {
    let card: BankPhrase
    let phrase: Phrase?

    var body: some View {
        HStack(alignment: .top, spacing: Space.m) {
            RoundedRectangle(cornerRadius: 2)
                .fill(phrase.map { MarkerLevel.color(level(for: $0.review.box)) } ?? Ink.rule)
                .frame(width: 6)
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(card.ja)
                    .font(.subheadline)
                    .foregroundStyle(Ink.sub)
                Text(card.en)
                    .font(Typo.english(.body))
                    .foregroundStyle(phrase == nil ? Ink.sub : Ink.text)
            }
            Spacer(minLength: 0)
            if phrase != nil {
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundStyle(card.sceneKind.swatch.deep)
                    .accessibilityLabel("リングに通した")
            }
            SpeakButton(text: card.en)
        }
        .padding(.vertical, Space.xs)
        .accessibilityElement(children: .combine)
    }

    private func level(for box: Int) -> Int {
        switch box {
        case 0: 1
        case 1...2: 2
        case 3...5: 3
        default: 4
        }
    }
}

/// 自分のカード・リングのカードの 1 行
struct PhraseRow: View {
    let phrase: Phrase

    var body: some View {
        HStack(spacing: Space.m) {
            RoundedRectangle(cornerRadius: 2)
                .fill(MarkerLevel.color(min(phrase.review.box, 4)))
                .frame(width: 6, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(phrase.english)
                    .font(Typo.english(.body))
                    .foregroundStyle(Ink.text)
                    .lineLimit(2)
                Text(phrase.japanese)
                    .font(.footnote)
                    .foregroundStyle(Ink.sub)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Ink.sub)
        }
        .padding(Space.m)
        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Ink.card))
        .paperShadow()
    }
}
