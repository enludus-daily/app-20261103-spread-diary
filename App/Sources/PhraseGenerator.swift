import Foundation

/// 日本語から作った英語の下書き（保存の前に直せる）
struct PhraseDraft: Equatable, Sendable, Identifiable {
    var id = UUID()
    var japanese: String
    var english: String
    var variants: [PhraseVariant]
    var words: [VocabItem]
    var source: Phrase.Source

    static func == (lhs: PhraseDraft, rhs: PhraseDraft) -> Bool {
        lhs.japanese == rhs.japanese && lhs.english == rhs.english && lhs.variants.map(\.english) == rhs.variants.map(\.english)
            && lhs.variants.map(\.label) == rhs.variants.map(\.label)
            && lhs.words.map(\.english) == rhs.words.map(\.english) && lhs.words.map(\.japanese) == rhs.words.map(\.japanese)
            && lhs.source == rhs.source
    }
}

enum GeneratorStatus: Equatable, Sendable {
    case available
    /// 使えない理由（画面に出す）
    case unavailable(String)
}

enum PhraseGenerationError: Error, Equatable {
    case emptyInput
    case emptyResult
}

/// 日本語から英語を作る役。本物は端末の中のモデル（OnDeviceGenerator）、テストでは偽物に差し替える。
protocol PhraseGenerator: Sendable {
    var status: GeneratorStatus { get }
    func generate(japanese: String) async throws -> PhraseDraft
}

/// モデルや翻訳の出力を整える（空・重複・長すぎを除く）
enum DraftCleaner {
    static func clean(
        japanese: String,
        english: String,
        variants: [(label: String, english: String)],
        words: [(english: String, japanese: String)],
        source: Phrase.Source
    ) throws -> PhraseDraft {
        let main = trim(english, max: Phrase.maxEnglishLength)
        guard !main.isEmpty else { throw PhraseGenerationError.emptyResult }
        var seenSentences: Set<String> = [main.lowercased()]
        var cleanVariants: [PhraseVariant] = []
        for variant in variants {
            let text = trim(variant.english, max: Phrase.maxEnglishLength)
            guard !text.isEmpty, seenSentences.insert(text.lowercased()).inserted else { continue }
            cleanVariants.append(PhraseVariant(label: trim(variant.label, max: 12), english: text))
        }
        var seenWords: Set<String> = []
        var cleanWords: [VocabItem] = []
        for word in words {
            let english = trim(word.english, max: 40)
            guard !english.isEmpty, seenWords.insert(english.lowercased()).inserted else { continue }
            cleanWords.append(VocabItem(english: english, japanese: trim(word.japanese, max: 40)))
        }
        return PhraseDraft(
            japanese: trim(japanese, max: Phrase.maxJapaneseLength),
            english: main,
            variants: cleanVariants,
            words: Array(cleanWords.prefix(Phrase.maxWords)),
            source: source
        )
    }

    private static func trim(_ text: String, max: Int) -> String {
        String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(max))
    }
}

/// モデルを使わない（使えない）ときの役
struct UnavailableGenerator: PhraseGenerator {
    var reason: String

    var status: GeneratorStatus { .unavailable(reason) }

    func generate(japanese: String) async throws -> PhraseDraft {
        throw PhraseGenerationError.emptyResult
    }
}
