import Foundation

// Animated grammar lessons. Hand-written scripts for points that need a
// purpose-built story (Lesson 8 for now); every other point gets an automatic
// script built from its pattern, formula, examples, mistakes and register.

enum LessonScripts {
    static func beats(for g: GrammarItem) -> [LessonBeat] {
        switch g.key {
        case "n5.v.te": return teForm
        case "n5.t.kudasai": return kudasai
        case "n5.t.teiru": return teiru
        case "n5.t.teiru2": return teiruState
        case "n5.t.connect": return teChain
        default: return auto(g)
        }
    }

    static func isHandmade(_ key: String) -> Bool {
        ["n5.v.te", "n5.t.kudasai", "n5.t.teiru", "n5.t.teiru2", "n5.t.connect"].contains(key)
    }

    // MARK: て形の作り方

    static let teForm: [LessonBeat] = [
        LessonBeat(kicker: "て形 · meet the verb",
                   rows: [rw("w", spacing: 0, [tk("stem", "飲", .plain, .huge, ruby: "の"), tk("end", "む", .plain, .huge, ruby: " ")])],
                   en: "Meet 飲む, \"to drink\". Every verb has a て-form: the shape that links it to whatever comes next.",
                   th: "นี่คือ 飲む แปลว่า ดื่ม กริยาทุกตัวมีรูป て ซึ่งเป็นรูปที่ใช้เชื่อมกับส่วนถัดไป", say: "のむ"),
        LessonBeat(kicker: "Step 1 · look at the end",
                   rows: [rw("w", spacing: 0, [tk("stem", "飲", .plain, .huge, ruby: "の"), tk("end", "む", .key, .huge, ruby: " ", caption: "last sound")])],
                   en: "To build it, ignore everything except the LAST sound of the dictionary form. Here it's む.",
                   th: "วิธีทำ: ดูแค่เสียงสุดท้ายของรูปพจนานุกรม ในที่นี้คือ む"),
        LessonBeat(kicker: "Step 2 · find the rule",
                   rows: [rw("w", spacing: 0, [tk("stem", "飲", .plain, .huge, ruby: "の"), tk("end", "む", .strike, .huge, ruby: " ")]),
                          rw("rule", spacing: 12, [tk("r1", "む", .ghost, .mid), tk("r2", "ぶ", .ghost, .mid), tk("r3", "ぬ", .ghost, .mid), tk("arrow", "→", .op, .mid), tk("out", "んで", .key, .mid)])],
                   en: "む, ぶ and ぬ all follow the same rule: they turn into んで.",
                   th: "む ぶ ぬ ใช้กฎเดียวกัน คือเปลี่ยนเป็น んで"),
        LessonBeat(kicker: "Step 3 · swap it in",
                   rows: [rw("w", spacing: 0, [tk("stem", "飲", .plain, .huge, ruby: "の"), tk("out", "んで", .key, .huge, ruby: "んで")])],
                   en: "Swap the ending in: 飲む becomes 飲んで.",
                   th: "ใส่ส่วนท้ายใหม่: 飲む กลายเป็น 飲んで", say: "のんで"),
        LessonBeat(kicker: "Use it",
                   rows: [rw("ex", spacing: 4, [tk("obj", "薬を", .plain, .big, ruby: "くすりを"), tk("stem", "飲", .plain, .big, ruby: "の"), tk("out", "んで", .key, .big, ruby: "んで"), tk("kudasai", "ください", .ink, .big, ruby: " ")])],
                   en: "Add ください and you have a polite request: 薬を飲んでください, \"please take your medicine\".",
                   th: "เติม ください จะกลายเป็นคำขอร้องสุภาพ: 薬を飲んでください = กรุณาทานยา", say: "くすりをのんでください"),
        LessonBeat(kicker: "Another row · く",
                   rows: [rw("w2", spacing: 0, [tk("stem2", "書", .plain, .huge, ruby: "か"), tk("end2", "く", .key, .huge, ruby: " ", caption: "last sound")]),
                          rw("rule2", spacing: 12, [tk("rk", "く", .ghost, .mid), tk("arrow2", "→", .op, .mid), tk("out2", "いて", .key, .mid)])],
                   en: "Verbs ending in く follow a different rule: く becomes いて.",
                   th: "กริยาที่ลงท้ายด้วย く ใช้อีกกฎหนึ่ง: く เปลี่ยนเป็น いて", say: "かく"),
        LessonBeat(kicker: "Another row · く",
                   rows: [rw("w2", spacing: 0, [tk("stem2", "書", .plain, .huge, ruby: "か"), tk("out2", "いて", .key, .huge, ruby: "いて")])],
                   en: "So 書く, \"to write\", becomes 書いて.",
                   th: "ดังนั้น 書く (เขียน) กลายเป็น 書いて", say: "かいて"),
        LessonBeat(kicker: "例外 · the one exception",
                   rows: [rw("w3", spacing: 0, [tk("stem3", "行", .plain, .huge, ruby: "い"), tk("bad", "いて", .strike, .huge, ruby: " ")]),
                          rw("warn", [tk("warn", "例外 · EXCEPTION", .label, .mid)])],
                   en: "One trap: 行く, \"to go\", also ends in く. But it never becomes 行いて.",
                   th: "ระวัง! 行く (ไป) ลงท้ายด้วย く เหมือนกัน แต่ไม่ใช่ 行いて"),
        LessonBeat(kicker: "例外 · the one exception",
                   rows: [rw("w3", spacing: 0, [tk("stem3", "行", .plain, .huge, ruby: "い"), tk("good", "って", .key, .huge, ruby: "って")]),
                          rw("warn", [tk("warn", "例外 · EXCEPTION", .label, .mid)])],
                   en: "It's 行って. That's the only exception in the whole く row.",
                   th: "ที่ถูกคือ 行って เป็นข้อยกเว้นเดียวของกลุ่ม く", say: "いって"),
        LessonBeat(kicker: "Group 2 · る-verbs",
                   rows: [rw("w4", spacing: 0, [tk("stem4", "食べ", .plain, .huge, ruby: "たべ"), tk("ru", "る", .key, .huge, ruby: " ", caption: "drop it")])],
                   en: "Group 2 verbs end in いる or える. They're the easy ones.",
                   th: "กริยากลุ่ม 2 ลงท้ายด้วย いる หรือ える เป็นกลุ่มที่ง่ายที่สุด", say: "たべる"),
        LessonBeat(kicker: "Group 2 · る-verbs",
                   rows: [rw("w4", spacing: 0, [tk("stem4", "食べ", .plain, .huge, ruby: "たべ"), tk("te4", "て", .key, .huge, ruby: "て")])],
                   en: "Just drop る and add て: 食べる → 食べて.",
                   th: "แค่ตัด る แล้วเติม て: 食べる → 食べて", say: "たべて"),
        LessonBeat(kicker: "Irregular",
                   rows: [rw("s", spacing: 14, [tk("suru", "する", .ink, .big), tk("sa", "→", .op, .big), tk("shite", "して", .key, .big)]),
                          rw("k", spacing: 14, [tk("kuru", "来る", .ink, .big, ruby: "くる"), tk("ka", "→", .op, .big), tk("kite", "来て", .key, .big, ruby: "きて")])],
                   en: "And the only two irregular verbs: する → して, and 来る → 来て (read きて).",
                   th: "และกริยาผิดปกติแค่สองตัว: する → して และ 来る → 来て (อ่านว่า きて)", say: "して、きて"),
        LessonBeat(kicker: "The whole rule",
                   rows: [rw("rec1", spacing: 12, [tk("a1", "う つ る", .ghost, .mid), tk("b1", "→", .op, .mid), tk("c1", "って", .key, .mid)]),
                          rw("rec2", spacing: 12, [tk("a2", "む ぶ ぬ", .ghost, .mid), tk("b2", "→", .op, .mid), tk("c2", "んで", .key, .mid)]),
                          rw("rec3", spacing: 12, [tk("a3", "く · ぐ · す", .ghost, .mid), tk("b3", "→", .op, .mid), tk("c3", "いて · いで · して", .key, .mid)])],
                   en: "Say it like a rhythm: うつる って, むぶぬ んで, く いて, ぐ いで, す して. Then answer the check on the right.",
                   th: "ท่องเป็นจังหวะ: うつる って, むぶぬ んで, く いて, ぐ いで, す して แล้วลองตอบคำถามทางขวา",
                   say: "うつる、って。むぶぬ、んで。く、いて。ぐ、いで。す、して。")
    ]

