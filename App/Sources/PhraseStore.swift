import Foundation
import Observation

/// フレーズとドリルの記録の保存（端末の UserDefaults だけ。PrivacyInfo.xcprivacy に CA92.1 で申告済み）
@MainActor
@Observable
final class PhraseStore {
    private(set) var phrases: [Phrase] = []
    private(set) var drillDays: [Date] = []
    /// 日ごとの答えた数（"yyyy-MM-dd" → 数）
    private(set) var answerLog: [String: Int] = [:]

    /// 1 日の目標（答える数）
    static let dailyGoal = 5

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key: String

    init(defaults: UserDefaults = .standard, key: String = "phrases.v1") {
        self.defaults = defaults
        self.key = key
        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode([Phrase].self, from: data) {
            phrases = saved
        }
        if let data = defaults.data(forKey: daysKey),
           let saved = try? JSONDecoder().decode([Date].self, from: data) {
            drillDays = saved
        }
        if let data = defaults.data(forKey: logKey),
           let saved = try? JSONDecoder().decode([String: Int].self, from: data) {
            answerLog = saved
        }
        if let data = defaults.data(forKey: todayKey),
           let saved = try? JSONDecoder().decode([String: [String]].self, from: data) {
            todayPicks = saved
        }
        learnedDays = Set(defaults.stringArray(forKey: learnedKey) ?? [])
    }

    // MARK: - 今日の 3 枚

    /// 日ごとの今日のカード（"yyyy-MM-dd" → 束の ID）。今日の分だけ残す
    private(set) var todayPicks: [String: [String]] = [:]
    /// 今日の 3 枚をめくり終えた日
    private(set) var learnedDays: Set<String> = []
    private var todayKey: String { key + ".today" }
    private var learnedKey: String { key + ".learned" }

    var ownedBankIDs: Set<String> {
        Set(phrases.compactMap(\.bankID))
    }

    /// 今日の 3 枚（同じ日は何度開いても同じカード）
    func todayCards(bank: PhraseBank, count: Int = 3, scenes: Set<String> = Set(SceneKind.bankScenes.map(\.rawValue)),
                    now: Date = .now, calendar: Calendar = .current) -> [BankPhrase] {
        let day = Self.dayKey(now, calendar: calendar)
        if let ids = todayPicks[day], ids.count == count || learnedDays.contains(day) {
            return ids.compactMap(bank.phrase(id:))
        }
        let ids = TodayPlanner.picks(bank: bank.phrases, owned: ownedBankIDs, scenes: scenes, dayKey: day, count: count)
        todayPicks = [day: ids]
        if let data = try? JSONEncoder().encode(todayPicks) {
            defaults.set(data, forKey: todayKey)
        }
        return ids.compactMap(bank.phrase(id:))
    }

    func isTodayLearned(now: Date = .now, calendar: Calendar = .current) -> Bool {
        learnedDays.contains(Self.dayKey(now, calendar: calendar))
    }

    /// 今日のカードをリングに通す（もう通したカードは足さない）。めくった日も記録する
    @discardableResult
    func learnToday(_ cards: [BankPhrase], now: Date = .now, calendar: Calendar = .current) -> [UUID] {
        let ids = cards.map { addFromBank($0, now: now) }
        learnedDays.insert(Self.dayKey(now, calendar: calendar))
        defaults.set(Array(learnedDays).sorted().suffix(400), forKey: learnedKey)
        recordDrillFinished(now: now, calendar: calendar)
        return ids
    }

    /// 束のカードを自分のリングに通す（同じカードは 1 枚だけ）
    @discardableResult
    func addFromBank(_ card: BankPhrase, now: Date = .now) -> UUID {
        if let existing = phrases.first(where: { $0.bankID == card.id }) {
            return existing.id
        }
        var phrase = Phrase(
            createdAt: now,
            japanese: card.ja,
            english: card.en,
            variants: card.draft.variants,
            words: card.draft.words,
            source: .bank,
            scene: card.scene,
            bankID: card.id
        )
        phrase.clampLengths()
        phrases.append(phrase)
        save()
        return phrase.id
    }

    func phrases(in scene: SceneKind) -> [Phrase] {
        phrases.filter { $0.sceneKind == scene }
    }

    /// 練習した日の合計（答えた日と、今日の 3 枚をめくった日）
    var totalDays: Int {
        Set(answerLog.filter { $0.value > 0 }.keys).union(learnedDays).count
    }

    /// 言えるようになったフレーズ（箱 3 以上）。新しく上がった順
    var spokenPhrases: [Phrase] {
        phrases.filter { $0.review.box >= 3 }.sorted { ($0.review.box, $0.review.correctCount) > ($1.review.box, $1.review.correctCount) }
    }

