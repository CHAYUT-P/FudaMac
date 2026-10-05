import SwiftUI

struct MacEssentialsView: View {
    @Environment(CourseProgress.self) private var course
    @Environment(MacRouter.self) private var router

    var body: some View {
        let chapters = Essentials.chapters
        let cur = chapters.first { $0.id == router.essentialID } ?? chapters[0]
        HStack(spacing: 0) {
            ListColumn(width: 280) {
                VStack(alignment: .leading, spacing: 4) {
                    TrackedLabel(text: "基 · Essentials")
                    Text("How Japanese works").font(Typo.mincho(24))
                    Text("\(chapters.count) chapters · about 5 min each").font(Typo.ui(12)).foregroundStyle(Ink.soft)
                }
                .padding(.horizontal, 22).padding(.top, 22).padding(.bottom, 10)
                ForEach(chapters) { c in
                    ListRow(title: "\(String(format: "%02d", c.id))  \(c.ja)", subtitle: c.en, trailing: course.essentials.contains(c.id) ? "済" : "", trailingAccent: true, selected: c.id == cur.id) {
                        router.essentialID = c.id
                    }
                }
            }
            EssentialPage(chapter: cur).id(cur.id)
        }
    }
}

struct EssentialPage: View {
    @Environment(CourseProgress.self) private var course
    @Environment(MacRouter.self) private var router
    let chapter: EssentialChapter

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    TrackedLabel(text: "Chapter \(String(format: "%02d", chapter.id))", color: Ink.akane)
                    MixedText("\(chapter.ja) — \(chapter.en)", size: 34, weight: .bold)
                    MixedText(chapter.intro, size: 16).frame(maxWidth: 820, alignment: .leading)
                    MixedText(chapter.summaryTH, size: 13, color: Ink.soft).frame(maxWidth: 820, alignment: .leading)
                }
                .overlay(alignment: .topTrailing) {
                    Text(chapter.ja.prefix(1)).font(Typo.mincho(220)).foregroundStyle(Ink.ink.opacity(0.06)).offset(x: 0, y: -60).allowsHitTesting(false)
                }

                switch chapter.widget {
                case .scripts: ScriptsWidget()
                case .particles: ParticleMapWidget()
                case .verbGroups: VerbSorterWidget()
                case .politeness: PolitenessWidget()
                case .counters: CounterWidget()
                case .none: EmptyView()
                }

                ForEach(Array(chapter.sections.enumerated()), id: \.offset) { i, s in
                    VStack(alignment: .leading, spacing: 10) {
                        NumberedRule(numeral: ["一", "二", "三", "四", "五", "六"][min(i, 5)], title: s.title)
                        if !s.body.isEmpty { MixedText(s.body, size: 15).frame(maxWidth: 820, alignment: .leading).textSelection(.enabled) }
                        if !s.table.isEmpty { table(s.table) }
                        ForEach(s.examples, id: \.self) { e in
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    JPText(ja: e.ja, kana: e.kana, size: 20)
                                    Text(e.en).font(Typo.ui(13)).foregroundStyle(Ink.soft)
                                }
                                .textSelection(.enabled)
                                Spacer()
                                SpeakIcon(text: e.kana)
                            }
                            .padding(14).inkBox()
                        }
                    }
                }

                HStack {
                    Button(course.essentials.contains(chapter.id) ? "✓ Read" : "Mark as read") { course.markEssential(chapter.id) }
                        .buttonStyle(InkButtonStyle(kind: course.essentials.contains(chapter.id) ? .ink : .outline, height: 44)).frame(width: 180)
                    Spacer()
                    if chapter.id < Essentials.chapters.count {
                        Button("Next: \(Essentials.chapters[chapter.id].ja) →") { course.markEssential(chapter.id); router.essentialID = chapter.id + 1 }
                            .buttonStyle(InkButtonStyle(kind: .akane, height: 44)).frame(width: 240)
                    }
                }
            }
            .padding(36)
        }
    }

    private func table(_ rows: [[String]]) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
            ForEach(rows.indices, id: \.self) { r in
                GridRow {
                    ForEach(rows[r].indices, id: \.self) { c in
                        MixedText(rows[r][c], size: r == 0 ? 11 : 14, weight: r == 0 ? .heavy : .regular, color: r == 0 ? Ink.onInk : Ink.ink, furigana: r == 0 ? false : nil, romaji: r == 0 ? false : nil)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(r == 0 ? Ink.ink : (c == 0 ? Ink.chip.opacity(0.6) : Ink.card))
                    }
                }
                if r > 0 && r < rows.count - 1 { Divider().overlay(Ink.line) }
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: 820)
        .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 2))
    }
}