    // MARK: 〜てください

    static let kudasai: [LessonBeat] = [
        LessonBeat(kicker: "Asking politely",
                   rows: [rw("v", spacing: 0, [tk("v", "待つ", .plain, .huge, ruby: "まつ")])],
                   en: "You want someone to wait. Start with the verb: 待つ, \"to wait\".",
                   th: "อยากขอให้ใครรอ เริ่มจากกริยา 待つ (รอ)", say: "まつ"),
        LessonBeat(kicker: "Step 1 · て-form",
                   rows: [rw("v", spacing: 0, [tk("v", "待って", .key, .huge, ruby: "まって")])],
                   en: "Turn it into its て-form: 待つ → 待って.",
                   th: "เปลี่ยนเป็นรูป て: 待つ → 待って", say: "まって"),
        LessonBeat(kicker: "Step 2 · add ください",
                   rows: [rw("v", spacing: 0, [tk("v", "待って", .key, .huge, ruby: "まって"), tk("k", "ください", .ink, .huge, ruby: " ")])],
                   en: "Add ください. 待ってください means \"please wait\".",
                   th: "เติม ください: 待ってください = กรุณารอสักครู่", say: "まってください"),
        LessonBeat(kicker: "How polite?",
                   rows: [rw("l3", spacing: 14, [tk("a3", "待ってください", .key, .mid), tk("c3", "polite · the default", .label, .small)]),
                          rw("l2", spacing: 14, [tk("a2", "待って", .plain, .mid), tk("c2", "casual · friends", .label, .small)]),
                          rw("l1", spacing: 14, [tk("a1", "待て", .ghost, .mid), tk("c1", "rough · a command", .label, .small)])],
                   en: "With friends you can drop ください. With teachers, staff and strangers, keep it.",
                   th: "กับเพื่อนตัด ください ได้ แต่กับครู พนักงาน หรือคนแปลกหน้าให้ใช้ ください"),
        LessonBeat(kicker: "In the classroom",
                   rows: [rw("ex", spacing: 4, [tk("o", "窓を", .plain, .big, ruby: "まどを"), tk("v2", "開けて", .key, .big, ruby: "あけて"), tk("k", "ください", .ink, .big, ruby: " ")])],
                   en: "窓を開けてください: \"Please open the window.\"",
                   th: "窓を開けてください = กรุณาเปิดหน้าต่าง", say: "まどをあけてください"),
        LessonBeat(kicker: "Please don't",
                   rows: [rw("ex", spacing: 4, [tk("o", "窓を", .plain, .big, ruby: "まどを"), tk("v3", "開けない", .plain, .big, ruby: "あけない"), tk("de", "で", .key, .big, ruby: " "), tk("k", "ください", .ink, .big, ruby: " ")])],
                   en: "To say \"please DON'T\", use the ない-form + で: 開けないでください.",
                   th: "ถ้าจะบอกว่า กรุณาอย่า… ใช้รูป ない + で: 開けないでください", say: "まどをあけないでください"),
        LessonBeat(kicker: "Recap",
                   rows: [rw("f", spacing: 12, [tk("f1", "Vて", .ink, .big), tk("f2", "+", .op, .big), tk("k", "ください", .key, .big)]),
                          rw("f2", spacing: 12, [tk("g1", "Vない", .ink, .mid), tk("g2", "+", .op, .mid), tk("g3", "でください", .key, .mid)])],
                   en: "Vて + ください = please do. Vない + でください = please don't.",
                   th: "Vて + ください = กรุณา… / Vない + でください = กรุณาอย่า…")
    ]

