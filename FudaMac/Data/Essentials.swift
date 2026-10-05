import Foundation

// 基 Essentials: the background knowledge a learner needs alongside the
// course. Short chapters: an intro, a few sections, real examples, and a Thai
// summary. Chapters with `widget` get an interactive explainer as well.

struct EssentialExample: Hashable {
    let ja: String
    let kana: String
    let en: String
}

struct EssentialSection: Hashable {
    let title: String
    let body: String
    var table: [[String]] = []          // first row = header
    var examples: [EssentialExample] = []
}

struct EssentialChapter: Identifiable, Hashable {
    enum Widget { case none, scripts, particles, verbGroups, politeness, counters }
    let id: Int
    let ja: String
    let en: String
    let intro: String
    let summaryTH: String
    var widget: Widget = .none
    let sections: [EssentialSection]
}

private func ex(_ ja: String, _ kana: String, _ en: String) -> EssentialExample { EssentialExample(ja: ja, kana: kana, en: en) }

enum Essentials {
    static let chapters: [EssentialChapter] = [
        EssentialChapter(id: 1, ja: "文字", en: "Scripts: kana & kanji",
            intro: "Japanese is written with three scripts at once. Each has a job, and a normal sentence mixes all three.",
            summaryTH: "ภาษาญี่ปุ่นใช้ 3 ระบบตัวอักษรพร้อมกัน: ฮิรางานะ (ไวยากรณ์/คำญี่ปุ่น), คาตากานะ (คำต่างประเทศ), คันจิ (ความหมายหลักของคำ)",
            widget: .scripts,
            sections: [
                EssentialSection(title: "Three scripts, three jobs",
                    body: "Hiragana writes grammar: particles, verb endings, and words without common kanji. Katakana writes foreign words, names and sound effects. Kanji carry the meaning of most nouns, verb stems and adjectives.",
                    table: [["Script", "Example", "Used for"], ["ひらがな", "は・を・ます・きれい", "grammar, native words"], ["カタカナ", "コーヒー・タイ・テレビ", "loanwords, names, emphasis"], ["漢字", "日本・食・先生", "meaning: nouns, stems"]]),
                EssentialSection(title: "Reading a mixed sentence",
                    body: "Kanji show where the content words are; hiragana glue them together. Furigana are small kana printed over kanji to show the reading.",
                    examples: [ex("私はタイ人です。", "わたしはタイじんです。", "I am Thai. 私 and 人 are kanji, タイ is katakana, the rest is hiragana.")]),
                EssentialSection(title: "No spaces",
                    body: "Japanese doesn't put spaces between words. You find word edges from the script changes and from particles like は, を and に.")
            ]),
        EssentialChapter(id: 2, ja: "発音", en: "Sounds, っ, long vowels, pitch",
            intro: "Japanese has only five vowels and a regular rhythm. Every kana takes one beat (a mora), so length changes meaning.",
            summaryTH: "ทุกตัวคะนะยาวเท่ากัน 1 จังหวะ สระยาว (おばさん/おばあさん) และ っ (きて/きって) ทำให้ความหมายเปลี่ยน",
            sections: [
                EssentialSection(title: "Five vowels",
                    body: "あ a · い i · う u · え e · お o. They are short and clean, with no glides. う is said with relaxed lips."),
                EssentialSection(title: "Long vowels change meaning",
                    body: "Hold the vowel for an extra beat. In katakana the long mark is ー.",
                    table: [["Short", "Long"], ["おばさん aunt", "おばあさん grandmother"], ["ここ here", "こうこう high school"], ["ビル building", "ビール beer"]]),
                EssentialSection(title: "Small っ: a silent beat",
                    body: "A small っ doubles the next consonant. You pause for one beat before it.",
                    examples: [ex("来て / 切って", "きて / きって", "come / cut: the only difference is the pause")]),
                EssentialSection(title: "ん is a full beat",
                    body: "ん counts as its own beat. こんにちは has five beats: こ・ん・に・ち・は."),
                EssentialSection(title: "Pitch accent",
                    body: "Japanese uses high and low pitch, not stress. 箸 はし (chopsticks) falls high→low; 橋 はし (bridge) rises low→high. Context usually makes the meaning clear, so copy the audio and don't worry too much.")
            ]),
        EssentialChapter(id: 3, ja: "語順", en: "Word order (SOV)",
            intro: "Japanese puts the verb at the end. Everything else comes before it, with a particle marking its role.",
            summaryTH: "ประโยคญี่ปุ่นเรียง ประธาน → กรรม → กริยา กริยาอยู่ท้ายเสมอ คำช่วยบอกหน้าที่ของแต่ละคำ",
            sections: [
                EssentialSection(title: "Subject, object, verb",
                    body: "English says \"I eat bread\" (S-V-O). Japanese says \"I bread eat\" (S-O-V).",
                    examples: [ex("私はパンを食べます。", "わたしはパンをたべます。", "I (topic) bread (object) eat.")]),
                EssentialSection(title: "The verb is the anchor",
                    body: "Time, place and people can move around, as long as each keeps its particle. The verb stays last.",
                    examples: [ex("毎朝、駅で友達と会います。", "まいあさ、えきでともだちとあいます。", "Every morning I meet a friend at the station."), ex("駅で毎朝友達と会います。", "えきでまいあさともだちとあいます。", "Same meaning, different order.")]),
                EssentialSection(title: "Leave out what's obvious",
                    body: "If the listener knows who you mean, drop it. \"I\" and \"you\" are usually left out.",
                    examples: [ex("食べましたか。— はい、食べました。", "たべましたか。— はい、たべました。", "Did (you) eat? Yes, (I) ate.")]),
                EssentialSection(title: "Modifiers come first",
                    body: "Adjectives and whole clauses go before the noun they describe: 赤い車 a red car; 昨日買った本 the book I bought yesterday.")
            ]),
        EssentialChapter(id: 4, ja: "はとが", en: "は vs が",
            intro: "Both can follow the subject, but they do different jobs. は sets the topic; が points to the subject.",
            summaryTH: "は = หัวเรื่อง (ส่วน…นั้น) / が = ชี้ตัวประธาน ใช้ในคำถาม 誰が/何が และกับ 好き・ある・いる",
            sections: [
                EssentialSection(title: "は: \"as for…\"",
                    body: "は introduces what you're talking about, usually something already known. The new information comes after it.",
                    examples: [ex("私は学生です。", "わたしはがくせいです。", "As for me, I'm a student.")]),
                EssentialSection(title: "が: \"it's X that…\"",
                    body: "が picks out the subject, often as new information. Question words always take が, and so does the answer.",
                    examples: [ex("誰が来ましたか。— 田中さんが来ました。", "だれがきましたか。— たなかさんがきました。", "Who came? Tanaka came.")]),
                EssentialSection(title: "Always が",
                    body: "Use が with 好き / 嫌い / 上手 / 分かる / ある / いる / ほしい, and in clauses that describe a noun.",
                    examples: [ex("猫が好きです。", "ねこがすきです。", "I like cats."), ex("机の上に本があります。", "つくえのうえにほんがあります。", "There is a book on the desk.")]),
                EssentialSection(title: "は for contrast",
                    body: "は can also mean \"but this one…\". 肉は食べますが、魚は食べません: I eat meat, but not fish.")
            ]),
        EssentialChapter(id: 5, ja: "助詞", en: "Particles",
            intro: "A particle comes after a noun and shows its job in the sentence. Learn the particle and the word order stops mattering.",
            summaryTH: "คำช่วยตามหลังคำนามเพื่อบอกหน้าที่: は หัวเรื่อง が ประธาน を กรรม に เวลา/เป้าหมาย で สถานที่ทำ/วิธีการ と ร่วมกับ",
            widget: .particles,
            sections: [
                EssentialSection(title: "The N5 set",
                    body: "These twelve cover almost every N5 sentence.",
                    table: [["Particle", "Job", "Example"], ["は", "topic", "私は学生です"], ["が", "subject · likes", "猫が好きです"], ["を", "object", "パンを食べる"], ["に", "time · target · existence", "七時に起きる"], ["で", "place of action · means", "バスで行く"], ["へ", "direction", "日本へ行く"], ["と", "with · and", "友達と話す"], ["も", "also", "私も行く"], ["の", "of · 's", "私の本"], ["から / まで", "from / until", "九時から五時まで"], ["か", "question", "学生ですか"], ["ね / よ", "agree / tell", "いいですね"]]),
                EssentialSection(title: "に vs で for places",
                    body: "に marks where something is or where it goes: 東京に住む. で marks where an action happens: 東京で働く.",
                    examples: [ex("部屋に猫がいます。", "へやにねこがいます。", "There's a cat in the room."), ex("部屋で勉強します。", "へやでべんきょうします。", "I study in my room.")]),
                EssentialSection(title: "を with movement",
                    body: "With 歩く, 走る and 渡る, を marks the space you move through: 公園を歩く, walk through the park.")
            ]),
        EssentialChapter(id: 6, ja: "動詞", en: "Verb groups & conjugation",
            intro: "Every verb belongs to one of three groups. Know the group and you can build every form.",
            summaryTH: "กริยามี 3 กลุ่ม: กลุ่ม 1 (う-verb) กลุ่ม 2 (る-verb ตัด る) และผิดปกติ する・来る",
            widget: .verbGroups,
            sections: [
                EssentialSection(title: "Group 1: u-verbs (五段)",
                    body: "Ends in an -u sound: う く ぐ す つ ぬ ぶ む る. The last sound shifts along its row: 書く → 書きます → 書かない → 書いて.",
                    examples: [ex("飲む → 飲みます → 飲まない → 飲んで", "のむ → のみます → のまない → のんで", "drink")]),
                EssentialSection(title: "Group 2: ru-verbs (一段)",
                    body: "Ends in いる or える. Just drop る and add the ending: 食べる → 食べます / 食べない / 食べて.",
                    examples: [ex("見る → 見ます → 見ない → 見て", "みる → みます → みない → みて", "see")]),
                EssentialSection(title: "Irregular: する and 来る",
                    body: "する → します / しない / して. 来る → 来ます (きます) / 来ない (こない) / 来て (きて). Every 〜する verb (勉強する, 電話する) follows する."),
                EssentialSection(title: "Traps",
                    body: "Some verbs look like Group 2 but are Group 1: 帰る, 入る, 走る, 知る, 要る, 切る. Their ます-form gives them away: 帰ります, not 帰ます."),
                EssentialSection(title: "The forms you'll learn",
                    body: "Dictionary (Lesson 10) · ます (4) · て (8) · ない (9) · た (11) · potential, volitional, passive, causative (N4).",
                    table: [["Form", "Group 1 書く", "Group 2 食べる", "する"], ["ます", "書きます", "食べます", "します"], ["ない", "書かない", "食べない", "しない"], ["て", "書いて", "食べて", "して"], ["た", "書いた", "食べた", "した"]])
            ]),
        EssentialChapter(id: 7, ja: "形容詞", en: "い / な adjectives",
            intro: "Japanese has two kinds of adjective. い-adjectives conjugate themselves; な-adjectives work more like nouns.",
            summaryTH: "คุณศัพท์ い ผันที่ตัวเอง (高くない/高かった) คุณศัพท์ な ใช้ じゃない/でした และใส่ な ก่อนคำนาม",
            sections: [
                EssentialSection(title: "い-adjectives",
                    body: "End in い and change their ending: 高い → 高くない (not) → 高かった (was) → 高くて (and).",
                    examples: [ex("このラーメンはおいしかったです。", "このラーメンはおいしかったです。", "This ramen was delicious.")]),
                EssentialSection(title: "な-adjectives",
                    body: "Take な before a noun and use です / じゃない like nouns: 静かな町, 静かじゃない, 静かでした.",
                    examples: [ex("ここは静かな公園です。", "ここはしずかなこうえんです。", "This is a quiet park.")]),
                EssentialSection(title: "Exceptions",
                    body: "いい (good) conjugates from よい: よくない, よかった. きれい and 嫌い end in い but are な-adjectives."),
                EssentialSection(title: "Side by side",
                    body: "",
                    table: [["", "高い (い)", "静か (な)"], ["before noun", "高い山", "静かな町"], ["not", "高くない", "静かじゃない"], ["was", "高かった", "静かでした"], ["and", "高くて", "静かで"]])
            ]),
        EssentialChapter(id: 8, ja: "丁寧さ", en: "Politeness levels",
            intro: "The same sentence changes shape depending on who you're talking to. As a learner, start polite.",
            summaryTH: "ระดับภาษา: ธรรมดา (เพื่อน/ครอบครัว) · สุภาพ です・ます (คนทั่วไป) · เคโกะ (ลูกค้า/ผู้ใหญ่) เริ่มต้นใช้ です・ます",
            widget: .politeness,
            sections: [
                EssentialSection(title: "Three levels",
                    body: "Plain form for friends and family. です / ます for strangers, teachers, staff and colleagues. Keigo (honorific and humble forms) for customers and formal situations, which you'll meet in N4.",
                    table: [["Plain", "Polite", "Keigo"], ["食べる", "食べます", "召し上がる / いただく"], ["行く", "行きます", "いらっしゃる / 参る"], ["だ", "です", "でございます"]]),
                EssentialSection(title: "Names and さん",
                    body: "Add さん after other people's names, never your own. 先生 replaces さん for teachers and doctors. Children get ちゃん or くん."),
                EssentialSection(title: "Shop Japanese",
                    body: "Staff speak keigo to you (いらっしゃいませ, かしこまりました, ございます). You can answer in plain です / ます. Nobody expects keigo from a customer.")
            ]),
        EssentialChapter(id: 9, ja: "数", en: "Numbers, counters, money",
            intro: "Numbers are regular, but counting things uses counters, and some readings change.",
            summaryTH: "นับสิ่งของต้องใช้ลักษณนาม เช่น 枚 (แบน) 本 (ยาว) 匹 (สัตว์เล็ก) 人 (คน) ระวังเสียงเปลี่ยน 一本 いっぽん",
            widget: .counters,
            sections: [
                EssentialSection(title: "1 to 10",
                    body: "一 いち · 二 に · 三 さん · 四 よん / し · 五 ご · 六 ろく · 七 なな / しち · 八 はち · 九 きゅう / く · 十 じゅう. Big units: 百 100, 千 1,000, 万 10,000."),
                EssentialSection(title: "Counters",
                    body: "Number + counter. The counter depends on the shape or kind of thing.",
                    table: [["Counter", "For", "Example"], ["つ", "general things (1–10)", "ひとつ・ふたつ・みっつ"], ["人 にん", "people", "ひとり・ふたり・さんにん"], ["枚 まい", "flat things", "切手を二枚"], ["本 ほん", "long things", "ペンを一本 いっぽん"], ["匹 ひき", "small animals", "猫が三匹 さんびき"], ["個 こ", "small objects", "りんごを五個"], ["台 だい", "machines, cars", "車が一台"]]),
                EssentialSection(title: "Money",
                    body: "円 えん follows the number: 五百八十円 580 yen. Prices are said in 万: 一万円 is 10,000 yen.")
            ]),
        EssentialChapter(id: 10, ja: "時間", en: "Time, dates, calendar",
            intro: "Times and dates are number + unit, with a handful of special readings to memorise.",
            summaryTH: "เวลา: 時 (โมง) 分 (นาที) วันที่ 1–10 มีคำอ่านพิเศษ (ついたち・ふつか…) เวลาแน่นอนใช้ に",
            sections: [
                EssentialSection(title: "Clock time",
                    body: "〜時 じ hours, 〜分 ふん/ぷん minutes, 半 half past. Watch out for 四時 よじ, 七時 しちじ, 九時 くじ.",
                    examples: [ex("七時半に起きます。", "しちじはんにおきます。", "I get up at 7:30.")]),
                EssentialSection(title: "Days of the month",
                    body: "1st–10th, 14th, 20th and 24th have special readings.",
                    table: [["Date", "Reading"], ["1日", "ついたち"], ["2日", "ふつか"], ["3日", "みっか"], ["4日", "よっか"], ["5日", "いつか"], ["8日", "ようか"], ["10日", "とおか"], ["20日", "はつか"]]),
                EssentialSection(title: "Weekdays",
                    body: "月 Mon · 火 Tue · 水 Wed · 木 Thu · 金 Fri · 土 Sat · 日 Sun, each + 曜日: 月曜日."),
                EssentialSection(title: "When to use に",
                    body: "Exact times and dates take に (三時に, 五月に). Relative words don't: 今日, 明日, 毎朝, 来週.")
            ]),
        EssentialChapter(id: 11, ja: "こそあど", en: "This, that, which",
            intro: "One system covers this / that / that-over-there / which, for things, places, directions and kinds.",
            summaryTH: "こ = ใกล้ผู้พูด そ = ใกล้ผู้ฟัง あ = ไกลทั้งคู่ ど = คำถาม (これ・それ・あれ・どれ)",
            sections: [
                EssentialSection(title: "The grid",
                    body: "こ is near me, そ is near you, あ is far from both of us, ど asks which.",
                    table: [["", "こ", "そ", "あ", "ど"], ["thing", "これ", "それ", "あれ", "どれ"], ["+ noun", "この", "その", "あの", "どの"], ["place", "ここ", "そこ", "あそこ", "どこ"], ["direction (polite)", "こちら", "そちら", "あちら", "どちら"], ["kind", "こんな", "そんな", "あんな", "どんな"]]),
                EssentialSection(title: "これ vs この",
                    body: "これ stands alone; この needs a noun after it: これは本です / この本は高いです.")
            ]),
        EssentialChapter(id: 12, ja: "決まり文句", en: "Set phrases & あいづち",
            intro: "Daily life runs on fixed phrases. Learn them whole, like words.",
            summaryTH: "วลีประจำวันที่ต้องรู้ และ あいづち (はい・そうですね・へえ) ที่แสดงว่ากำลังฟังอยู่",
            sections: [
                EssentialSection(title: "Every day",
                    body: "",
                    table: [["Phrase", "When"], ["おはようございます", "good morning"], ["いただきます", "before eating"], ["ごちそうさまでした", "after eating"], ["いってきます / いってらっしゃい", "leaving home / seeing someone off"], ["ただいま / おかえりなさい", "coming home / welcoming back"], ["お疲れさまです", "to colleagues, after work"], ["すみません", "excuse me · sorry · thank you"]]),
                EssentialSection(title: "あいづち: show you're listening",
                    body: "Japanese listeners make small sounds while the other person talks: はい, ええ, そうですか, へえ, なるほど. Staying silent can sound like you're not following."),
                EssentialSection(title: "Saying no softly",
                    body: "A flat いいえ can feel blunt. Use ちょっと… (trailing off), 大丈夫です (I'm fine without it), or 結構です (no, thank you).")
            ])
    ]
}
