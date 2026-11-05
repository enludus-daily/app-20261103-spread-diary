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

    @Test func laterBoxesAlternateListeningAndRecall() {
        let english = "Could you tell me the way to the station?"
        #expect(DrillPlanner.kind(for: phrase(english, box: 3)) == .listening)
        #expect(DrillPlanner.kind(for: phrase(english, box: 4)) == .recall)
        #expect(DrillPlanner.kind(for: phrase(english, box: 5)) == .listening)
        #expect(DrillPlanner.kind(for: phrase("Thank you", box: 3)) == .recall)
    }

    @Test func listeningQuestionUsesTheSameWords() {
        var rng = SeededRandom(seed: 3)
        let question = DrillPlanner.makeQuestion(for: phrase("Could you tell me the way?", box: 3), pool: [], using: &rng)
        guard case .listening(let scramble) = question else {
            Issue.record("聞き取りになっていない: \(question)")
            return
        }
        #expect(scramble.pieces.sorted() == scramble.answer.sorted())
        #expect(question.kind == .listening)
    }

    @Test func extraPracticeTakesWeakestNotDuePhrases() {
        let strong = phrase("Strong one here", box: 5, due: day(20))
        let weak = phrase("Weak one here", box: 1, due: day(6))
        let due = phrase("Due one here", box: 0, due: day(1))
        let extra = DrillPlanner.extraPractice([strong, weak, due], now: day(4))
        #expect(extra.map(\.english) == ["Weak one here", "Strong one here"])
        #expect(DrillPlanner.extraPractice([strong, weak], now: day(4), count: 1).map(\.english) == ["Weak one here"])
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

// MARK: - フレーズの束（手で用意したデータ）

struct PhraseBankTests {
    private func norm(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: "’", with: "'").filter { $0.isLetter || $0.isNumber || $0 == "'" || $0 == " " || $0 == "-" }
    }

    @Test func hasAtLeast300PhrasesInSixScenes() throws {
        let bank = try PhraseBank.load()
        #expect(bank.phrases.count >= 300)
        for scene in SceneKind.bankScenes {
            #expect(bank.phrases(in: scene).count >= 45, "\(scene.rawValue)")
        }
        #expect(Set(bank.phrases.map(\.scene)) == Set(SceneKind.bankScenes.map(\.rawValue)))
    }

    @Test func everyPhraseIsComplete() throws {
        let bank = try PhraseBank.load()
        #expect(Set(bank.phrases.map(\.id)).count == bank.phrases.count)
        #expect(Set(bank.phrases.map(\.ja)).count == bank.phrases.count)
        for p in bank.phrases {
            #expect(!p.ja.isEmpty && !p.en.isEmpty && !p.polite.isEmpty && !p.casual.isEmpty, "\(p.id)")
            #expect(!p.words.isEmpty, "\(p.id)")
            for w in p.words {
                #expect(!w.ja.isEmpty, "\(p.id)")
                #expect(norm(p.en).contains(norm(w.en)), "\(p.id): \(w.en)")
            }
            #expect(p.en.count <= Phrase.maxEnglishLength && p.ja.count <= Phrase.maxJapaneseLength)
        }
    }

    @Test func bankPhraseBecomesDraftWithVariants() throws {
        let card = try #require(try PhraseBank.load().phrases.first)
        let draft = card.draft
        #expect(draft.english == card.en)
        #expect(draft.variants.map(\.label) == ["丁寧", "くだけた"])
        #expect(draft.source == .bank)
    }
}

// MARK: - 今日の 3 枚・記録の見える化・言い方

struct TodayPlannerTests {
    private let bank: [BankPhrase] = (1...40).map { i in
        BankPhrase(id: String(format: "%@-%03d", i % 2 == 0 ? "work" : "travel", i), scene: i % 2 == 0 ? "work" : "travel",
                   ja: "日本語\(i)", en: "English \(i)", polite: "p", casual: "c", words: [BankWord(en: "English", ja: "英語")])
    }