    // MARK: 〜ている ① in progress

    static let teiru: [LessonBeat] = [
        LessonBeat(kicker: "A timeline",
                   rows: [tl(LessonTimeline(caption: "")), rw("w", spacing: 0, [tk("v", "食べる", .plain, .huge, ruby: "たべる")])],
                   en: "Here's a timeline. The red line is NOW.",
                   th: "นี่คือเส้นเวลา เส้นสีแดงคือ ตอนนี้", say: "たべる"),
        LessonBeat(kicker: "Vて + いる",
                   rows: [tl(LessonTimeline(bar: 0.35...0.85, caption: "started, not finished")),
                          rw("w", spacing: 0, [tk("v", "食べ", .plain, .huge, ruby: "たべ"), tk("te", "て", .key, .huge, ruby: " "), tk("iru", "いる", .ink, .huge, ruby: " ")])],
                   en: "Vて + いる puts NOW inside the action: it has started, and it hasn't finished.",
                   th: "Vて + いる = เส้น ตอนนี้ อยู่ในการกระทำ คือเริ่มแล้วแต่ยังไม่จบ", say: "たべている"),
        LessonBeat(kicker: "Right now",
                   rows: [tl(LessonTimeline(bar: 0.35...0.85, caption: "in progress")),
                          rw("ex", spacing: 4, [tk("now", "今、ご飯を", .plain, .big, ruby: "いま、ごはんを"), tk("v", "食べ", .plain, .big, ruby: "たべ"), tk("te", "て", .key, .big, ruby: " "), tk("iru", "います", .ink, .big, ruby: " ")])],
                   en: "今、ご飯を食べています: \"I'm eating right now.\"",
                   th: "今、ご飯を食べています = ตอนนี้กำลังกินข้าวอยู่", say: "いま、ごはんをたべています"),
        LessonBeat(kicker: "A habit",
                   rows: [tl(LessonTimeline(ticks: [0.12, 0.24, 0.36, 0.48, 0.6, 0.72, 0.84], caption: "again and again")),
                          rw("ex", spacing: 4, [tk("now", "毎朝", .plain, .big, ruby: "まいあさ"), tk("v", "走っ", .plain, .big, ruby: "はしっ"), tk("te", "て", .key, .big, ruby: " "), tk("iru", "います", .ink, .big, ruby: " ")])],
                   en: "With 毎朝 (every morning) or いつも (always), ている means a habit: 毎朝走っています, \"I run every morning.\"",
                   th: "ถ้ามี 毎朝 หรือ いつも จะแปลว่าทำเป็นประจำ: 毎朝走っています = วิ่งทุกเช้า", say: "まいあさはしっています"),
        LessonBeat(kicker: "Casual speech",
                   rows: [rw("c", spacing: 14, [tk("full", "食べている", .plain, .big, ruby: "たべている"), tk("arr", "→", .op, .big), tk("cas", "食べてる", .key, .big, ruby: "たべてる")])],
                   en: "Friends often drop the い: 食べている → 食べてる.",
                   th: "ภาษาพูดกับเพื่อนมักตัด い: 食べている → 食べてる", say: "たべてる"),
        LessonBeat(kicker: "Recap",
                   rows: [rw("f", spacing: 12, [tk("f1", "Vて", .ink, .big), tk("f2", "+", .op, .big), tk("iru", "いる", .key, .big)]), rw("m", [tk("m", "is doing now · does regularly", .label, .mid)])],
                   en: "Vて + いる: doing it right now, or doing it as a habit.",
                   th: "Vて + いる: กำลังทำอยู่ หรือทำเป็นประจำ")
    ]

