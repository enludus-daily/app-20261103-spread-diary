import Foundation
import Testing
@testable import SpreadDiary

private var tokyo: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    return calendar
}

private func day(_ d: Int, hour: Int = 12) -> Date {
    tokyo.date(from: DateComponents(year: 2026, month: 11, day: d, hour: hour))!
}

private func phrase(_ english: String, box: Int = 0, words: [VocabItem] = [], due: Date = day(4)) -> Phrase {
    Phrase(
        createdAt: day(1),
        japanese: "日本語",
        english: english,
        words: words,
        source: .manual,
        review: ReviewState(box: box, due: due)
    )
}

// MARK: - 単語に分ける

struct TokenizerTests {
    @Test func splitsOnWhitespace() {
        #expect(Tokenizer.tokens("Could  you\ntell me?") == ["Could", "you", "tell", "me?"])
    }

    @Test func coreAndNormalizedStripEdgePunctuation() {
        #expect(Tokenizer.core("station?") == "station")
        #expect(Tokenizer.core("“Hello,”") == "Hello")
        #expect(Tokenizer.normalized("Station!") == "station")
        #expect(Tokenizer.core("tomorrow's") == "tomorrow's")
    }

    @Test func trailingPunctuation() {
        #expect(Tokenizer.trailingPunctuation("station?") == "?")
        #expect(Tokenizer.trailingPunctuation("little.”") == ".”")
        #expect(Tokenizer.trailingPunctuation("word") == "")
    }
}

// MARK: - 復習の間隔

struct ReviewStateTests {
    @Test func correctMovesUpABoxAndSchedulesLater() {
        var review = ReviewState(box: 0, due: day(3))
        review.record(correct: true, now: day(3, hour: 22), calendar: tokyo)
        #expect(review.box == 1)
        #expect(review.due == tokyo.startOfDay(for: day(4)))
        #expect(review.correctCount == 1)
    }

    @Test func intervalsGrowWithTheBox() {
        var review = ReviewState(box: 3, due: day(3))
        review.record(correct: true, now: day(3), calendar: tokyo)
        #expect(review.box == 4)
        #expect(review.due == tokyo.startOfDay(for: day(10))) // 7 日後
    }

    @Test func wrongGoesBackToFirstBoxAndIsDueNow() {
        var review = ReviewState(box: 4, due: day(3))
        review.record(correct: false, now: day(5), calendar: tokyo)
        #expect(review.box == 0)
        #expect(review.due == day(5))
        #expect(review.isDue(now: day(5)))
        #expect(review.wrongCount == 1)
    }

    @Test func boxStopsAtMastered() {
        var review = ReviewState(box: ReviewState.maxBox, due: day(3))
        review.record(correct: true, now: day(3), calendar: tokyo)
        #expect(review.box == ReviewState.maxBox)
        #expect(review.isMastered)
    }
}

// MARK: - ドリルの組み立て

struct DrillPlannerTests {
    @Test func onlyDuePhrasesInDueOrderAndCapped() {
        let later = phrase("Later one here", due: day(6))
        let early = phrase("Early one here", due: day(2))
        let middle = phrase("Middle one here", due: day(3))
        let due = DrillPlanner.duePhrases([later, middle, early], now: day(4))
        #expect(due.map(\.english) == ["Early one here", "Middle one here"])

        let many = (0..<20).map { phrase("Sentence number \($0)", due: day(1)) }
        #expect(DrillPlanner.duePhrases(many, now: day(4)).count == DrillPlanner.maxPerSession)
    }

    @Test func kindProgressesWithTheBox() {
        let words = [VocabItem(english: "station", japanese: "駅")]
        #expect(DrillPlanner.kind(for: phrase("Could you tell me the way to the station?", box: 0, words: words)) == .scramble)
        #expect(DrillPlanner.kind(for: phrase("Could you tell me the way to the station?", box: 1, words: words)) == .cloze)
        #expect(DrillPlanner.kind(for: phrase("Could you tell me the way to the station?", box: 2, words: words)) == .recall)
    }

    @Test func shortSentenceSkipsScramble() {
        #expect(DrillPlanner.kind(for: phrase("OK!", box: 0)) == .recall)
        #expect(DrillPlanner.kind(for: phrase("Good morning", box: 0)) == .cloze)
    }

