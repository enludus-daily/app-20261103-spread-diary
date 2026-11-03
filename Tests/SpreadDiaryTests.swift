import Foundation
import Testing
@testable import SpreadDiary

// MARK: - 単語の差分

struct WordDiffTests {
    @Test func sameTextHasNoChanges() {
        let parts = WordDiff.compare("I like tea.", "I like tea.")
        #expect(parts.map(\.kind) == [.same, .same, .same])
        #expect(WordDiff.changeCount(parts) == 0)
    }

    @Test func replacedWordIsRemovedThenAdded() {
        let parts = WordDiff.compare("I go to school yesterday.", "I went to school yesterday.")
        #expect(parts == [
            .init(kind: .same, text: "I"),
            .init(kind: .removed, text: "go"),
            .init(kind: .added, text: "went"),
            .init(kind: .same, text: "to"),
            .init(kind: .same, text: "school"),
            .init(kind: .same, text: "yesterday."),
        ])
        #expect(WordDiff.changeCount(parts) == 2)
    }

    @Test func insertedAndDeletedWords() {
        let parts = WordDiff.compare("I am very exciting", "I am excited today")
        #expect(parts.filter { $0.kind == .removed }.map(\.text) == ["very", "exciting"])
        #expect(parts.filter { $0.kind == .added }.map(\.text) == ["excited", "today"])
        #expect(parts.filter { $0.kind == .same }.map(\.text) == ["I", "am"])
    }

    @Test func emptySides() {
        #expect(WordDiff.compare("", "Hello world").map(\.kind) == [.added, .added])
        #expect(WordDiff.compare("Hello world", "").map(\.kind) == [.removed, .removed])
        #expect(WordDiff.compare("", "").isEmpty)
    }

    @Test func extraSpacesAndNewlinesAreIgnored() {
        #expect(WordDiff.compare("I  like\ntea", "I like tea").allSatisfy { $0.kind == .same })
    }

    @Test func comparisonIsCaseSensitive() {
        #expect(WordDiff.changeCount(WordDiff.compare("i like tea", "I like tea")) == 2)
    }
}

// MARK: - 続けた日数

struct StreakTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }

    private func day(_ d: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: d, hour: hour))!
    }

    @Test func noEntriesIsZero() {
        #expect(Streak.current(dates: [], today: day(3), calendar: calendar) == 0)
    }

    @Test func countsConsecutiveDaysEndingToday() {
        let dates = [day(1), day(2), day(3, hour: 8), day(3, hour: 21)]
        #expect(Streak.current(dates: dates, today: day(3), calendar: calendar) == 3)
    }

    @Test func stillCountsWhenTodayIsNotWrittenYet() {
        #expect(Streak.current(dates: [day(1), day(2)], today: day(3), calendar: calendar) == 2)
    }

    @Test func gapResetsTheStreak() {
        #expect(Streak.current(dates: [day(1), day(3)], today: day(3), calendar: calendar) == 1)
        #expect(Streak.current(dates: [day(1)], today: day(3), calendar: calendar) == 0)
    }

    @Test func usesCalendarDaysNotTwentyFourHours() {
        // 23:30 と翌日 0:10 は別の日
        #expect(Streak.current(dates: [day(2, hour: 23), day(3, hour: 0)], today: day(3), calendar: calendar) == 2)
    }
}

// MARK: - モデルの答えの読み取り

struct CorrectionParserTests {
    @Test func readsCorrectedAndNote() {
        let raw = "CORRECTED: I went to the park.\nNOTE: ・過去なので went"
        #expect(CorrectionParser.parse(raw) == Correction(corrected: "I went to the park.", note: "・過去なので went"))
    }

    @Test func toleratesMarkdownLeadingTextAndCase() {
        let raw = "Sure!\n**Corrected:** I am excited.\n\n**Note:** excited にしました"
        #expect(CorrectionParser.parse(raw) == Correction(corrected: "I am excited.", note: "excited にしました"))
    }

    @Test func noteIsOptional() {
        #expect(CorrectionParser.parse("CORRECTED: Hello.") == Correction(corrected: "Hello.", note: ""))
    }

    @Test func multilineCorrectionIsKept() {
        let parsed = CorrectionParser.parse("CORRECTED: Line one.\nLine two.\nNOTE: ok")
        #expect(parsed?.corrected == "Line one.\nLine two.")
    }

    @Test(arguments: ["", "I went to the park.", "CORRECTED:   \nNOTE: nothing"])
    func unreadableAnswersAreRejected(raw: String) {
        #expect(CorrectionParser.parse(raw) == nil)
    }

