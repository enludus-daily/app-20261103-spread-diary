import Foundation

/// 1 日分の英文。左のページ（自分の文）と右のページ（直した文と説明）を持つ。
struct DiaryEntry: Codable, Identifiable, Equatable, Sendable {
    /// 右のページをだれが書いたか
    enum Source: String, Codable, Sendable {
        case none     // まだ直していない
        case model    // Apple Intelligence（端末の中のモデル）の提案
        case manual   // 自分で書き直した
    }

    /// 1 ページに書ける文字数の上限（端末の中のモデルに渡す長さも抑える）
    static let maxLength = 600

    var id: UUID
    var date: Date
    var original: String
    var corrected: String
    var note: String
    var source: Source
    var isSample: Bool

    init(
        id: UUID = UUID(),
        date: Date,
        original: String = "",
        corrected: String = "",
        note: String = "",
        source: Source = .none,
        isSample: Bool = false
    ) {
        self.id = id
        self.date = date
        self.original = original
        self.corrected = corrected
        self.note = note
        self.source = source
        self.isSample = isSample
    }

    var hasOriginal: Bool {
        !original.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasCorrection: Bool {
        !corrected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 上限を超えた分を切る
    mutating func clampLengths() {
        original = String(original.prefix(Self.maxLength))
        corrected = String(corrected.prefix(Self.maxLength))
        note = String(note.prefix(Self.maxLength))
    }

    static func sample(date: Date) -> DiaryEntry {
        DiaryEntry(
            date: date,
            original: "Yesterday I go to the library and borrow two books. I am exciting to read them.",
            corrected: "Yesterday I went to the library and borrowed two books. I am excited to read them.",
            note: "・過去のことなので go → went、borrow → borrowed。\n・自分の気持ちは excited（exciting は「わくわくさせる」側）。",
            source: .manual,
            isSample: true
        )
    }
}
