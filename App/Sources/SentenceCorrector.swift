import Foundation

/// 直した文と、短い説明
struct Correction: Equatable, Sendable {
    var corrected: String
    var note: String
}

enum CorrectorStatus: Equatable, Sendable {
    case available
    /// 使えない理由（画面に出す）
    case unavailable(String)
}

enum CorrectionError: Error, Equatable {
    case emptyInput
    case unreadableResponse
}

/// 英文を直す役。本物は端末の中のモデル（OnDeviceCorrector）、テストでは偽物に差し替える。
protocol SentenceCorrector: Sendable {
    var status: CorrectorStatus { get }
    func correct(_ text: String) async throws -> Correction
}

/// モデルの答え（決めた形）を読み取る。
///   CORRECTED: <直した文>
///   NOTE: <説明>
enum CorrectionParser {
    private static let trimSet = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "*"))

    static func parse(_ raw: String) -> Correction? {
        guard let correctedMarker = raw.range(of: "CORRECTED:", options: .caseInsensitive) else { return nil }
        let rest = raw[correctedMarker.upperBound...]
        let correctedPart: Substring
        var note = ""
        if let noteMarker = rest.range(of: "NOTE:", options: .caseInsensitive) {
            correctedPart = rest[..<noteMarker.lowerBound]
            note = rest[noteMarker.upperBound...].trimmingCharacters(in: trimSet)
        } else {
            correctedPart = rest
        }
        let corrected = correctedPart.trimmingCharacters(in: trimSet)
        guard !corrected.isEmpty else { return nil }
        return Correction(
            corrected: String(corrected.prefix(DiaryEntry.maxLength)),
            note: String(note.prefix(DiaryEntry.maxLength))
        )
    }
}

/// モデルを使わない（使えない）ときの役
struct UnavailableCorrector: SentenceCorrector {
    var reason: String

    var status: CorrectorStatus { .unavailable(reason) }

    func correct(_ text: String) async throws -> Correction {
        throw CorrectionError.unreadableResponse
    }
}