    @Test func sameDaySamePicksAndDifferentDaysDiffer() {
        let a = TodayPlanner.picks(bank: bank, owned: [], scenes: ["work", "travel"], dayKey: "2026-11-05", count: 3)
        let b = TodayPlanner.picks(bank: bank, owned: [], scenes: ["work", "travel"], dayKey: "2026-11-05", count: 3)
        let c = TodayPlanner.picks(bank: bank, owned: [], scenes: ["work", "travel"], dayKey: "2026-11-06", count: 3)
        #expect(a == b)
        #expect(a.count == 3)
        #expect(a != c)
    }

    @Test func skipsOwnedAndKeepsToChosenScenes() {
        let owned = Set(bank.filter { $0.scene == "work" }.prefix(15).map(\.id))
        let picks = TodayPlanner.picks(bank: bank, owned: owned, scenes: ["work"], dayKey: "2026-11-05", count: 5)
        #expect(picks.count == 5)
        #expect(picks.allSatisfy { $0.hasPrefix("work") && !owned.contains($0) })
    }

    @Test func fallsBackWhenChosenScenesAreDone() {
        let owned = Set(bank.filter { $0.scene == "work" }.map(\.id))
        let picks = TodayPlanner.picks(bank: bank, owned: owned, scenes: ["work"], dayKey: "2026-11-05", count: 3)
        #expect(picks.count == 3)
        #expect(picks.allSatisfy { $0.hasPrefix("travel") })
        #expect(TodayPlanner.picks(bank: bank, owned: Set(bank.map(\.id)), scenes: ["work"], dayKey: "x", count: 3).isEmpty)
    }

    @Test(arguments: [(0, 0), (1, 1), (2, 1), (3, 2), (5, 2), (6, 3), (9, 3), (10, 4), (40, 4)])
    func heatLevels(count: Int, level: Int) {
        #expect(HeatLevel.level(count) == level)
    }

    @Test func heatmapColumnsAreMondayWeeksEndingToday() {
        let columns = HeatmapGrid.columns(endingAt: day(5), weeks: 18, calendar: tokyo)
        #expect(columns.count == 18)
        #expect(columns.dropLast().allSatisfy { $0.count == 7 })
        #expect(columns.last?.last.map { tokyo.isDate($0, inSameDayAs: day(5)) } == true)
        // 2026-11-05 は木曜日。月曜始まりなので最後の列は 4 日
        #expect(columns.last?.count == 4)
        #expect(columns.first?.first.map { tokyo.component(.weekday, from: $0) } == 2)
    }

    @Test func streakMessageNeverBlames() {
        #expect(StreakMessage.text(streak: 0, totalDays: 0, practicedToday: false).contains("1 日目"))
        #expect(StreakMessage.text(streak: 4, totalDays: 10, practicedToday: true) == "4 日続いています")
        #expect(StreakMessage.text(streak: 0, totalDays: 12, practicedToday: false) == "おかえりなさい。これまでに合計 12 日")
        for text in [StreakMessage.text(streak: 0, totalDays: 3, practicedToday: false), StreakMessage.text(streak: 1, totalDays: 3, practicedToday: false)] {
            #expect(!text.contains("途切れ"))
        }
    }

    @Test func boxDistributionCountsEachBox() {
        let phrases = [0, 0, 3, 6, 6, 6].map { box in
            Phrase(createdAt: day(1), japanese: "a", english: "b", source: .manual, review: ReviewState(box: box, due: day(1)))
        }
        #expect(BoxDistribution.counts(phrases) == [2, 0, 0, 1, 0, 0, 3])
    }