    // MARK: 〜ている ② resulting state

    static let teiruState: [LessonBeat] = [
        LessonBeat(kicker: "Instant verbs",
                   rows: [tl(LessonTimeline(event: 0.3, eventLabel: "結婚した")), rw("w", spacing: 0, [tk("v", "結婚する", .plain, .huge, ruby: "けっこんする")])],
                   en: "Some verbs happen in an instant. 結婚する, \"to get married\", happens at one moment.",
                   th: "กริยาบางตัวเกิดขึ้นในพริบตาเดียว เช่น 結婚する (แต่งงาน) เกิดขึ้น ณ จุดเดียว", say: "けっこんする"),
        LessonBeat(kicker: "The state that follows",
                   rows: [tl(LessonTimeline(bar: 0.3...0.97, solid: true, event: 0.3, eventLabel: "結婚した", caption: "still true now")),
                          rw("w", spacing: 0, [tk("v", "結婚し", .plain, .huge, ruby: "けっこんし"), tk("te", "て", .key, .huge, ruby: " "), tk("iru", "いる", .ink, .huge, ruby: " ")])],
                   en: "With these verbs, ている shows the state that follows the change, and it's still true now.",
                   th: "กับกริยาแบบนี้ ている = สภาพหลังจากเปลี่ยนแปลงแล้ว และยังเป็นอยู่จนถึงตอนนี้", say: "けっこんしている"),
        LessonBeat(kicker: "Not \"marrying\"",
                   rows: [tl(LessonTimeline(bar: 0.3...0.97, solid: true, event: 0.3, eventLabel: "結婚した", caption: "is married")),
                          rw("ex", spacing: 4, [tk("s", "姉は", .plain, .big, ruby: "あねは"), tk("v", "結婚し", .plain, .big, ruby: "けっこんし"), tk("te", "て", .key, .big, ruby: " "), tk("iru", "います", .ink, .big, ruby: " ")])],
                   en: "姉は結婚しています means \"my sister IS married\", not \"is getting married\".",
                   th: "姉は結婚しています = พี่สาวแต่งงานแล้ว (ไม่ใช่ กำลังแต่งงาน)", say: "あねはけっこんしています"),
        LessonBeat(kicker: "知っています",
                   rows: [tl(LessonTimeline(bar: 0.2...0.97, solid: true, event: 0.2, eventLabel: "知った", caption: "I know")),
                          rw("ex", spacing: 4, [tk("s", "田中さんを", .plain, .big, ruby: "たなかさんを"), tk("v", "知っ", .plain, .big, ruby: "しっ"), tk("te", "て", .key, .big, ruby: " "), tk("iru", "います", .ink, .big, ruby: " ")])],
                   en: "知っています = \"I know\": you learned it once, and you still know it.",
                   th: "知っています = รู้จัก/รู้ คือรู้มาตั้งแต่ครั้งหนึ่งและยังรู้อยู่", say: "たなかさんをしっています"),
        LessonBeat(kicker: "Watch out",
                   rows: [rw("neg", spacing: 18, [tk("good", "知りません", .key, .big, ruby: "しりません"), tk("bad", "知っていません", .strike, .big, ruby: " ")])],
                   en: "But its negative is 知りません, \"I don't know\". Never 知っていません.",
                   th: "แต่รูปปฏิเสธคือ 知りません (ไม่รู้) ห้ามใช้ 知っていません", say: "しりません"),
        LessonBeat(kicker: "More instant verbs",
                   rows: [rw("m1", spacing: 12, [tk("x1", "住んでいます", .key, .mid, ruby: "すんでいます"), tk("y1", "live (in)", .label, .small)]),
                          rw("m2", spacing: 12, [tk("x2", "来ています", .key, .mid, ruby: "きています"), tk("y2", "has come, is here", .label, .small)]),
                          rw("m3", spacing: 12, [tk("x3", "持っています", .key, .mid, ruby: "もっています"), tk("y3", "have, own", .label, .small)])],
                   en: "Other common ones: 住んでいます (live), 来ています (is here), 持っています (have).",
                   th: "ตัวอื่นที่ใช้บ่อย: 住んでいます (อาศัยอยู่), 来ています (มาถึงแล้ว), 持っています (มี/ถืออยู่)"),
        LessonBeat(kicker: "Recap",
                   rows: [rw("f", spacing: 12, [tk("f1", "instant verb", .ink, .mid), tk("f2", "+", .op, .mid), tk("iru", "ている", .key, .mid), tk("f3", "=", .op, .mid), tk("f4", "state now", .label, .mid)])],
                   en: "Instant verb + ている = the state you're in now, after the change.",
                   th: "กริยาเปลี่ยนสภาพทันที + ている = สภาพที่เป็นอยู่ตอนนี้หลังการเปลี่ยนแปลง")
    ]

