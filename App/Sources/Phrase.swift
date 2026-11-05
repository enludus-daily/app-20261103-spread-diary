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
        case bank         // アプリが用意した束
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
    /// 場面の束（nil は自分で作ったカード）
    var scene: String?
    /// 束のカードの ID（自分で作ったカードは nil）
    var bankID: String?

    var sceneKind: SceneKind { SceneKind(sceneID: scene) }

    private enum CodingKeys: String, CodingKey {
        case id, createdAt, japanese, english, variants, words, source, review, scene, bankID
    }

    /// 前の版で保存したデータ（scene・bankID がない）も読めるようにする
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        japanese = try c.decode(String.self, forKey: .japanese)
        english = try c.decode(String.self, forKey: .english)
        variants = try c.decodeIfPresent([PhraseVariant].self, forKey: .variants) ?? []
        words = try c.decodeIfPresent([VocabItem].self, forKey: .words) ?? []
        source = try c.decodeIfPresent(Source.self, forKey: .source) ?? .manual
        review = try c.decodeIfPresent(ReviewState.self, forKey: .review) ?? ReviewState(due: createdAt)
        scene = try c.decodeIfPresent(String.self, forKey: .scene)
        bankID = try c.decodeIfPresent(String.self, forKey: .bankID)
    }

    init(
        id: UUID = UUID(),
        createdAt: Date,
        japanese: String,
        english: String,
        variants: [PhraseVariant] = [],
        words: [VocabItem] = [],
        source: Source,
        review: ReviewState? = nil,
        scene: String? = nil,
        bankID: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.japanese = japanese
        self.english = english
        self.variants = variants
        self.words = words
        self.source = source
        self.review = review ?? ReviewState(due: createdAt)
        self.scene = scene
        self.bankID = bankID
    }

    mutating func clampLengths() {
        japanese = String(japanese.prefix(Self.maxJapaneseLength))
        english = String(english.prefix(Self.maxEnglishLength))
        words = Array(words.prefix(Self.maxWords))
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
