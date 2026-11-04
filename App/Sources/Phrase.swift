import Foundation

/// 単語・言い回しのカード
struct VocabItem: Codable, Equatable, Hashable, Sendable, Identifiable {
    var id: UUID
    var english: String
    var japanese: String

    init(id: UUID = UUID(), english: String, japanese: String) {
        self.id = id
        self.english = english
        self.japanese = japanese
    }
}

/// 言い方の違い（丁寧・くだけた など）
struct PhraseVariant: Codable, Equatable, Hashable, Sendable, Identifiable {
    var id: UUID
    var label: String
    var english: String

    init(id: UUID = UUID(), label: String, english: String) {
        self.id = id
        self.label = label
        self.english = english
    }
}

/// 日本語で言いたいことと、その英語。ドリルの材料になる。
struct Phrase: Codable, Identifiable, Equatable, Sendable {
    /// 英語をだれが作ったか
    enum Source: String, Codable, Sendable {
        case model        // Apple Intelligence（端末の中のモデル）
        case translation  // Apple の翻訳（端末の中）
        case manual       // 自分で書いた
    }

    static let maxJapaneseLength = 200
    static let maxEnglishLength = 300
    static let maxWords = 6

    var id: UUID
    var createdAt: Date
    var japanese: String
    var english: String
    var variants: [PhraseVariant]
    var words: [VocabItem]
    var source: Source
    var review: ReviewState

    init(
        id: UUID = UUID(),
        createdAt: Date,
        japanese: String,
        english: String,
        variants: [PhraseVariant] = [],
        words: [VocabItem] = [],
        source: Source,
        review: ReviewState? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.japanese = japanese
        self.english = english
        self.variants = variants
        self.words = words
        self.source = source
        self.review = review ?? ReviewState(due: createdAt)
    }

    mutating func clampLengths() {
        japanese = String(japanese.prefix(Self.maxJapaneseLength))
        english = String(english.prefix(Self.maxEnglishLength))
        words = Array(words.prefix(Self.maxWords))
    }

    static func samples(now: Date) -> [Phrase] {
        [
            Phrase(
                createdAt: now,
                japanese: "明日の会議、少し遅らせてもらえますか？",
                english: "Could we push tomorrow's meeting back a little?",
                variants: [
                    PhraseVariant(label: "丁寧", english: "Would it be possible to move tomorrow's meeting a little later?"),
                    PhraseVariant(label: "くだけた", english: "Can we push tomorrow's meeting back a bit?"),
                ],
                words: [
                    VocabItem(english: "push back", japanese: "（予定を）遅らせる"),
                    VocabItem(english: "a little", japanese: "少し"),
                ],
                source: .manual
            ),
            Phrase(
                createdAt: now.addingTimeInterval(-60),
                japanese: "駅までの道を教えてもらえますか？",
                english: "Could you tell me the way to the station?",
                variants: [
                    PhraseVariant(label: "くだけた", english: "How do I get to the station?"),
                ],
                words: [
                    VocabItem(english: "the way to", japanese: "〜への道"),
                    VocabItem(english: "station", japanese: "駅"),
                ],
                source: .manual
            ),
        ]
    }
}

/// 間隔をあけた復習（箱を進める方式）
struct ReviewState: Codable, Equatable, Sendable {
    /// 箱ごとの、次に出すまでの日数
    static let intervals = [0, 1, 2, 4, 7, 15, 30]

    var box: Int
    var due: Date
    var correctCount: Int
    var wrongCount: Int

    init(box: Int = 0, due: Date, correctCount: Int = 0, wrongCount: Int = 0) {
        self.box = box
        self.due = due
        self.correctCount = correctCount
        self.wrongCount = wrongCount
    }

    static var maxBox: Int { intervals.count - 1 }

    var isMastered: Bool { box >= Self.maxBox }

    func isDue(now: Date) -> Bool { due <= now }

    /// できた → 箱を 1 つ進め、その箱の日数だけ先に出す。できなかった → 最初の箱に戻し、すぐまた出す。
    mutating func record(correct: Bool, now: Date, calendar: Calendar) {
        if correct {
            box = min(box + 1, Self.maxBox)
            correctCount += 1
            let start = calendar.startOfDay(for: now)
            due = calendar.date(byAdding: .day, value: Self.intervals[box], to: start) ?? now
        } else {
            box = 0
            wrongCount += 1
            due = now
        }
    }
}
