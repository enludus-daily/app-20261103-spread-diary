import AVFoundation

/// 英文を読み上げる（端末の音声。通信しない）
@MainActor
final class Speaker {
    static let shared = Speaker()
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        let scale = UserDefaults.standard.object(forKey: "settings.speechRate") as? Double ?? 0.9
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * Float(min(max(scale, 0.5), 1.2))
        synthesizer.speak(utterance)
    }
}
