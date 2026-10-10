#if DEBUG
import AppKit
import SwiftUI

/// Debug-only: `-FudaShots /path/to/dir` walks through the main screens,
/// saves a PNG of the app's own window for each, then quits.
/// `-FudaDemo YES` seeds some history first so screens aren't empty.
enum MacShots {
    static func runIfRequested(router: MacRouter, store: ProgressStore, course: CourseProgress) {
        let d = UserDefaults.standard
        if d.bool(forKey: "FudaDemo"), store.states.isEmpty { seed(store, course) }
        if d.object(forKey: "FudaRomaji") != nil { store.settings.showRomaji = d.bool(forKey: "FudaRomaji") }
        if d.bool(forKey: "FudaRomajiTest") {
            // Print romaji / readings for tricky sentences, then quit.
            let cases: [(String, String)] = [("今日はいい天気です。", "きょうはいいてんきです。"), ("私はいます。", "わたしはいます。"), ("私は医者です。", "わたしはいしゃです。"),
                ("こんにちは。", "こんにちは。"), ("かばんで行きます。", "かばんでいきます。"), ("ビールを飲んで寝ました。", "ビールをのんでねました。"),
                ("中国人ですか。", "ちゅうごくじんですか。"), ("先生でした。", "せんせいでした。"), ("行ったら、電話してください。", "いったら、でんわしてください。"),
                ("日本語を勉強しています。", "にほんごをべんきょうしています。")]
            for (ja, kana) in cases { print("ROMAJI", ja, "→", Furigana.romaji(ja, kana)) }
            for t in ["今日はいい天気", "て形と辞書形", "行った", "一歩"] { print("AUTO", t, "→", AutoReading.tokens(t).map { "\($0.surface)[\($0.kana ?? "-")|\($0.romaji)]" }.joined(separator: " ")) }
            print("TYPED", AnswerCheck.reading("私は医者じゃありません"), AnswerCheck.reading("高くありません"))
            exit(0)
        }
        guard let dir = d.string(forKey: "FudaShots") else { return }
        // -FudaWindow 1280x800: shoot at a laptop-sized window.
        if let size = d.string(forKey: "FudaWindow")?.split(separator: "x").compactMap({ Double($0) }), size.count == 2 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let w = NSApp.windows.first(where: { $0.isVisible }) { w.setFrame(NSRect(x: 40, y: 40, width: size[0], height: size[1]), display: true) }
            }
        }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        var steps: [(String, () -> Void)] = [
            ("01-today", { router.section = .today }),
            ("02-course", { router.section = .course; router.lessonN = nil }),
            ("03-lesson8-machine", { router.openLesson(8, step: .learn) }),
            ("04-lesson4-learn", { router.openLesson(4, step: .learn) }),
            ("05-lesson8-words", { router.openLesson(8, step: .words) }),
            ("06-lesson4-talk", { router.openLesson(4, step: .talk) }),
            ("07-lesson8-practice", { router.openLesson(8, step: .practice) }),
            ("08-lesson8-test", { router.openLesson(8, step: .test) }),
            ("09-talk", { router.lessonN = nil; router.section = .talk; router.talkID = "konbini" }),
            ("10-stories", { router.section = .read; router.storyKey = "short_day" }),
            ("11-essentials", { router.section = .essentials; router.essentialID = 5 }),
            ("12-decks", { router.section = .decks }),
            ("13-practice", { router.section = .practice }),
            ("14-dictionary", { router.section = .dictionary; router.query = "たべ" }),
            ("15-progress", { router.section = .progress }),
            ("16-study", { router.section = .today; router.startStudy("まいにちの動詞", cards: Course.shared.lessons[4].wordCards.filter { $0.prompt == "食べる" }, store: store); router.study?.flipped = true }),
            ("17-quiz", { router.study = nil; router.startQuiz("Lesson 8 test", cards: Course.shared.lessons[8].allCards, count: 15, store: store) }),
            ("18-lesson0-kana", { router.quiz = nil; router.openLesson(0, step: .learn) }),
            ("19-essentials-verbs", { router.section = .essentials; router.essentialID = 6 }),
            ("29-mistake-note", {
                guard let l = Course.shared.lesson(teaching: "n5.p.ga") else { return }
                let pts = l.grammarCards.compactMap(\.grammarItem)
                let pi = pts.firstIndex { $0.key == "n5.p.ga" } ?? 0
                router.learnMode = .lesson
                router.debugBeat = LessonScripts.beats(for: pts[pi]).firstIndex { $0.kicker.contains("注意") } ?? 0
                router.openLesson(l.n, step: .learn); router.learnPoint = pi
            }),
            ("30-notes", { router.learnMode = .notes; router.debugBeat = 0 }),
            ("31-essentials-wa-ga", { router.lessonN = nil; router.learnMode = .lesson; router.section = .essentials; router.essentialID = 4 }),
            ("32-kosoado", {
                guard let l = Course.shared.lesson(teaching: "n5.kosoado") else { return }
                let pts = l.grammarCards.compactMap(\.grammarItem)
                let pi = pts.firstIndex { $0.key == "n5.kosoado" } ?? 0
                router.learnMode = .lesson; router.lessonN = nil; router.debugBeat = 2
                router.openLesson(l.n, step: .learn); router.learnPoint = pi
            }),
            ("27-player-te-1", { router.learnMode = .lesson; router.openLesson(8, step: .learn); router.learnPoint = 0 }),
            ("27b-player-te-3", { router.lessonN = nil; router.debugBeat = 2; router.openLesson(8, step: .learn) }),
            ("27c-player-te-5", { router.lessonN = nil; router.debugBeat = 4; router.openLesson(8, step: .learn) }),
            ("27d-player-teiru2", { router.lessonN = nil; router.debugBeat = 1; router.openLesson(8, step: .learn); router.learnPoint = 3 }),
            ("27e-player-chain", { router.lessonN = nil; router.debugBeat = 3; router.openLesson(8, step: .learn); router.learnPoint = 4 }),
            ("28-player-auto", { router.lessonN = nil; router.debugBeat = 0; router.openLesson(7, step: .learn) }),
            ("28b-player-auto-ex", { router.lessonN = nil; router.debugBeat = 4; router.openLesson(7, step: .learn) }),
            ("20-ladder", { router.learnMode = .play; router.openLesson(8, step: .learn); router.learnPoint = 1 }),
            ("21-timeline", { router.learnPoint = 2 }),
            ("22-state", { router.learnPoint = 3 }),
            ("23-chain", { router.learnPoint = 4 }),
            ("24-vertical", { UserDefaults.standard.set(true, forKey: "storyVertical"); router.lessonN = nil; router.section = .read; router.storyKey = "tale_momotaro" }),
            ("25-roleplay-dialogue", { UserDefaults.standard.set(false, forKey: "storyVertical"); router.openLesson(9, step: .talk) }),
            ("26-n4-lesson", { router.openLesson(20, step: .learn) })
        ]
        let tb: [(String, () -> Void)] = [
            ("tb-01-book", { router.debugBeat = 0; router.openLesson(1, step: .learn) }),
            ("tb-02-video", { router.openLesson(1, step: .video) }),
            ("tb-03-video-b4", { router.lessonN = nil; router.debugBeat = 4; router.openLesson(1, step: .video) }),
            ("tb-04-video-b8", { router.lessonN = nil; router.debugBeat = 8; router.openLesson(1, step: .video) }),
            ("tb-05-video-b21", { router.lessonN = nil; router.debugBeat = 21; router.openLesson(1, step: .video) }),
            ("tb-06-notes", { router.debugBeat = 0; router.openLesson(1, step: .notes) }),
            ("tb-07-talk", { router.openLesson(1, step: .talk) }),
            ("tb-08-drillA", { router.drillTab = "A"; router.openLesson(1, step: .practice) }),
            ("tb-09-drillB", { router.drillTab = "B" }),
            ("tb-10-drillC", { router.drillTab = "C" }),
            ("tb-11-test", { router.openLesson(1, step: .test) }),
            ("tb-12-course", { router.lessonN = nil; router.section = .course })
        ]
        let only = d.string(forKey: "FudaShotsSet")
        if only == "tb" { steps = tb } else if only == nil { steps += tb }
        if only == "course" {
            steps = [
                ("c-1-map", { router.section = .course; router.lessonN = nil }),
                ("c-2-lesson10-words", { router.openLesson(10, step: .words) }),
                ("c-3-lesson20", { router.lessonN = nil; router.section = .course }),
                ("c-4-talk-casual", { router.lessonN = nil; router.section = .talk; router.talkID = "l08_casual" }),
                ("c-5-talk-polite", { router.talkID = "l08_polite" }),
                ("c-6-lesson-talk", { router.openLesson(32, step: .talk) }),
                ("c-7-grammar", { router.openLesson(20, step: .notes) }),
            ]
        }
        if only == "words" {
            // 語 Word list: read mode, a typed test with mixed answers, then a whole category.
            let wl = router.wordList
            func open(_ sub: String, _ mode: WordListState.Mode) {
                router.section = .words
                wl.expanded = [String(sub.split(separator: ".")[0])]
                wl.selection = .sub(sub); wl.mode = mode; wl.restart()
            }
            steps = [
                ("w-1-read", { open("food.seasoning", .list) }),
                ("w-2-typing", {
                    open("food.drink", .test)
                    let ws = WordList.shared.words(sub: "food.drink")
                    let typed = ["เหล้า", "tea", "", "milk", "coffe", "น้ำร้อน", "beer"]
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { for (w, t) in zip(ws, typed) where !t.isEmpty { wl.answers[w.id] = t } }
                }),
                ("w-3-checked", {
                    for w in WordList.shared.words(sub: "food.drink") {
                        let ok = MeaningCheck.isCorrect(wl.answers[w.id] ?? "", w)
                        wl.results[w.id] = ok
                        store.recordList(w.id, correct: ok)
                        print("CHECK", w.word, "|", wl.answers[w.id] ?? "", "→", ok)
                    }
                    wl.checked = true
                }),
                ("w-4-category", { router.section = .words; wl.expanded = ["action"]; wl.selection = .category("action"); wl.mode = .list; wl.restart() }),
                ("w-5-category-typing", { router.section = .words; wl.expanded = ["food"]; wl.selection = .category("food"); wl.mode = .test; wl.restart() }),
                ("w-6-japanese", {
                    open("food.taste", .recall)
                    // romaji, hiragana, kanji, a near miss and a blank
                    let typed: [String: String] = ["甘い_あまい": "amai", "辛い_からい": "からい", "美味しい_おいしい": "美味しい", "苦い_にがい": "niga"]
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { for (k, v) in typed { wl.answers[k] = v } }
                }),
                ("w-7-japanese-checked", {
                    for w in WordList.shared.words(sub: "food.taste") {
                        let ok = JapaneseCheck.isCorrect(wl.answers[w.id] ?? "", w)
                        wl.results[w.id] = ok
                        store.recordList("jp:" + w.id, correct: ok)
                        print("JPCHECK", w.word, "|", wl.answers[w.id] ?? "", "→", ok)
                    }
                    wl.checked = true
                }),
                ("w-8-search", { wl.mode = .list; wl.query = "หั่น" }),
                ("w-9-greetings", { wl.query = ""; open("basic.greeting", .list) }),
                ("w-10-copy", {
                    open("food.taste", .list)
                    print("COPYTEXT-BEGIN\n" + WordExport.sentences.text(title: "味 รสชาติ · Taste", words: WordList.shared.words(sub: "food.taste")) + "\nCOPYTEXT-END")
                }),
            ]
        }
        if let n = d.string(forKey: "FudaShotsLesson").flatMap(Int.init) {
            // One lesson, every textbook step (for reviewing authored lessons).
            steps = LessonStep.steps(for: n).enumerated().map { i, st in
                (String(format: "L%02d-%d-%@", n, i + 1, st.rawValue), { router.debugBeat = 0; router.openLesson(n, step: st) })
            }
            if Textbook.lesson(n) != nil {
                let beats = Textbook.lesson(n)!.playerBeats.chapters
                steps += beats.map { c in (String(format: "L%02d-video-%02d", n, c.start), { router.lessonN = nil; router.debugBeat = c.start; router.openLesson(n, step: .video) }) }
                steps += ["B", "C"].map { t in (String(format: "L%02d-drill%@", n, t), { router.debugBeat = 0; router.drillTab = t; router.openLesson(n, step: .practice) }) }
            }
        }
        var i = 0
        func next() {
            guard i < steps.count else { NSApp.terminate(nil); return }
            let (name, action) = steps[i]
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                capture(to: "\(dir)/\(name).png")
                i += 1
                next()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { next() }
    }

    private static func capture(to path: String) {
        // Sheets are child windows: capture the frontmost one.
        let windows = NSApp.windows.filter { $0.isVisible && $0.contentView != nil }
        guard let window = windows.first(where: { $0.isSheet }) ?? NSApp.mainWindow ?? windows.first,
              let view = window.contentView else { return }
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }

    private static func seed(_ store: ProgressStore, _ course: CourseProgress) {
        let cal = Calendar.current
        for (i, card) in DB.shared.path(.n5).prefix(320).enumerated() {
            let t = cal.date(byAdding: .day, value: -max(1, 40 - i / 8), to: .now)!
            store.grade(card, .good, now: t)
            if i % 3 == 0, let s = store.state(card.id), s.due < .now { store.grade(card, .good, now: s.due) }
            if i % 17 == 0 { store.grade(card, .again, now: t.addingTimeInterval(3600)) }
        }
        for n in 0..<8 { for st in LessonStep.allCases { course.complete(n, st) }; course.recordTest(n, score: 80 + n) }
        course.complete(8, .learn); course.complete(8, .words); course.complete(8, .kanji)
        course.recordStory("short_family", score: 100)
        course.markTalk("konbini"); course.markEssential(1); course.markEssential(2); course.markEssential(3); course.markEssential(4)
        store.toggleStar("v:食べる_たべる")
    }
}
#endif
