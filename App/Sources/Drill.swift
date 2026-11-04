import Foundation

/// 英文を単語に分ける・比べるための形にする
enum Tokenizer {
    private static let edgePunctuation = CharacterSet(charactersIn: ".,!?;:\"“”‘’()[]…")

    static func tokens(_ text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    /// 前後の記号を取る（大文字・小文字は残す）
    static func core(_ token: String) -> String {
        token.trimmingCharacters(in: edgePunctuation)
    }

    /// 後ろに付いた記号（"station?" → "?"）
    static func trailingPunctuation(_ token: String) -> String {
        let tail = token.reversed().prefix { character in
            character.unicodeScalars.allSatisfy { edgePunctuation.contains($0) }
        }
        return String(tail.reversed())
    }

    /// 比べるための形（記号を取り、小文字）
    static func normalized(_ token: String) -> String {
        core(token).lowercased()
    }
}

enum QuizKind: String, Equatable, Sendable {
    case scramble  // 並べ替え
    case cloze     // 穴埋め
    case recall    // 日本語を見て英語を言う
}

struct ScrambleQuestion: Equatable, Sendable {
    let answer: [String]
    let pieces: [String]

    func isCorrect(_ order: [String]) -> Bool {
        order.map(Tokenizer.normalized) == answer.map(Tokenizer.normalized)
    }
}

struct ClozeQuestion: Equatable, Sendable {
    /// 穴の所は "____"（後ろの記号は残す）
    let displayTokens: [String]
    let answer: String
    let choices: [String]

    func isCorrect(_ choice: String) -> Bool {
        Tokenizer.normalized(choice) == Tokenizer.normalized(answer)
    }
}

enum Question: Equatable, Sendable {
    case scramble(ScrambleQuestion)
    case cloze(ClozeQuestion)
    case recall
}

/// 今日のドリルを組み立てる
enum DrillPlanner {
    static let maxPerSession = 10
    static let blank = "____"
    private static let stopWords: Set<String> = [
        "the", "a", "an", "to", "of", "in", "on", "at", "for", "and", "or", "but", "is", "are", "am",
        "was", "were", "be", "i", "you", "we", "he", "she", "it", "they", "me", "my", "your", "our",
        "do", "does", "did", "can", "could", "would", "will", "this", "that",
    ]
    private static let fallbackDistractors = ["make", "take", "bring", "keep", "find", "give", "leave", "send"]

    /// 出す時期が来たフレーズ（早い順、上限つき）
    static func duePhrases(_ phrases: [Phrase], now: Date) -> [Phrase] {
        phrases
            .filter { $0.review.isDue(now: now) && !Tokenizer.tokens($0.english).isEmpty }
            .sorted { ($0.review.due, $0.createdAt) < ($1.review.due, $1.createdAt) }
            .prefix(maxPerSession)
            .map { $0 }
    }

    /// 箱が浅いうちは並べ替え（見て分かる）→ 穴埋め → 何も見ずに言う
    static func kind(for phrase: Phrase) -> QuizKind {
        let tokens = Tokenizer.tokens(phrase.english)
        switch phrase.review.box {
        case 0 where tokens.count >= 3:
            return .scramble
        case 0, 1:
            return blankIndex(tokens: tokens, words: phrase.words) == nil ? .recall : .cloze
        default:
            return .recall
        }
    }

    static func makeQuestion<R: RandomNumberGenerator>(
        for phrase: Phrase,
        pool: [String],
        using rng: inout R
    ) -> Question {
        switch kind(for: phrase) {
        case .scramble:
            return .scramble(makeScramble(phrase.english, using: &rng))
        case .cloze:
            if let cloze = makeCloze(phrase, pool: pool, using: &rng) {
                return .cloze(cloze)
            }
            return .recall
        case .recall:
            return .recall
        }
    }

    static func makeScramble<R: RandomNumberGenerator>(_ english: String, using rng: inout R) -> ScrambleQuestion {
        let answer = Tokenizer.tokens(english)
        var pieces = answer
        if Set(answer).count > 1 {
            // 元の並びのままにならないように混ぜる
            for _ in 0..<10 {
                pieces.shuffle(using: &rng)
                if pieces != answer { break }
            }
        }
        return ScrambleQuestion(answer: answer, pieces: pieces)
    }

    /// 穴にする単語：カードの単語が文にあればそれ、なければいちばん長い（よく使う短い語を除く）単語
    static func blankIndex(tokens: [String], words: [VocabItem]) -> Int? {
        let vocab = Set(words.flatMap { Tokenizer.tokens($0.english) }.map(Tokenizer.normalized))
        let candidates = tokens.indices.filter { index in
            let word = Tokenizer.normalized(tokens[index])
            return word.count >= 3 && !stopWords.contains(word)
        }
        if let vocabIndex = candidates.first(where: { vocab.contains(Tokenizer.normalized(tokens[$0])) }) {
            return vocabIndex
        }
        return candidates.max { Tokenizer.core(tokens[$0]).count < Tokenizer.core(tokens[$1]).count }
    }

    static func makeCloze<R: RandomNumberGenerator>(
        _ phrase: Phrase,
        pool: [String],
        using rng: inout R
    ) -> ClozeQuestion? {
        let tokens = Tokenizer.tokens(phrase.english)
        guard let index = blankIndex(tokens: tokens, words: phrase.words) else { return nil }
        let answer = Tokenizer.core(tokens[index])
        let trailing = Tokenizer.trailingPunctuation(tokens[index])
        var display = tokens
        display[index] = blank + trailing

        let answerKey = answer.lowercased()
        var seen: Set<String> = [answerKey]
        var distractors: [String] = []
        for word in (pool + fallbackDistractors).map(Tokenizer.core) {
            let key = word.lowercased()
            guard key.count >= 3, !stopWords.contains(key), !seen.contains(key) else { continue }
            seen.insert(key)
            distractors.append(word.lowercased())
        }
        distractors.shuffle(using: &rng)
        var choices = [answer] + distractors.prefix(3)
        choices.shuffle(using: &rng)
        return ClozeQuestion(displayTokens: display, answer: answer, choices: choices)
    }

    /// 穴埋めの選択肢の材料：ほかのフレーズの単語
    static func distractorPool(_ phrases: [Phrase], excluding id: UUID) -> [String] {
        phrases
            .filter { $0.id != id }
            .flatMap { phrase in
                phrase.words.flatMap { Tokenizer.tokens($0.english) } + Tokenizer.tokens(phrase.english)
            }
    }
}

/// 種を決められる乱数（テストで同じ結果にするため）。SplitMix64。
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