    // MARK: 〜て、〜

    static let teChain: [LessonBeat] = [
        LessonBeat(kicker: "Chaining actions",
                   rows: [rw("c", spacing: 8, [tk("a1", "起き", .plain, .big, ruby: "おき"), tk("t1", "て", .key, .big, ruby: " ")])],
                   en: "て-form can chain actions in order. First: 起きて, \"I get up, and…\"",
                   th: "รูป て เชื่อมการกระทำตามลำดับ เริ่มจาก 起きて = ตื่นนอน แล้ว…", say: "おきて"),
        LessonBeat(kicker: "Chaining actions",
                   rows: [rw("c", spacing: 8, [tk("a1", "起き", .plain, .big, ruby: "おき"), tk("t1", "て", .key, .big, ruby: " "), tk("a2", "顔を洗っ", .plain, .big, ruby: "かおをあらっ"), tk("t2", "て", .key, .big, ruby: " ")])],
                   en: "…wash my face, and…",
                   th: "…ล้างหน้า แล้ว…", say: "かおをあらって"),
        LessonBeat(kicker: "Chaining actions",
                   rows: [rw("c", spacing: 8, [tk("a1", "起き", .plain, .big, ruby: "おき"), tk("t1", "て", .key, .big, ruby: " "), tk("a2", "顔を洗っ", .plain, .big, ruby: "かおをあらっ"), tk("t2", "て", .key, .big, ruby: " "), tk("a3", "朝ご飯を食べ", .plain, .big, ruby: "あさごはんをたべ"), tk("t3", "て", .key, .big, ruby: " ")])],
                   en: "…eat breakfast, and…",
                   th: "…กินข้าวเช้า แล้ว…", say: "あさごはんをたべて"),
        LessonBeat(kicker: "The last verb",
                   rows: [rw("c", spacing: 8, [tk("a1", "起き", .plain, .big, ruby: "おき"), tk("t1", "て", .key, .big, ruby: " "), tk("a2", "顔を洗っ", .plain, .big, ruby: "かおをあらっ"), tk("t2", "て", .key, .big, ruby: " "), tk("a3", "朝ご飯を食べ", .plain, .big, ruby: "あさごはんをたべ"), tk("t3", "て", .key, .big, ruby: " "), tk("a4", "学校に行き", .plain, .big, ruby: "がっこうにいき"), tk("t4", "ます", .ink, .big, ruby: " ", caption: "tense lives here")])],
                   en: "…go to school. Only the LAST verb ends in ます. It decides the tense for the whole chain.",
                   th: "…ไปโรงเรียน กริยาตัวสุดท้ายเท่านั้นที่ลงท้ายด้วย ます และเป็นตัวบอกกาลของทั้งประโยค",
                   say: "おきて、かおをあらって、あさごはんをたべて、がっこうにいきます"),
        LessonBeat(kicker: "Make it past",
                   rows: [rw("c", spacing: 8, [tk("a1", "起き", .plain, .big, ruby: "おき"), tk("t1", "て", .key, .big, ruby: " "), tk("a2", "顔を洗っ", .plain, .big, ruby: "かおをあらっ"), tk("t2", "て", .key, .big, ruby: " "), tk("a3", "朝ご飯を食べ", .plain, .big, ruby: "あさごはんをたべ"), tk("t3", "て", .key, .big, ruby: " "), tk("a4", "学校に行き", .plain, .big, ruby: "がっこうにいき"), tk("t5", "ました", .key, .big, ruby: " ", caption: "past for all")])],
                   en: "To make it all past, change only the last verb: 行きました. Every て stays the same.",
                   th: "ถ้าจะเป็นอดีต เปลี่ยนแค่ตัวสุดท้ายเป็น 行きました ส่วน て อื่นๆ เหมือนเดิม",
                   say: "おきて、かおをあらって、あさごはんをたべて、がっこうにいきました"),
        LessonBeat(kicker: "て for a reason",
                   rows: [rw("r", spacing: 8, [tk("r1", "風邪をひい", .plain, .big, ruby: "かぜをひい"), tk("r2", "て", .key, .big, ruby: " ", caption: "because"), tk("r3", "休みました", .ink, .big, ruby: "やすみました")])],
                   en: "て can also give a reason: 風邪をひいて休みました, \"I caught a cold, so I stayed home.\"",
                   th: "て ใช้บอกเหตุผลได้ด้วย: 風邪をひいて休みました = เป็นหวัดก็เลยหยุด", say: "かぜをひいて、やすみました"),
        LessonBeat(kicker: "て for how",
                   rows: [rw("m", spacing: 8, [tk("m1", "歩い", .plain, .big, ruby: "あるい"), tk("m2", "て", .key, .big, ruby: " ", caption: "how"), tk("m3", "駅まで行きます", .ink, .big, ruby: "えきまでいきます")])],
                   en: "Or HOW you do something: 歩いて駅まで行きます, \"I go to the station on foot.\"",
                   th: "หรือบอกวิธีการ: 歩いて駅まで行きます = เดินไปสถานี", say: "あるいて、えきまでいきます"),
        LessonBeat(kicker: "Recap",
                   rows: [rw("f", spacing: 10, [tk("f1", "A て", .ghost, .mid), tk("f2", "B て", .ghost, .mid), tk("f3", "C ます", .key, .mid)]), rw("g", [tk("g", "and then · because · by", .label, .mid)])],
                   en: "Link actions with て. Only the last verb carries the tense. て can mean \"and then\", \"because\" or \"by\".",
                   th: "เชื่อมการกระทำด้วย て กาลอยู่ที่ตัวสุดท้าย て แปลได้ทั้ง แล้วก็ / เพราะ / โดย")
    ]

