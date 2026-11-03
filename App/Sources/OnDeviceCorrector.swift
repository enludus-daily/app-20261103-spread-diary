import Foundation
import FoundationModels

/// Apple Intelligence の端末の中のモデル（Foundation Models）で英文を直す。
/// 使えるかは SystemLanguageModel.availability で確かめる
/// （https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel）。
/// 通信はしない。CI のシミュレータでは本物のモデルが動く前提にしない（テストは偽物で書く）。
struct OnDeviceCorrector: SentenceCorrector {
    var status: CorrectorStatus {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            if model.supportsLocale(Locale(identifier: "en_US")) {
                return .available
            }
            return .unavailable("Apple Intelligence が英語に対応していない設定です。右のページに自分で直した文を書けます。")
        case .unavailable(.deviceNotEligible):
            return .unavailable("この iPhone は Apple Intelligence に対応していません。右のページに自分で直した文を書けます。")
        case .unavailable(.modelNotReady):
            return .unavailable("Apple Intelligence のモデルを準備中です。しばらくしてから試してください。それまでは自分で直した文を書けます。")
        case .unavailable:
            return .unavailable("Apple Intelligence が使えません（設定でオフ、または言語・地域が未対応の可能性）。右のページに自分で直した文を書けます。")
        @unknown default:
            return .unavailable("Apple Intelligence が使えません。右のページに自分で直した文を書けます。")
        }
    }

    func correct(_ text: String) async throws -> Correction {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CorrectionError.emptyInput }
        let session = LanguageModelSession(instructions: """
            You are a friendly English writing tutor for a Japanese learner. \
            The learner writes a short English diary entry. \
            Correct grammar, word choice and naturalness with as few changes as possible. \
            Keep the meaning, the tone and the writer's own words when they are fine. \
            Reply in exactly this format and nothing else:
            CORRECTED: <the corrected English text>
            NOTE: <one to three short bullet points in Japanese that explain the main changes, or 「直す所はありません」 if nothing needs to change>
            """)
        let prompt = "Diary entry:\n\(trimmed)"
        let response = try await session.respond(to: prompt)
        guard let correction = CorrectionParser.parse(response.content) else {
            throw CorrectionError.unreadableResponse
        }
        return correction
    }
}
