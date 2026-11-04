import SwiftUI

// MARK: - あいさつ・今日の目標・1 週間

struct HeroHeader: View {
    let answered: Int
    let progress: Double
    let streak: Int
    let week: [(date: Date, count: Int)]

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<11: "おはようございます"
        case 11..<17: "こんにちは"
        default: "こんばんは"
        }
    }

    private var headline: String {
        let remaining = PhraseStore.dailyGoal - answered
        return remaining <= 0 ? "今日の目標、達成！" : "今日の目標まで\nあと \(remaining) 問"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(greeting)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(headline)
                        .font(.title3.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Label("\(streak) 日連続", systemImage: "flame.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(streak > 0 ? Theme.coral : Color.secondary)
                        .symbolEffect(.bounce, value: streak)
                }
                Spacer(minLength: 0)
                ZStack {
                    GoalRing(progress: progress, lineWidth: 10)
                    VStack(spacing: 0) {
                        Text("\(min(answered, 99))")
                            .font(.title2.weight(.heavy))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("/ \(PhraseStore.dailyGoal) 問")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 84, height: 84)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("今日 \(answered) 問、目標 \(PhraseStore.dailyGoal) 問")
            }
            WeekStrip(week: week)
        }
        .card()
    }
}

private struct WeekStrip: View {
    let week: [(date: Date, count: Int)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(week.enumerated()), id: \.offset) { index, day in
                let isToday = index == week.count - 1
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(day.count > 0 ? AnyShapeStyle(Theme.brand) : AnyShapeStyle(Color.primary.opacity(0.06)))
                        if day.count >= PhraseStore.dailyGoal {
                            Image(systemName: "star.fill").font(.caption2).foregroundStyle(.white)
                        } else if day.count > 0 {
                            Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(.white)
                        }
                    }
                    .frame(width: 28, height: 28)
                    .overlay(Circle().strokeBorder(isToday ? Theme.pink : Color.clear, lineWidth: 2).padding(-3))
                    Text(day.date.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2.weight(isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? Color.primary : Color.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("この 1 週間で練習した日 \(week.filter { $0.count > 0 }.count) 日")
    }
}

// MARK: - 入力

struct ComposeCard: View {
    @Binding var japanese: String
    let isGenerating: Bool
    let status: GeneratorStatus
    let onSubmit: () -> Void

    private static let examples = [
        "明日の会議、少し遅らせてもらえますか？",
        "おすすめは何ですか？",
        "もう一度言ってもらえますか？",
        "それ、すごくいいと思う！",
        "今日は早めに帰ります",
    ]

    private var buttonTitle: String {
        isGenerating ? "英語にしています…" : "英語にしてドリルを作る"
    }

    private var isEmpty: Bool {
        japanese.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("言いたいことを日本語で")
                    .font(.headline)
            } icon: {
                Image(systemName: "character.bubble.fill")
                    .foregroundStyle(Theme.brand)
            }
            TextField("例：明日の会議、少し遅らせてもらえますか？", text: $japanese, axis: .vertical)
                .lineLimit(2...5)
                .padding(12)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .onChange(of: japanese) { _, newValue in
                    if newValue.count > Phrase.maxJapaneseLength {
                        japanese = String(newValue.prefix(Phrase.maxJapaneseLength))
                    }
                }
            if isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Self.examples, id: \.self) { example in
                            Button(example) { japanese = example }
                                .font(.footnote)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Theme.coral.opacity(0.12), in: Capsule())
                                .foregroundStyle(Theme.pink)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            Button(action: onSubmit) {
                HStack(spacing: 8) {
                    if isGenerating {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(buttonTitle)
                }
            }
            .buttonStyle(BrandButtonStyle())
            .disabled(isGenerating || isEmpty)
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: status == .available ? "apple.intelligence" : "translate")
                    .foregroundStyle(.secondary)
                switch status {
                case .available:
                    Text("Apple Intelligence が端末の中で、言い方の違いと単語も作ります（通信しません）。")
                case .unavailable(let reason):
                    Text(reason)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .card()
    }
}

// MARK: - 今日のドリル

struct TodayCard: View {
    let dueCount: Int
    let extraCount: Int
    let nextReview: String?
    let mastered: Int
    let total: Int
    let onStart: () -> Void
    let onExtra: () -> Void

    private var startTitle: String {
        "今日のドリルを始める（\(dueCount) 問）"
    }

    private var minutes: Int { max(1, (dueCount * 20 + 59) / 60) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("今日の復習", systemImage: "rectangle.stack.fill")
                    .font(.headline)
                Spacer()
                Text("覚えた \(mastered) / \(total)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.mint)
            }
            if dueCount > 0 {
                Text("約 \(minutes) 分。忘れかけたフレーズから出します。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button(action: onStart) {
                    Label(startTitle, systemImage: "play.fill")
                }
                .buttonStyle(BrandButtonStyle())
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.mint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("今日の復習はおわり！")
                            .font(.body.weight(.semibold))
                        if let nextReview {
                            Text(nextReview)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if extraCount > 0 {
                    Button(action: onExtra) {
                        Label("もっと練習する（\(extraCount) 問）", systemImage: "bolt.fill")
                    }
                    .buttonStyle(BrandButtonStyle(fill: AnyShapeStyle(Theme.indigo)))
                }
            }
        }
        .card()
    }
}

// MARK: - 一覧の行

struct PhraseRow: View {
    let phrase: Phrase

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                GoalRing(progress: Double(phrase.review.box) / Double(ReviewState.maxBox), lineWidth: 4)
                if phrase.review.isMastered {
                    Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(Theme.mint)
                } else {
                    Text("\(phrase.review.box)").font(.caption.weight(.bold)).monospacedDigit()
                }
            }
            .frame(width: 32, height: 32)
            .accessibilityLabel("覚えた度合い \(phrase.review.box) / \(ReviewState.maxBox)")
            VStack(alignment: .leading, spacing: 3) {
                Text(phrase.english)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                Text(phrase.japanese)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView(generator: UnavailableGenerator(reason: "プレビュー"))
        .environment(PhraseStore(defaults: UserDefaults(suiteName: "preview")!))
}
