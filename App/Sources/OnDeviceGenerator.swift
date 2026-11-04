import Foundation
import FoundationModels

/// Apple Intelligence の端末の中のモデル（Foundation Models）で、日本語から英語の言い方と単語を作る。
/// 使えるかは SystemLanguageModel.availability で確かめる
/// （https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel）。
/// 出力は guided generation（@Generable）で形を決める
/// （https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation）。
/// 通信はしない。CI のシミュレータでは本物のモデルが動く前提にしない（テストは偽物で書く）。
struct OnDeviceGenerator: PhraseGenerator {
    var status: GeneratorStatus {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            if model.supportsLocale(Locale(identifier: "ja_JP")) {
                return .available
            }
            return .unavailable("Apple Intelligence が日本語に対応していない設定です。Apple の翻訳で英語にします。")
        case .unavailable(.deviceNotEligible):
            return .unavailable("この iPhone は Apple Intelligence に対応していません。Apple の翻訳で英語にします。")
        case .unavailable(.modelNotReady):
            return .unavailable("Apple Intelligence のモデルを準備中です。それまでは Apple の翻訳で英語にします。")
        case .unavailable:
            return .unavailable("Apple Intelligence が使えません（設定でオフなど）。Apple の翻訳で英語にします。")
        @unknown default:
            return .unavailable("Apple Intelligence が使えません。Apple の翻訳で英語にします。")
        }
    }

    func generate(japanese: String) async throws -> PhraseDraft {
        let input = japanese.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { throw PhraseGenerationError.emptyInput }
        let session = LanguageModelSession(instructions: """
            You help a Japanese learner of English. \
            The learner writes, in Japanese, something they want to say in daily life or at work. \
            Write natural, short English that a native speaker would actually say. \
            Do not add facts that are not in the Japanese. \
            Pick useful words or phrases from your natural sentence and explain each meaning in Japanese.
            """)
        let prompt = "Japanese: \(input)"
        let response = try await session.respond(to: prompt, generating: GeneratedPhrase.self)
        let result = response.content
        return try DraftCleaner.clean(
            japanese: input,
            english: result.natural,
            variants: [(label: "丁寧", english: result.polite), (label: "くだけた", english: result.casual)],
            words: result.words.map { (english: $0.english, japanese: $0.japanese) },
            source: .model
        )
    }
}

@Generable
struct GeneratedPhrase {
    @Guide(description: "The most natural English sentence for the Japanese input")
    var natural: String

    @Guide(description: "A more polite way to say it")
    var polite: String

    @Guide(description: "A more casual way to say it")
    var casual: String

    @Guide(description: "Two to five useful English words or short phrases taken from the natural sentence")
    var words: [GeneratedWord]
}

@Generable
struct GeneratedWord {
    @Guide(description: "The English word or short phrase exactly as it appears in the natural sentence")
    var english: String

    @Guide(description: "Its meaning in Japanese, a few words")
    var japanese: String
}
