import Foundation

/// 手で用意したフレーズの束（App/Resources/PhraseBank.json。元は data/bank/*.txt）
struct BankWord: Codable, Equatable, Hashable, Sendable {
    let en: String
    let ja: String
}

struct BankPhrase: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let scene: String
    let ja: String
    let en: String
    let polite: String
    let casual: String
    let words: [BankWord]

    var sceneKind: SceneKind { SceneKind(sceneID: scene) }

    /// 自分のリングに通すときの下書き
    var draft: PhraseDraft {
        PhraseDraft(
            japanese: ja,
            english: en,
            variants: [PhraseVariant(label: "丁寧", english: polite), PhraseVariant(label: "くだけた", english: casual)],
            words: words.map { VocabItem(english: $0.en, japanese: $0.ja) },
            source: .bank
        )
    }
}

/// アプリの束を読むための目印（テストからも同じ bundle を探せる）
final class BankBundleToken {}

struct PhraseBank: Sendable {
    let phrases: [BankPhrase]

    private struct File: Decodable {
        let phrases: [BankPhrase]
    }

    enum LoadError: Error {
        case missing
    }

    static func load(bundle: Bundle = Bundle(for: BankBundleToken.self)) throws -> PhraseBank {
        guard let url = bundle.url(forResource: "PhraseBank", withExtension: "json") else { throw LoadError.missing }
        let data = try Data(contentsOf: url)
        return PhraseBank(phrases: try JSONDecoder().decode(File.self, from: data).phrases)
    }

    /// 読めなかったときは空の束（画面で「束を読み込めませんでした」を出す）
    static let shared: PhraseBank = (try? load()) ?? PhraseBank(phrases: [])

    func phrases(in scene: SceneKind) -> [BankPhrase] {
        phrases.filter { $0.scene == scene.rawValue }
    }

    func phrase(id: String) -> BankPhrase? {
        phrases.first { $0.id == id }
    }
}

/// 今日の 3 枚：まだリングに通していないカードから、日付で決まる順に選ぶ（同じ日は何度開いても同じ）
enum TodayPlanner {
    static func picks(bank: [BankPhrase], owned: Set<String>, scenes: Set<String>, dayKey: String, count: Int) -> [String] {
        let fresh = bank.filter { !owned.contains($0.id) }
        var pool = fresh.filter { scenes.contains($0.scene) }
        if pool.isEmpty { pool = fresh }
        var ids = pool.map(\.id).sorted()
        var rng = SeededRandom(seed: seed(dayKey))
        ids.shuffle(using: &rng)
        return Array(ids.prefix(count))
    }

    /// FNV-1a（日付の文字列から決まった種を作る）
    static func seed(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        return hash
    }
}

/// 連続記録の言い方：途切れても責めない（StudyReel の「おかえり! 今年は合計○日」の考え方）
enum StreakMessage {
    static func text(streak: Int, totalDays: Int, practicedToday: Bool) -> String {
        if totalDays == 0 { return "今日が 1 日目。3 枚だけめくってみよう" }
        if streak >= 2 { return practicedToday ? "\(streak) 日続いています" : "\(streak) 日続いています。今日も 1 枚どうぞ" }
        if streak == 1 && practicedToday { return totalDays > 1 ? "今日もできました。合計 \(totalDays) 日" : "1 日目、できました" }
        if streak == 1 { return "昨日の続きから。合計 \(totalDays) 日" }
        return "おかえりなさい。これまでに合計 \(totalDays) 日"
    }
}

/// 練習した量の濃さ（ヒートマップ）：0 / 1〜2 / 3〜5 / 6〜9 / 10 以上 の 5 段階
enum HeatLevel {
    static func level(_ count: Int) -> Int {
        switch count {
        case ..<1: 0
        case 1...2: 1
        case 3...5: 2
        case 6...9: 3
        default: 4
        }
    }
}

/// ヒートマップのマス：月曜始まりの週ごとの列（古い順）。今日より先の日は入れない
enum HeatmapGrid {
    static func columns(endingAt today: Date, weeks: Int, calendar: Calendar) -> [[Date]] {
        var cal = calendar
        cal.firstWeekday = 2
        let todayStart = cal.startOfDay(for: today)
        guard let thisWeek = cal.dateInterval(of: .weekOfYear, for: todayStart)?.start,
              let first = cal.date(byAdding: .weekOfYear, value: -(weeks - 1), to: thisWeek) else { return [] }
        return (0..<weeks).compactMap { w in
            guard let weekStart = cal.date(byAdding: .weekOfYear, value: w, to: first) else { return nil }
            return (0..<7).compactMap { d in
                guard let day = cal.date(byAdding: .day, value: d, to: weekStart), day <= todayStart else { return nil }
                return day
            }
        }
    }
}

/// カード箱の仕切りごとの枚数（覚えた度合い 0〜6）
enum BoxDistribution {
    static func counts(_ phrases: [Phrase]) -> [Int] {
        var result = Array(repeating: 0, count: ReviewState.maxBox + 1)
        for phrase in phrases {
            result[min(max(phrase.review.box, 0), ReviewState.maxBox)] += 1
        }
        return result
    }
}
