import Foundation
import Observation

/// 日記の保存（端末の UserDefaults だけ。PrivacyInfo.xcprivacy に CA92.1 で申告済み）
@MainActor
@Observable
final class DiaryStore {
    private(set) var entries: [DiaryEntry] = []

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key: String

    init(defaults: UserDefaults = .standard, key: String = "diary.entries", seedSample: Bool = true, now: Date = .now) {
        self.defaults = defaults
        self.key = key
        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode([DiaryEntry].self, from: data) {
            entries = saved
        } else if seedSample {
            // 初めて開いたときだけ、見本を 1 つ置く（全部消したあとは置かない）
            entries = [DiaryEntry.sample(date: now)]
            save()
        }
    }

    /// 新しい順
    var sortedEntries: [DiaryEntry] {
        entries.sorted { $0.date > $1.date }
    }

    func entry(id: UUID) -> DiaryEntry? {
        entries.first { $0.id == id }
    }

    @discardableResult
    func addEntry(now: Date = .now) -> UUID {
        let entry = DiaryEntry(date: now)
        entries.append(entry)
        save()
        return entry.id
    }

    func update(id: UUID, _ change: (inout DiaryEntry) -> Void) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        var entry = entries[index]
        change(&entry)
        entry.clampLengths()
        guard entry != entries[index] else { return }
        entries[index] = entry
        save()
    }

    /// 左のページ（自分の文）を書き換える
    func setOriginal(_ text: String, id: UUID) {
        update(id: id) { $0.original = text }
    }

    /// 右のページを自分で書き換える
    func setCorrectedManually(_ text: String, id: UUID) {
        update(id: id) { entry in
            guard entry.corrected != text else { return }
            entry.corrected = text
            entry.source = .manual
        }
    }

    func delete(ids: [UUID]) {
        let removing = Set(ids)
        entries.removeAll { removing.contains($0.id) }
        save()
    }

    /// 続けて書いた日数（見本と空の日記は数えない）
    func streak(today: Date = .now, calendar: Calendar = .current) -> Int {
        let dates = entries.filter { !$0.isSample && $0.hasOriginal }.map(\.date)
        return Streak.current(dates: dates, today: today, calendar: calendar)
    }

    /// 左のページを直してもらい、右のページに書く。失敗したら何も変えない。
    func requestCorrection(id: UUID, using corrector: any SentenceCorrector) async throws {
        guard let entry = entry(id: id) else { return }
        let text = entry.original.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw CorrectionError.emptyInput }
        let result = try await corrector.correct(text)
        update(id: id) { entry in
            entry.corrected = result.corrected
            entry.note = result.note
            entry.source = .model
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: key)
    }
}
