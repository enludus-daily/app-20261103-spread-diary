import SwiftUI

/// きろく：連続の言い方、合計、練習のヒートマップ（18 週）、カード箱（覚えた順の仕切り）、言えるようになった英語
struct RecordView: View {
    @Environment(PhraseStore.self) private var store
    @State private var shareRequest: Phrase?
    @State private var handledScene = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    PageHeading(title: "きろく", caption: StreakMessage.text(streak: store.streak(), totalDays: store.totalDays,
                                                                         practicedToday: store.answeredCount() > 0 || store.isTodayLearned()))
                    HStack(spacing: Space.m) {
                        BigNumber(value: store.totalDays, label: "練習した日")
                        BigNumber(value: store.phrases.count, label: "リングのカード")
                        BigNumber(value: store.spokenPhrases.count, label: "言える英語")
                    }
                    SectionMark(title: "練習した日（18 週）", color: Ink.marker)
                    Heatmap(log: store.answerLog, learnedDays: store.learnedDays)
                    SectionMark(title: "カード箱", color: SceneKind.work.swatch.accent)
                    CardBoxChart(counts: BoxDistribution.counts(store.phrases))
                    SectionMark(title: "言えるようになった英語", color: SceneKind.feelings.swatch.accent)
                    if store.spokenPhrases.isEmpty {
                        StickyNote(color: SceneKind.feelings.swatch.soft) {
                            Text("まだありません").font(.headline)
                            Text("カード箱の 3 番目の仕切りまで進んだカードが、ここに並びます。カードの画像にして共有できます。")
                                .font(.callout)
                        }
                    } else {
                        ForEach(store.spokenPhrases.prefix(12)) { phrase in
                            HStack {
                                PhraseRow(phrase: phrase)
                                Button {
                                    shareRequest = phrase
                                } label: {
                                    Image(systemName: "square.and.arrow.up")
                                        .frame(width: 44, height: 44)
                                }
                                .accessibilityLabel("カードの画像で共有")
                            }
                        }
                    }
                }
                .padding(.leading, 52)
                .padding(.trailing, Space.xl)
                .padding(.vertical, Space.xl)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .background(RuledPaper())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $shareRequest) { phrase in
                ShareCardSheet(phrase: phrase)
            }
            .onAppear {
                guard !handledScene else { return }
                handledScene = true
                if ScreenshotScene.current == .share { shareRequest = store.spokenPhrases.first }
            }
        }
    }
}

/// 大きな数字（セリフ・字間を詰める）
struct BigNumber: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(value)")
                .font(.system(size: 40, weight: .regular, design: .serif))
                .kerning(-3)
                .monospacedDigit()
                .foregroundStyle(Ink.text)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(Typo.label(.caption))
                .kerning(0.6)
                .foregroundStyle(Ink.sub)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// 練習した日のヒートマップ：マス 14pt・間隔 3・マーカーの濃さ 5 段階（Canvas）
struct Heatmap: View {
    let log: [String: Int]
    let learnedDays: Set<String>
    private let weeks = 18
    private let cell: CGFloat = 14
    private let gap: CGFloat = 3

    var body: some View {
        let calendar = Calendar.current
        let columns = HeatmapGrid.columns(endingAt: .now, weeks: weeks, calendar: calendar)
        let values: [[Int]] = columns.map { column in
            column.map { day in
                let key = PhraseStore.dayKey(day, calendar: calendar)
                let count = log[key] ?? 0
                return max(HeatLevel.level(count), learnedDays.contains(key) ? 1 : 0)
            }
        }
        VStack(alignment: .leading, spacing: Space.s) {
            Canvas { context, _ in
                for (x, column) in values.enumerated() {
                    for (y, level) in column.enumerated() {
                        let rect = CGRect(x: CGFloat(x) * (cell + gap), y: CGFloat(y) * (cell + gap), width: cell, height: cell)
                        context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(MarkerLevel.color(level)))
                    }
                }
            }
            .frame(width: CGFloat(weeks) * (cell + gap), height: 7 * (cell + gap))
            HStack(spacing: Space.xs) {
                Text("少ない").font(Typo.label(.caption2)).foregroundStyle(Ink.sub)
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2).fill(MarkerLevel.color(level)).frame(width: 12, height: 12)
                }
                Text("多い").font(Typo.label(.caption2)).foregroundStyle(Ink.sub)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("この 18 週で練習した日は \(values.flatMap { $0 }.filter { $0 > 0 }.count) 日")
    }
}

/// カード箱：仕切り 0〜6 ごとの枚数を、立てたカードの高さで
struct CardBoxChart: View {
    let counts: [Int]

    var body: some View {
        let maxCount = max(counts.max() ?? 0, 1)
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .bottom, spacing: Space.s) {
                ForEach(Array(counts.enumerated()), id: \.offset) { box, count in
                    VStack(spacing: Space.xs) {
                        Text("\(count)")
                            .font(Typo.label(.caption))
                            .monospacedDigit()
                            .foregroundStyle(Ink.sub)
                        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                            .fill(MarkerLevel.color(min(box / 2 + (count > 0 ? 1 : 0), 4)))
                            .frame(height: 12 + 90 * CGFloat(count) / CGFloat(maxCount))
                        Text(verbatim: box == ReviewState.maxBox ? "覚えた" : "\(box)")
                            .font(Typo.label(.caption2))
                            .foregroundStyle(Ink.sub)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(Space.m)
            .background(
                UnevenRoundedRectangle(bottomLeadingRadius: Radius.tile, bottomTrailingRadius: Radius.tile, style: .continuous)
                    .strokeBorder(Ink.penDeep.opacity(0.4), lineWidth: 2)
            )
            Text("できると右の仕切りへ進み、間違えると 0 に戻ります。仕切りが進むほど、次に出るまでの日があきます（1・2・4・7・15・30 日）。")
                .font(.caption)
                .foregroundStyle(Ink.sub)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("カード箱。" + counts.enumerated().map { "仕切り\($0.offset) に \($0.element) 枚" }.joined(separator: "、"))
    }
}