    @Test func oldSavedPhrasesStillDecode() throws {
        let json = #"[{"id":"7C9E6679-7425-40DE-944B-E07FC1F90AE7","createdAt":0,"japanese":"あ","english":"Hi","variants":[],"words":[],"source":"manual","review":{"box":2,"due":0,"correctCount":1,"wrongCount":0}}]"#
        let phrases = try JSONDecoder().decode([Phrase].self, from: Data(json.utf8))
        #expect(phrases.first?.review.box == 2)
        #expect(phrases.first?.scene == nil)
        #expect(phrases.first?.sceneKind == .mine)
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

    private func makeStore() -> PhraseStore {
        PhraseStore(defaults: defaults, key: "phrases")
    }

    @Test func startsEmptyWithoutSamples() {
        #expect(makeStore().phrases.isEmpty)
    }

    @Test func todayCardsAreStableAndLearnedOnce() throws {
        let bank = try PhraseBank.load()
        let store = makeStore()
        let first = store.todayCards(bank: bank, count: 3, now: day(5), calendar: tokyo)
        #expect(first.count == 3)
        #expect(store.todayCards(bank: bank, count: 3, now: day(5, hour: 22), calendar: tokyo).map(\.id) == first.map(\.id))
        #expect(makeStore().todayCards(bank: bank, count: 3, now: day(5), calendar: tokyo).map(\.id) == first.map(\.id))
        #expect(!store.isTodayLearned(now: day(5), calendar: tokyo))

        let ids = store.learnToday(first, now: day(5), calendar: tokyo)
        #expect(ids.count == 3)
        #expect(store.phrases.count == 3)
        #expect(store.isTodayLearned(now: day(5), calendar: tokyo))
        #expect(store.phrases.allSatisfy { $0.source == .bank && $0.bankID != nil && $0.scene != nil })
        // めくり終えたあとも、今日のカードは同じ 3 枚のまま
        #expect(store.todayCards(bank: bank, count: 3, now: day(5), calendar: tokyo).map(\.id) == first.map(\.id))
        // 同じカードをもう一度通しても増えない
        store.learnToday(first, now: day(5), calendar: tokyo)
        #expect(store.phrases.count == 3)
        // 次の日は、通したカード以外から選ぶ
        let next = store.todayCards(bank: bank, count: 3, now: day(6), calendar: tokyo)
        #expect(Set(next.map(\.id)).isDisjoint(with: Set(first.map(\.id))))
        #expect(store.totalDays == 1)
    }

    @Test func addFromBankKeepsOneCopy() throws {
        let bank = try PhraseBank.load()
        let store = makeStore()
        let card = try #require(bank.phrases.first)
        let a = store.addFromBank(card, now: day(5))
        let b = store.addFromBank(card, now: day(6))
        #expect(a == b)
        #expect(store.phrases.count == 1)
        #expect(store.phrases(in: card.sceneKind).count == 1)
        #expect(store.phrase(id: a)?.variants.count == 2)
    }

    @Test func spokenPhrasesAreBoxThreeAndUp() {
        let store = makeStore()
        let id = store.add(PhraseDraft(japanese: "a", english: "Thank you so much", variants: [], words: [], source: .manual), now: day(1))
        #expect(store.spokenPhrases.isEmpty)
        for d in 1...3 { store.record(id: id, correct: true, now: day(d), calendar: tokyo) }
        #expect(store.spokenPhrases.map(\.id) == [id])
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

    @Test func answersCountTowardTodaysGoalAndWeek() {
        let store = makeStore()
        let id = store.add(PhraseDraft(japanese: "a", english: "Thank you so much", variants: [], words: [], source: .manual), now: day(1))
        store.record(id: id, correct: true, now: day(3), calendar: tokyo)
        for _ in 0..<3 {
            store.record(id: id, correct: false, now: day(4, hour: 9), calendar: tokyo)
        }
        #expect(store.answeredCount(on: day(4), calendar: tokyo) == 3)
        #expect(store.goalProgress(now: day(4), calendar: tokyo) == 3.0 / Double(PhraseStore.dailyGoal))
        let week = store.week(endingAt: day(4), calendar: tokyo)
        #expect(week.count == 7)
        #expect(week.last?.count == 3)
        #expect(week[week.count - 2].count == 1)
        #expect(makeStore().answeredCount(on: day(4), calendar: tokyo) == 3)
    }

    @Test func goalProgressStopsAtOne() {
        let store = makeStore()
        let id = store.add(PhraseDraft(japanese: "a", english: "Thank you so much", variants: [], words: [], source: .manual), now: day(1))
        for _ in 0..<(PhraseStore.dailyGoal + 3) {
            store.record(id: id, correct: true, now: day(4), calendar: tokyo)
        }
        #expect(store.goalProgress(now: day(4), calendar: tokyo) == 1)
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