    @Test func longAnswersAreCut() {
        let long = String(repeating: "a", count: DiaryEntry.maxLength + 50)
        #expect(CorrectionParser.parse("CORRECTED: \(long)")?.corrected.count == DiaryEntry.maxLength)
    }
}

// MARK: - 保存と、直す流れ（モデルは偽物）

private struct FakeError: Error {}

private struct FakeCorrector: SentenceCorrector {
    var status: CorrectorStatus = .available
    var result: Result<Correction, FakeError>

    func correct(_ text: String) async throws -> Correction {
        try result.get()
    }
}

@MainActor
struct DiaryStoreTests {
    private let defaults: UserDefaults
    private let now = Date(timeIntervalSince1970: 1_793_700_000)

    init() {
        let suite = "SpreadDiaryTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
    }

    private func makeStore(seed: Bool = false) -> DiaryStore {
        DiaryStore(defaults: defaults, key: "entries", seedSample: seed, now: now)
    }

    @Test func firstLaunchSeedsOneSampleOnlyOnce() {
        let store = makeStore(seed: true)
        #expect(store.entries.count == 1)
        #expect(store.entries[0].isSample)
        store.delete(ids: store.entries.map(\.id))
        // 全部消したあとに開き直しても、見本は戻らない
        #expect(makeStore(seed: true).entries.isEmpty)
    }

    @Test func sampleDoesNotCountForStreak() {
        let store = makeStore(seed: true)
        #expect(store.streak(today: now) == 0)
    }

    @Test func entriesPersistAcrossLaunches() {
        let store = makeStore()
        let id = store.addEntry(now: now)
        store.setOriginal("I like tea.", id: id)
        let reopened = makeStore()
        #expect(reopened.entry(id: id)?.original == "I like tea.")
        #expect(reopened.streak(today: now) == 1)
    }

    @Test func emptyEntryDoesNotCountForStreak() {
        let store = makeStore()
        store.addEntry(now: now)
        #expect(store.streak(today: now) == 0)
    }

    @Test func textIsCutAtMaximumLength() {
        let store = makeStore()
        let id = store.addEntry(now: now)
        store.setOriginal(String(repeating: "x", count: DiaryEntry.maxLength + 10), id: id)
        #expect(store.entry(id: id)?.original.count == DiaryEntry.maxLength)
    }

    @Test func sortedNewestFirst() {
        let store = makeStore()
        let older = store.addEntry(now: now)
        let newer = store.addEntry(now: now.addingTimeInterval(86_400))
        #expect(store.sortedEntries.map(\.id) == [newer, older])
    }

    @Test func correctionFillsRightPageFromModel() async throws {
        let store = makeStore()
        let id = store.addEntry(now: now)
        store.setOriginal("I go school.", id: id)
        let fake = FakeCorrector(result: .success(Correction(corrected: "I go to school.", note: "to が要ります")))
        try await store.requestCorrection(id: id, using: fake)
        let entry = try #require(store.entry(id: id))
        #expect(entry.original == "I go school.")
        #expect(entry.corrected == "I go to school.")
        #expect(entry.note == "to が要ります")
        #expect(entry.source == .model)
    }

    @Test func failedCorrectionChangesNothing() async {
        let store = makeStore()
        let id = store.addEntry(now: now)
        store.setOriginal("I go school.", id: id)
        let before = store.entry(id: id)
        await #expect(throws: FakeError.self) {
            try await store.requestCorrection(id: id, using: FakeCorrector(result: .failure(FakeError())))
        }
        #expect(store.entry(id: id) == before)
    }

    @Test func emptyOriginalIsNotSentToModel() async {
        let store = makeStore()
        let id = store.addEntry(now: now)
        store.setOriginal("   \n", id: id)
        await #expect(throws: CorrectionError.emptyInput) {
            try await store.requestCorrection(id: id, using: FakeCorrector(result: .success(Correction(corrected: "x", note: ""))))
        }
    }

    @Test func manualEditMarksSourceAsManual() async throws {
        let store = makeStore()
        let id = store.addEntry(now: now)
        store.setOriginal("I go school.", id: id)
        try await store.requestCorrection(id: id, using: FakeCorrector(result: .success(Correction(corrected: "I go to school.", note: ""))))
        store.setCorrectedManually("I went to school.", id: id)
        #expect(store.entry(id: id)?.source == .manual)
        #expect(store.entry(id: id)?.corrected == "I went to school.")
    }

    @Test func unavailableCorrectorReportsReason() {
        #expect(UnavailableCorrector(reason: "非対応").status == .unavailable("非対応"))
    }
}