    // MARK: - Automatic script for any grammar point

    static func auto(_ g: GrammarItem) -> [LessonBeat] {
        var beats: [LessonBeat] = []
        let parts = formula(g.structure)
        let keyIndex = keyPart(parts, pattern: g.pattern)
        let core = coreOf(g.pattern)

        /// The formula as tokens. With `hideKey`, the key part leaves an empty slot
        /// so the key token can fly into the example sentence below.
        func formulaRow(_ size: LessonTok.Size, hideKey: Bool = false) -> LessonRow {
            let toks = parts.enumerated().map { i, p -> LessonTok in
                if ["+", "→", "/"].contains(p) { return tk("op\(i)", p, .op, size) }
                if i == keyIndex { return hideKey ? tk("slot", String(repeating: "＿", count: max(1, min(p.count, 4))), .ghost, size) : tk("key", p, .key, size) }
                return tk("p\(i)", p, i == 0 ? .ink : .ghost, size)
            }
            return rw("formula", spacing: 10, toks)
        }

        // 1 · title
        beats.append(LessonBeat(kicker: "New pattern",
                                rows: [rw("title", [tk("key", g.pattern, .key, g.pattern.count > 8 ? .big : .huge)]), rw("mean", [tk("mean", g.en, .label, .mid)])],
                                en: "New pattern: \(g.pattern). It means \"\(g.en)\".",
                                th: "รูปประโยคใหม่: \(g.pattern) แปลว่า \(g.th)"))
        // 2 · formula, built part by part
        if parts.count > 1 {
            beats.append(LessonBeat(kicker: "How it's built", rows: [formulaRow(.big)],
                                    en: "Here's how it's built: \(g.structure).",
                                    th: "โครงสร้าง: \(g.structure)"))
        }
        // 3 · explanation, a few sentences at a time, formula stays on stage
        let enSents = sentences(g.explainEN)
        let thChunks = chunks(g.explainTH, into: max(1, min(3, (enSents.count + 1) / 2)))
        let enChunks = stride(from: 0, to: enSents.count, by: 2).map { enSents[$0..<min($0 + 2, enSents.count)].joined(separator: " ") }
        for (i, en) in enChunks.prefix(3).enumerated() {
            beats.append(LessonBeat(kicker: "What it does", rows: parts.count > 1 ? [formulaRow(.mid)] : [rw("title", [tk("key", g.pattern, .key, .big)])],
                                    en: en, th: i < thChunks.count ? thChunks[i] : ""))
        }
        // 4 · examples: the key part flies from the formula into the sentence
        for (i, e) in g.examples.prefix(3).enumerated() {
            var rows: [LessonRow] = []
            if parts.count > 1 { rows.append(formulaRow(.small, hideKey: true)) }
            let read = { (r: Range<String.Index>) in Furigana.reading(of: r, in: e.ja, kana: e.kana) }
            if let r = e.ja.range(of: core), !core.isEmpty {
                let pre = e.ja.startIndex..<r.lowerBound, post = r.upperBound..<e.ja.endIndex
                var toks: [LessonTok] = []
                if !pre.isEmpty { toks.append(tk("pre\(i)", String(e.ja[pre]), .plain, .big, ruby: read(pre))) }
                toks.append(tk("key", String(e.ja[r]), .key, .big, ruby: read(r)))
                if !post.isEmpty { toks.append(tk("post\(i)", String(e.ja[post]), .plain, .big, ruby: read(post))) }
                rows.append(rw("ex", spacing: 2, toks))
            } else {
                rows.append(rw("ex", [tk("ex\(i)", e.ja, .plain, .big, ruby: e.kana)]))
            }
            beats.append(LessonBeat(kicker: "例文 · example \(i + 1)", rows: rows,
                                    en: "\(e.ja) means \"\(e.en)\"", th: "\(e.ja) = \(e.th)", say: e.kana))
        }
        // 5 · formation, mistakes, register
        if !g.formationEN.isEmpty {
            beats.append(LessonBeat(kicker: "作り方 · forming it", rows: [rw("note", [tk("note", g.formationEN, .note, .big)])],
                                    en: "How to form it: \(g.formationEN)", th: g.formationTH))
        }
        if !g.mistakesEN.isEmpty {
            beats.append(LessonBeat(kicker: "注意 · watch out", rows: [rw("warn", [tk("warn", "注意", .key, .big)]), rw("note", [tk("note", g.mistakesEN, .note, .big)])],
                                    en: "A common mistake: \(g.mistakesEN)", th: g.mistakesTH))
        }
        if !g.registerEN.isEmpty {
            beats.append(LessonBeat(kicker: "使い方 · when to use it", rows: [rw("note", [tk("note", g.registerEN, .note, .big)])],
                                    en: g.registerEN, th: g.registerTH))
        }
        // 6 · recap
        beats.append(LessonBeat(kicker: "Recap",
                                rows: [rw("title", [tk("key", g.pattern, .key, g.pattern.count > 8 ? .big : .huge)]), rw("mean", [tk("mean", g.en, .label, .mid)])],
                                en: "Recap: \(g.pattern) = \(g.en). Now try the check question on the right.",
                                th: "ทบทวน: \(g.pattern) = \(g.th) ลองตอบคำถามทางขวาดู"))
        return beats
    }