// MARK: - Widgets

private struct WidgetFrame<C: View>: View {
    let title: String
    @ViewBuilder var content: () -> C
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TrackedLabel(text: title, color: Ink.akane, size: 11)
            content()
        }
        .padding(22).frame(maxWidth: 900, alignment: .leading).inkBox()
    }
}

/// 01: colour a sentence by script.
struct ScriptsWidget: View {
    @State private var show: Int? = nil       // 0 hira, 1 kata, 2 kanji
    private let sentence = "私はタイ人です。毎朝コーヒーを飲みます。"

    private func kind(_ c: Character) -> Int? {
        guard let u = c.unicodeScalars.first?.value else { return nil }
        if (0x3041...0x309F).contains(u) { return 0 }
        if (0x30A0...0x30FF).contains(u) { return 1 }
        if c.unicodeScalars.contains(where: { $0.properties.isIdeographic }) { return 2 }
        return nil
    }

    var body: some View {
        WidgetFrame(title: "Click a script to light it up") {
            HStack(spacing: 8) {
                ForEach(Array(["ひらがな Hiragana", "カタカナ Katakana", "漢字 Kanji"].enumerated()), id: \.offset) { i, t in
                    Button { show = show == i ? nil : i } label: {
                        Text(t).font(Typo.ui(13, .heavy)).padding(.horizontal, 12).frame(height: 34)
                            .foregroundStyle(show == i ? Ink.onAkane : Ink.ink).background(show == i ? Ink.akane : .clear)
                            .overlay(Rectangle().strokeBorder(show == i ? Ink.akane : Ink.ink, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 2) {
                ForEach(Array(sentence.enumerated()), id: \.offset) { _, ch in
                    let on = show != nil && kind(ch) == show
                    Text(String(ch)).font(Typo.mincho(34))
                        .foregroundStyle(on ? Ink.onAkane : (show == nil ? Ink.ink : Ink.ink.opacity(0.25)))
                        .padding(.horizontal, 1)
                        .background(on ? Ink.akane : .clear)
                }
            }
            Text("私はタイ人です。毎朝コーヒーを飲みます。 · I am Thai. I drink coffee every morning.").font(Typo.ui(12)).foregroundStyle(Ink.soft)
        }
    }
}

/// 05: the particle map from the design.
struct ParticleMapWidget: View {
    @State private var sel = 3
    private let chunks: [(String, String, String, String, String, String, String)] = [
        ("私", "わたし", "は", "TOPIC", "は — the topic", "\"As for me…\". It sets what the sentence is about. Written は but read \"wa\".", "บอกหัวเรื่อง: \"ส่วนฉัน…\" อ่านว่า wa"),
        ("毎朝", "まいあさ", "", "TIME", "No particle on relative time", "毎朝, 今日 and 明日 take no に. Clock times do: 七時に.", "คำบอกเวลาแบบสัมพัทธ์ไม่ต้องมี に"),
        ("駅", "えき", "で", "PLACE OF ACTION", "で — where it happens", "Marks the place an action takes place, and also the means: 電車で by train.", "สถานที่ที่การกระทำเกิดขึ้น / วิธีการ"),
        ("友達", "ともだち", "と", "WITH", "と — together with", "Marks a partner: 友達と with a friend. Between nouns it means \"and\": パンと卵.", "ร่วมกับ… / และ (เชื่อมคำนาม)"),
        ("電車", "でんしゃ", "に", "TARGET", "に — the target", "Marks the point an action reaches: getting on (乗る), meeting (会う), a time, a destination.", "เป้าหมาย/จุดหมายของการกระทำ"),
        ("乗ります", "のります", "", "VERB · ALWAYS LAST", "The verb comes last", "Particles let the other chunks move around, but the verb stays at the end.", "กริยาอยู่ท้ายประโยคเสมอ")
    ]

    var body: some View {
        let c = chunks[sel]
        WidgetFrame(title: "Particle map · click a particle") {
            Text("I take the train with a friend at the station every morning.").font(Typo.ui(12)).foregroundStyle(Ink.soft)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(chunks.indices, id: \.self) { i in
                    let k = chunks[i], on = i == sel
                    Button { sel = i } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .bottom, spacing: 2) {
                                JPText(ja: k.0, kana: k.1, size: 28, bold: true)
                                if !k.2.isEmpty { Text(k.2).font(Typo.mincho(28)).foregroundStyle(Ink.onAkane).padding(.horizontal, 4).background(Ink.akane) }
                            }
                            Text(k.3).font(.system(size: 10, weight: .heavy)).tracking(1).foregroundStyle(on ? Ink.akane : Ink.soft)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(on ? Ink.paper : Ink.card)
                        .overlay(Rectangle().strokeBorder(on ? Ink.akane : Ink.ink, lineWidth: 2))
                        .background(Rectangle().fill(on ? Ink.akane : .clear).offset(x: 4, y: 4))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(alignment: .top, spacing: 16) {
                Text(c.2.isEmpty ? (sel == 5 ? "動" : "∅") : c.2).font(Typo.mincho(46)).foregroundStyle(Ink.onAkane)
                    .frame(width: 86, height: 86).background(Ink.akane)
                VStack(alignment: .leading, spacing: 4) {
                    Text(c.4).font(Typo.ui(17, .heavy))
                    MixedText(c.5, size: 14)
                    MixedText(c.6, size: 13, color: Ink.soft)
                }
            }
            .padding(.top, 8)
            HStack {
                JPText(ja: "私は毎朝駅で友達と電車に乗ります。", kana: "わたしはまいあさえきでともだちとでんしゃにのります。", size: 18)
                SpeakIcon(text: "わたしはまいあさえきでともだちとでんしゃにのります。", size: 28)
            }
        }
    }
}

/// 06: pick any verb from your decks and see its group and forms.
struct VerbSorterWidget: View {
    @State private var pick = "帰る"
    private let sample = ["買う", "書く", "泳ぐ", "話す", "待つ", "死ぬ", "遊ぶ", "飲む", "帰る", "食べる", "見る", "起きる", "する", "来る", "勉強する", "入る"]

    var body: some View {
        let kana = DB.shared.vocab.first { $0.kanji == pick }?.kana ?? (pick == "来る" ? "くる" : pick)
        let forms = Conjugate.forms(pick, kana: kana)
        WidgetFrame(title: "Verb sorter · pick a verb") {
            Flow(spacing: 6) {
                ForEach(sample, id: \.self) { v in
                    Button { pick = v } label: {
                        Text(v).font(Typo.mincho(17)).padding(.horizontal, 12).frame(height: 36)
                            .foregroundStyle(v == pick ? Ink.onInk : Ink.ink).background(v == pick ? Ink.ink : Ink.paper)
                            .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            if let f = forms {
                HStack(alignment: .top, spacing: 18) {
                    HStack(spacing: 0) {
                        ForEach(1...3, id: \.self) { g in
                            Text(["", "Group 1\n五段", "Group 2\n一段", "Irregular\nする · 来る"][g]).font(Typo.ui(12, .heavy)).multilineTextAlignment(.center)
                                .frame(width: 110, height: 70)
                                .foregroundStyle(f.group.rawValue == g ? Ink.onAkane : Ink.soft)
                                .background(f.group.rawValue == g ? Ink.akane : .clear)
                                .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 1.5))
                        }
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(f.rows, id: \.0) { r in
                            HStack { Text(r.0).font(Typo.ui(12, .heavy)).frame(width: 100, alignment: .leading); Text(r.1).font(Typo.mincho(17)); Spacer(); Text(r.2).font(Typo.ui(11)).foregroundStyle(Ink.soft) }
                                .padding(.vertical, 4).overlay(alignment: .top) { Rectangle().fill(Ink.line).frame(height: 1) }
                        }
                    }
                    .frame(maxWidth: 380)
                }
                if ["帰る", "入る"].contains(pick) {
                    MixedText("Trap! It ends in える / いる but conjugates as Group 1: \(f.rows[1].1).", size: 13, weight: .heavy, color: Ink.akane)
                }
            }
        }
    }
}

/// 08: one verb across the three politeness levels.
struct PolitenessWidget: View {
    @State private var row = 0
    private let rows: [(String, String, String, String)] = [
        ("eat", "食べる", "食べます", "召し上がる (them) · いただく (me)"),
        ("go", "行く", "行きます", "いらっしゃる (them) · 参る (me)"),
        ("say", "言う", "言います", "おっしゃる (them) · 申す (me)"),
        ("see", "見る", "見ます", "ご覧になる (them) · 拝見する (me)"),
        ("is", "だ", "です", "でございます")
    ]
    var body: some View {
        let r = rows[row]
        WidgetFrame(title: "Same verb, three levels") {
            HStack(spacing: 6) {
                ForEach(rows.indices, id: \.self) { i in
                    Button { row = i } label: {
                        Text(rows[i].0).font(Typo.ui(13, .heavy)).padding(.horizontal, 12).frame(height: 32)
                            .foregroundStyle(i == row ? Ink.onInk : Ink.ink).background(i == row ? Ink.ink : .clear)
                            .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 0) {
                level("PLAIN · friends", r.1, density: 0)
                level("POLITE · です/ます", r.2, density: 0.45, accent: true)
                level("KEIGO · customers (N4)", r.3, density: 1)
            }
        }
    }
    private func level(_ title: String, _ form: String, density: CGFloat, accent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 10, weight: .heavy)).tracking(1)
            MixedText(form, size: density == 1 ? 17 : 24, weight: .bold, color: density == 1 ? Ink.onInk : Ink.ink)
            if accent { Text("← start here").font(Typo.ui(11, .heavy)).foregroundStyle(Ink.akane) }
        }
        .padding(16).frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .foregroundStyle(density == 1 ? Ink.onInk : Ink.ink)
        .background { ZStack { if density == 1 { Ink.ink } else { Ink.card; if density > 0 { Screentone(density: density, spacing: 5).opacity(0.35) } } } }
        .overlay(Rectangle().strokeBorder(accent ? Ink.akane : Ink.ink, lineWidth: 2))
    }
}

/// 09: counter + number → reading, with the sound changes.
struct CounterWidget: View {
    @State private var counter = 0
    @State private var n = 3
    private let counters: [(String, String, [String])] = [
        ("本", "long things", ["いっぽん", "にほん", "さんぼん", "よんほん", "ごほん", "ろっぽん", "ななほん", "はっぽん", "きゅうほん", "じゅっぽん"]),
        ("匹", "small animals", ["いっぴき", "にひき", "さんびき", "よんひき", "ごひき", "ろっぴき", "ななひき", "はっぴき", "きゅうひき", "じゅっぴき"]),
        ("人", "people", ["ひとり", "ふたり", "さんにん", "よにん", "ごにん", "ろくにん", "ななにん", "はちにん", "きゅうにん", "じゅうにん"]),
        ("枚", "flat things", ["いちまい", "にまい", "さんまい", "よんまい", "ごまい", "ろくまい", "ななまい", "はちまい", "きゅうまい", "じゅうまい"]),
        ("つ", "general things", ["ひとつ", "ふたつ", "みっつ", "よっつ", "いつつ", "むっつ", "ななつ", "やっつ", "ここのつ", "とお"])
    ]
    private let kanjiNums = ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]

    var body: some View {
        let c = counters[counter]
        let reading = c.2[n - 1]
        let regular = counter == 3
        WidgetFrame(title: "Counter machine · pick a counter and a number") {
            HStack(spacing: 6) {
                ForEach(counters.indices, id: \.self) { i in
                    Button { counter = i } label: {
                        VStack(spacing: 0) { Text(counters[i].0).font(Typo.mincho(20)); Text(counters[i].1).font(Typo.ui(10, .bold)) }
                            .padding(.horizontal, 10).frame(height: 52)
                            .foregroundStyle(i == counter ? Ink.onInk : Ink.ink).background(i == counter ? Ink.ink : .clear)
                            .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 4) {
                ForEach(1...10, id: \.self) { i in
                    Button { n = i; Speech.shared.say(c.2[i - 1]) } label: {
                        Text("\(i)").font(Typo.ui(15, .heavy)).frame(width: 40, height: 40)
                            .foregroundStyle(i == n ? Ink.onAkane : Ink.ink).background(i == n ? Ink.akane : Ink.paper)
                            .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 20) {
                Text(counter == 4 ? kanjiNums[n - 1] + "つ" : kanjiNums[n - 1] + c.0).font(Typo.mincho(54))
                Text(reading).font(Typo.ui(28, .bold)).foregroundStyle(Ink.akane)
                SpeakIcon(text: reading)
                Spacer()
                Text(regular ? "Regular: number + まい." : "Watch the sound changes on 1, 3, 6, 8 and 10.")
                    .font(Typo.ui(13)).foregroundStyle(Ink.soft)
            }
        }
    }
}