    @Test func scrambleUsesSameWordsInADifferentOrder() {
        var rng = SeededRandom(seed: 42)
        let question = DrillPlanner.makeScramble("Could you tell me the way?", using: &rng)
        #expect(question.answer == ["Could", "you", "tell", "me", "the", "way?"])
        #expect(question.pieces.sorted() == question.answer.sorted())
        #expect(question.pieces != question.answer)
        #expect(question.isCorrect(question.answer))
        #expect(!question.isCorrect(question.pieces))
    }

    @Test func scrambleCheckIgnoresCaseAndPunctuation() {
        let question = ScrambleQuestion(answer: ["Thank", "you."], pieces: ["you.", "Thank"])
        #expect(question.isCorrect(["thank", "you"]))
    }

    @Test func clozeBlanksTheVocabWordAndKeepsPunctuation() throws {
        var rng = SeededRandom(seed: 7)
        let target = phrase("Could you tell me the way to the station?", box: 1, words: [VocabItem(english: "station", japanese: "駅")])
        let cloze = try #require(DrillPlanner.makeCloze(target, pool: ["meeting", "push", "little", "station"], using: &rng))
        #expect(cloze.answer == "station")
        #expect(cloze.displayTokens.last == "____?")
        #expect(cloze.choices.count == 4)
        #expect(cloze.choices.filter { $0.lowercased() == "station" }.count == 1)
        #expect(cloze.isCorrect("Station"))
        #expect(!cloze.isCorrect("meeting"))
    }

    @Test func clozeFallsBackToLongestContentWord() {
        let tokens = Tokenizer.tokens("I really appreciate your help.")
        #expect(DrillPlanner.blankIndex(tokens: tokens, words: []) == 2)
    }

    @Test func clozeWithoutCandidatesIsNil() {
        var rng = SeededRandom(seed: 1)
        #expect(DrillPlanner.makeCloze(phrase("I am", box: 1), pool: [], using: &rng) == nil)
    }

    @Test func sameSeedGivesSameQuestion() {
        var a = SeededRandom(seed: 99)
        var b = SeededRandom(seed: 99)
        let target = phrase("Could we push tomorrow's meeting back a little?")
        #expect(DrillPlanner.makeQuestion(for: target, pool: [], using: &a) == DrillPlanner.makeQuestion(for: target, pool: [], using: &b))
    }

    @Test func distractorPoolExcludesThePhraseItself() {
        let a = phrase("Alpha bravo charlie")
        let b = phrase("Delta echo foxtrot", words: [VocabItem(english: "golf", japanese: "")])
        let pool = DrillPlanner.distractorPool([a, b], excluding: a.id)
        #expect(pool.contains("Delta"))
        #expect(pool.contains("golf"))
        #expect(!pool.contains("Alpha"))
    }
}

// MARK: - 出力を整える

struct DraftCleanerTests {
    @Test func trimsDropsEmptyAndDuplicates() throws {
        let draft = try DraftCleaner.clean(
            japanese: " 駅はどこ？ ",
            english: "  Where is the station?  ",
            variants: [(label: "丁寧", english: "Where is the station?"), (label: "くだけた", english: "Where's the station?"), (label: "x", english: " ")],
            words: [(english: "station", japanese: "駅"), (english: "Station", japanese: "駅"), (english: "", japanese: "空")],
            source: .model
        )
        #expect(draft.japanese == "駅はどこ？")
        #expect(draft.english == "Where is the station?")
        #expect(draft.variants.map(\.english) == ["Where's the station?"])
        #expect(draft.words.map(\.english) == ["station"])
    }

    @Test func emptyEnglishIsAnError() {
        #expect(throws: PhraseGenerationError.emptyResult) {
            try DraftCleaner.clean(japanese: "a", english: "  ", variants: [], words: [], source: .translation)
        }
    }

    @Test func wordsAreCapped() throws {
        let words = (0..<10).map { (english: "word\($0)", japanese: "") }
        let draft = try DraftCleaner.clean(japanese: "a", english: "b", variants: [], words: words, source: .model)
        #expect(draft.words.count == Phrase.maxWords)
    }
}

// MARK: - 続けた日数