    // MARK: Helpers

    static func formula(_ s: String) -> [String] {
        var out: [String] = []
        var cur = ""
        for ch in s {
            if ch == "+" || ch == "→" || ch == "＋" || ch == "/" {
                let t = cur.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty { out.append(t) }
                out.append(ch == "＋" ? "+" : String(ch))
                cur = ""
            } else { cur.append(ch) }
        }
        let t = cur.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty { out.append(t) }
        while let f = out.first, ["+", "→", "/"].contains(f) { out.removeFirst() }
        return out.count > 9 ? [s] : out
    }

    static func coreOf(_ pattern: String) -> String {
        pattern.components(separatedBy: CharacterSet(charactersIn: "/／・（("))[0]
            .replacingOccurrences(of: "〜", with: "").replacingOccurrences(of: "N", with: "").replacingOccurrences(of: "V", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    /// The formula part that holds the pattern itself (falls back to the last word part).
    static func keyPart(_ parts: [String], pattern: String) -> Int? {
        let core = coreOf(pattern)
        if !core.isEmpty, let i = parts.firstIndex(where: { $0.contains(core) || core.contains($0) && $0.count > 1 }) { return i }
        return parts.lastIndex { !["+", "→", "/"].contains($0) }
    }

    static func sentences(_ s: String) -> [String] {
        var out: [String] = []
        var cur = ""
        for ch in s {
            cur.append(ch)
            if ch == "." || ch == "!" || ch == "?" {
                let t = cur.trimmingCharacters(in: .whitespaces)
                if t.count > 2 { out.append(t) }
                cur = ""
            }
        }
        let t = cur.trimmingCharacters(in: .whitespaces)
        if t.count > 2 { out.append(t) }
        return out
    }

    /// Thai has no full stops: split on spaces into roughly equal chunks.
    static func chunks(_ s: String, into n: Int) -> [String] {
        let words = s.split(separator: " ").map(String.init)
        guard n > 1, words.count > n else { return [s] }
        let size = Int((Double(words.count) / Double(n)).rounded(.up))
        return stride(from: 0, to: words.count, by: size).map { words[$0..<min($0 + size, words.count)].joined(separator: " ") }
    }
}