    /// スクリーンショット用の見本の記録（CI でだけ使う。別の保存場所に入れる）
    func applyDemo(bank: PhraseBank, now: Date, calendar: Calendar) {
        let picks = Array(bank.phrases.enumerated().filter { $0.offset % 9 == 0 }.map(\.element).prefix(28))
        for (i, card) in picks.enumerated() {
            let id = addFromBank(card, now: now.addingTimeInterval(-Double(i) * 3_600))
            update(id: id) { phrase in
                phrase.review.box = [0, 1, 2, 3, 4, 5, 6, 2, 1, 3][i % 10]
                phrase.review.correctCount = phrase.review.box * 2
                phrase.review.due = i % 3 == 0 ? now.addingTimeInterval(-60) : now.addingTimeInterval(86_400 * Double(1 + i % 4))
            }
        }
        for offset in 0..<70 where offset % 5 != 3 && offset % 11 != 7 {
            guard let day = calendar.date(byAdding: .day, value: -offset - 1, to: now) else { continue }
            answerLog[Self.dayKey(day, calendar: calendar)] = (offset * 7) % 13
            if offset < 9 { drillDays.append(calendar.startOfDay(for: day)) }
        }
        answerLog[Self.dayKey(now, calendar: calendar)] = 3
        drillDays.append(calendar.startOfDay(for: now))
        if let data = try? JSONEncoder().encode(answerLog) { defaults.set(data, forKey: logKey) }
        if let data = try? JSONEncoder().encode(drillDays) { defaults.set(data, forKey: daysKey) }
    }

    private var daysKey: String { key + ".drillDays" }
    private var logKey: String { key + ".answerLog" }

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    func answeredCount(on date: Date = .now, calendar: Calendar = .current) -> Int {
        answerLog[Self.dayKey(date, calendar: calendar)] ?? 0
    }

    /// 今日の目標の進み（0〜1）
    func goalProgress(now: Date = .now, calendar: Calendar = .current) -> Double {
        min(Double(answeredCount(on: now, calendar: calendar)) / Double(Self.dailyGoal), 1)
    }

    /// 直近 7 日（古い順）の答えた数
    func week(endingAt today: Date = .now, calendar: Calendar = .current) -> [(date: Date, count: Int)] {
        let start = calendar.startOfDay(for: today)
        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: start) else { return nil }
            return (date: day, count: answeredCount(on: day, calendar: calendar))
        }
    }

    /// 新しい順
    var sortedPhrases: [Phrase] {
        phrases.sorted { $0.createdAt > $1.createdAt }
    }

    func phrase(id: UUID) -> Phrase? {
        phrases.first { $0.id == id }
    }

    func dueCount(now: Date = .now) -> Int {
        DrillPlanner.duePhrases(phrases, now: now).count
    }

    var masteredCount: Int {
        phrases.filter(\.review.isMastered).count
    }

    @discardableResult
    func add(_ draft: PhraseDraft, now: Date = .now) -> UUID {
        var phrase = Phrase(
            createdAt: now,
            japanese: draft.japanese,
            english: draft.english,
            variants: draft.variants,
            words: draft.words,
            source: draft.source
        )
        phrase.clampLengths()
        phrases.append(phrase)
        save()
        return phrase.id
    }

    func update(id: UUID, _ change: (inout Phrase) -> Void) {
        guard let index = phrases.firstIndex(where: { $0.id == id }) else { return }
        var phrase = phrases[index]
        change(&phrase)
        phrase.clampLengths()
        guard phrase != phrases[index] else { return }
        phrases[index] = phrase
        save()
    }

    func delete(ids: [UUID]) {
        let removing = Set(ids)
        phrases.removeAll { removing.contains($0.id) }
        save()
    }

    /// ドリルの答えを記録する
    func record(id: UUID, correct: Bool, now: Date = .now, calendar: Calendar = .current) {
        update(id: id) { $0.review.record(correct: correct, now: now, calendar: calendar) }
        let day = Self.dayKey(now, calendar: calendar)
        answerLog[day, default: 0] += 1
        // 古い記録は 400 日分だけ残す
        if answerLog.count > 400 {
            for old in answerLog.keys.sorted().prefix(answerLog.count - 400) {
                answerLog[old] = nil
            }
        }
        if let data = try? JSONEncoder().encode(answerLog) {
            defaults.set(data, forKey: logKey)
        }
    }

    /// ドリルを終えた日を記録する（続けた日数に使う）
    func recordDrillFinished(now: Date = .now, calendar: Calendar = .current) {
        let day = calendar.startOfDay(for: now)
        guard !drillDays.contains(day) else { return }
        drillDays.append(day)
        // 古い記録は 400 日分だけ残す
        drillDays = Array(drillDays.sorted().suffix(400))
        if let data = try? JSONEncoder().encode(drillDays) {
            defaults.set(data, forKey: daysKey)
        }
    }

    func streak(today: Date = .now, calendar: Calendar = .current) -> Int {
        Streak.current(dates: drillDays, today: today, calendar: calendar)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(phrases) else { return }
        defaults.set(data, forKey: key)
    }
}