struct StreakTests {
    @Test func countsConsecutiveDaysEndingTodayOrYesterday() {
        #expect(Streak.current(dates: [day(1), day(2), day(3)], today: day(3), calendar: tokyo) == 3)
        #expect(Streak.current(dates: [day(1), day(2)], today: day(3), calendar: tokyo) == 2)
        #expect(Streak.current(dates: [day(1)], today: day(3), calendar: tokyo) == 0)
        #expect(Streak.current(dates: [], today: day(3), calendar: tokyo) == 0)
    }
}

// MARK: - 保存と、作る流れ（モデルは偽物）

private struct FakeError: Error {}

private struct FakeGenerator: PhraseGenerator {
    var status: GeneratorStatus = .available
    var result: Result<PhraseDraft, FakeError>

    func generate(japanese: String) async throws -> PhraseDraft {
        try result.get()
    }
}

@MainActor
struct PhraseStoreTests {
    private let defaults: UserDefaults

    init() {
        let suite = "SpreadDiaryTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
    }

    private func makeStore(seed: Bool = false) -> PhraseStore {
        PhraseStore(defaults: defaults, key: "phrases", seedSamples: seed, now: day(4))
    }

    @Test func firstLaunchSeedsSamplesOnlyOnce() {
        let store = makeStore(seed: true)
        #expect(store.phrases.count == 2)
        #expect(store.dueCount(now: day(4)) == 2)
        store.delete(ids: store.phrases.map(\.id))
        #expect(makeStore(seed: true).phrases.isEmpty)
    }

    @Test func generatedDraftIsSavedAndDueImmediately() async throws {
        let store = makeStore()
        let fake = FakeGenerator(result: .success(PhraseDraft(
            japanese: "駅はどこ？",
            english: "Where is the station?",
            variants: [PhraseVariant(label: "くだけた", english: "Where's the station?")],
            words: [VocabItem(english: "station", japanese: "駅")],
            source: .model
        )))
        let draft = try await fake.generate(japanese: "駅はどこ？")
        let id = store.add(draft, now: day(4))
        let saved = try #require(store.phrase(id: id))
        #expect(saved.english == "Where is the station?")
        #expect(saved.source == .model)
        #expect(saved.review.box == 0)
        #expect(store.dueCount(now: day(4)) == 1)
        #expect(makeStore().phrase(id: id)?.words.first?.japanese == "駅")
    }

    @Test func failedGenerationAddsNothing() async {
        let store = makeStore()
        let fake = FakeGenerator(result: .failure(FakeError()))
        await #expect(throws: FakeError.self) {
            _ = try await fake.generate(japanese: "x")
        }
        #expect(store.phrases.isEmpty)
    }

    @Test func recordingAnAnswerMovesTheBoxAndPersists() {
        let store = makeStore()
        let id = store.add(PhraseDraft(japanese: "a", english: "Thank you so much", variants: [], words: [], source: .manual), now: day(4))
        store.record(id: id, correct: true, now: day(4), calendar: tokyo)
        #expect(store.phrase(id: id)?.review.box == 1)
        #expect(store.dueCount(now: day(4, hour: 23)) == 0)
        #expect(makeStore().dueCount(now: day(5)) == 1)
    }

    @Test func drillDaysMakeTheStreak() {
        let store = makeStore()
        store.recordDrillFinished(now: day(3), calendar: tokyo)
        store.recordDrillFinished(now: day(4, hour: 8), calendar: tokyo)
        store.recordDrillFinished(now: day(4, hour: 21), calendar: tokyo)
        #expect(store.drillDays.count == 2)
        #expect(store.streak(today: day(4), calendar: tokyo) == 2)
        #expect(makeStore().streak(today: day(4), calendar: tokyo) == 2)
    }

    @Test func longTextIsCut() {
        let store = makeStore()
        let id = store.add(PhraseDraft(
            japanese: String(repeating: "あ", count: 500),
            english: String(repeating: "a", count: 500),
            variants: [], words: [], source: .manual
        ), now: day(4))
        #expect(store.phrase(id: id)?.japanese.count == Phrase.maxJapaneseLength)
        #expect(store.phrase(id: id)?.english.count == Phrase.maxEnglishLength)
    }

    @Test func unavailableGeneratorReportsReason() {
        #expect(UnavailableGenerator(reason: "非対応").status == .unavailable("非対応"))
    }
}
