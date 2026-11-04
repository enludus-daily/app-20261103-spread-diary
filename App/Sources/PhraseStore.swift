import Foundation
import Observation

/// フレーズとドリルの記録の保存（端末の UserDefaults だけ。PrivacyInfo.xcprivacy に CA92.1 で申告済み）
@MainActor
@Observable
final class PhraseStore {
    private(set) var phrases: [Phrase] = []
    private(set) var drillDays: [Date] = []

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key: String

    init(defaults: UserDefaults = .standard, key: String = "phrases.v1", seedSamples: Bool = true, now: Date = .now) {
        self.defaults = defaults
        self.key = key
        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode([Phrase].self, from: data) {
            phrases = saved
        } else if seedSamples {
            // 初めて開いたときだけ見本を置く（全部消したあとは置かない）
            phrases = Phrase.samples(now: now)
            save()
        }
        if let data = defaults.data(forKey: daysKey),
           let saved = try? JSONDecoder().decode([Date].self, from: data) {
            drillDays = saved
        }
    }

    private var daysKey: String { key + ".drillDays" }

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
