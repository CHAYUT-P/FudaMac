import SwiftUI

// Interactive explainers for Lesson 8 (て形). Each one is self-contained:
// pick something, watch the rule light up.

private struct InfoTitle: View {
    let kicker: String
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            TrackedLabel(text: kicker, color: Ink.akane)
            MixedText(title, size: 24, weight: .bold)
        }
    }
}

private func chip(_ text: String, on: Bool, size: CGFloat = 17, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(text).font(Typo.mincho(size)).padding(.horizontal, 12).frame(height: 38)
            .foregroundStyle(on ? Ink.onInk : Ink.ink).background(on ? Ink.ink : Ink.card)
            .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 2))
            .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
}

// MARK: - 01 The て-form machine

struct TeMachineView: View {
    @Environment(ProgressStore.self) private var store
    struct Verb { let v, r: String; let group: Int; let end: String; let rule: Int; let teStem, teEnd, teReading, use: String }
    static let verbs: [Verb] = [
        .init(v: "買う", r: "かう", group: 1, end: "う", rule: 0, teStem: "買っ", teEnd: "て", teReading: "かって", use: "buy → 買ってください please buy"),
        .init(v: "待つ", r: "まつ", group: 1, end: "つ", rule: 0, teStem: "待っ", teEnd: "て", teReading: "まって", use: "wait → ちょっと待って"),
        .init(v: "帰る", r: "かえる", group: 1, end: "る", rule: 0, teStem: "帰っ", teEnd: "て", teReading: "かえって", use: "go home → 家に帰って"),
        .init(v: "飲む", r: "のむ", group: 1, end: "む", rule: 1, teStem: "飲ん", teEnd: "で", teReading: "のんで", use: "drink → 薬を飲んで"),
        .init(v: "遊ぶ", r: "あそぶ", group: 1, end: "ぶ", rule: 1, teStem: "遊ん", teEnd: "で", teReading: "あそんで", use: "play → 公園で遊んで"),
        .init(v: "死ぬ", r: "しぬ", group: 1, end: "ぬ", rule: 1, teStem: "死ん", teEnd: "で", teReading: "しんで", use: "die (the only ぬ verb)"),
        .init(v: "書く", r: "かく", group: 1, end: "く", rule: 2, teStem: "書い", teEnd: "て", teReading: "かいて", use: "write → 名前を書いて"),
        .init(v: "行く", r: "いく", group: 1, end: "く", rule: 2, teStem: "行っ", teEnd: "て", teReading: "いって", use: "go → the one く exception!"),
        .init(v: "泳ぐ", r: "およぐ", group: 1, end: "ぐ", rule: 3, teStem: "泳い", teEnd: "で", teReading: "およいで", use: "swim → 海で泳いで"),
        .init(v: "話す", r: "はなす", group: 1, end: "す", rule: 4, teStem: "話し", teEnd: "て", teReading: "はなして", use: "speak → 日本語で話して"),
        .init(v: "食べる", r: "たべる", group: 2, end: "る", rule: 5, teStem: "食べ", teEnd: "て", teReading: "たべて", use: "eat → 朝ご飯を食べて"),
        .init(v: "見る", r: "みる", group: 2, end: "る", rule: 5, teStem: "見", teEnd: "て", teReading: "みて", use: "look → これを見て"),
        .init(v: "する", r: "する", group: 3, end: "する", rule: 6, teStem: "", teEnd: "して", teReading: "して", use: "do → 勉強して"),
        .init(v: "来る", r: "くる", group: 3, end: "来る", rule: 6, teStem: "", teEnd: "来て", teReading: "きて", use: "come → ここに来て")
    ]
    static let rules: [(String, String)] = [("う · つ · る", "って"), ("む · ぶ · ぬ", "んで"), ("く", "いて"), ("ぐ", "いで"), ("す", "して"), ("る (Group 2)", "て"), ("する · 来る", "して · きて")]

    @State private var vi = 3
    @State private var quiz = false
    @State private var guess: Int?

    var body: some View {
        let c = Self.verbs[vi]
        let exception = c.v == "行く", trap = c.v == "帰る"
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                InfoTitle(kicker: "The て-form machine", title: "Pick a verb and watch it change")
                Spacer()
                Segmented(options: [(false, "Show me"), (true, "Quiz me")], selection: Binding(get: { quiz }, set: { quiz = $0; guess = nil }), height: 34)
            }
            Flow(spacing: 6) {
                ForEach(Self.verbs.indices, id: \.self) { i in chip(Self.verbs[i].v, on: i == vi) { vi = i; guess = nil } }
            }
            HStack(alignment: .top, spacing: 0) {
                station("① Which group?") {
                    ForEach(Array(["Group 1 · 五段 u-verbs", "Group 2 · 一段 る-verbs", "Irregular · する 来る"].enumerated()), id: \.offset) { i, t in
                        Text(t).font(Typo.ui(12, .bold)).padding(.horizontal, 8).padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(c.group == i + 1 ? Ink.onAkane : Ink.soft)
                            .background(c.group == i + 1 ? Ink.akane : .clear)
                            .overlay(Rectangle().strokeBorder(c.group == i + 1 ? Ink.akane : Ink.line, lineWidth: 1.5))
                    }
                    MixedText(groupNote(c, trap: trap), size: 12)
                    if trap { Text("TRAP · LOOKS LIKE GROUP 2").font(.system(size: 10, weight: .heavy)).padding(5).foregroundStyle(Ink.onAkane).background(Ink.akane) }
                }
                arrow
                station("② Look at the end") {
                    if store.settings.showFurigana { Text(c.r).font(Typo.ui(13)).foregroundStyle(Ink.soft).frame(maxWidth: .infinity) }
                    HStack(spacing: 0) {
                        if c.group != 3 { Text(String(c.v.dropLast())) }
                        Text(c.group == 3 ? c.v : c.end)
                            .padding(.horizontal, 4)
                            .foregroundStyle(c.group == 3 ? Ink.ink : Ink.onAkane)
                            .background(c.group == 3 ? .clear : Ink.akane)
                            .overlay(Rectangle().strokeBorder(c.group == 3 ? Ink.akane : .clear, lineWidth: 3))
                    }
                    .font(Typo.mincho(42)).frame(maxWidth: .infinity)
                    MixedText(c.group == 1 ? "Last sound: \(c.end). Find its row in the rules." : c.group == 2 ? "Drop the る. Nothing else changes." : "The whole verb changes.", size: 12, center: true)
                        .frame(maxWidth: .infinity)
                }
                arrow
                station("③ Apply the rule") {
                    ForEach(Self.rules.indices, id: \.self) { i in
                        HStack {
                            Text(Self.rules[i].0); Spacer(); Text("→ \(Self.rules[i].1)")
                        }
                        .font(Typo.mincho(14)).padding(.horizontal, 8).padding(.vertical, 5)
                        .foregroundStyle(c.rule == i ? Ink.onAkane : Ink.soft)
                        .background(c.rule == i ? Ink.akane : .clear)
                        .overlay(Rectangle().strokeBorder(c.rule == i ? Ink.akane : Ink.line, lineWidth: 1.5))
                    }
                }
                arrow
                VStack(alignment: .leading, spacing: 10) {
                    TrackedLabel(text: "④ て-form", color: Color(hex: 0xE5605B), size: 10)
                    if !quiz || guess != nil {
                        VStack(spacing: 8) {
                            (Text(c.teStem) + Text(c.teEnd).foregroundColor(Color(hex: 0xE5605B))).font(Typo.mincho(46))
                            if store.settings.showFurigana { Text(c.teReading).font(Typo.ui(14)).opacity(0.85) }
                            if store.settings.showRomaji { Text(Romaji.from(c.teReading)).font(Typo.ui(13)).opacity(0.75) }
                            MixedText(c.use, size: 12, color: Ink.onInk, center: true).opacity(0.85)
                            Text(exception ? "例外" : "○").font(Typo.mincho(18)).foregroundStyle(Ink.onAkane)
                                .frame(width: 44, height: 44).background(Ink.akane).rotationEffect(.degrees(-6))
                            if let guess { Text(guess == 0 ? "正解!" : "The answer is \(c.teStem + c.teEnd)").font(Typo.ui(12, .heavy)) }
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Text("Which is right?").font(Typo.ui(13)).opacity(0.85)
                        ForEach([1, 0, 2], id: \.self) { k in
                            Button { guess = k; k == 0 ? Haptic.success() : Haptic.warning() } label: {
                                Text(options(c)[k]).font(Typo.mincho(20)).frame(maxWidth: .infinity, minHeight: 42)
                                    .overlay(Rectangle().strokeBorder(Ink.onInk, lineWidth: 2)).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Ink.onInk)
                .padding(16).frame(maxWidth: .infinity, minHeight: 330, alignment: .topLeading)
                .background(ZStack { Ink.ink; HalftoneField(fade: .down, spacing: 6, maxRadius: 1.6, color: Ink.onInk).opacity(0.2) })
            }
            HStack(spacing: 6) {
                TrackedLabel(text: "Remember it as a song", color: Ink.akane, size: 10)
                ForEach(0..<5, id: \.self) { i in
                    let on = c.rule == i
                    HStack(spacing: 6) { Text(Self.rules[i].0.replacingOccurrences(of: " · ", with: " ")).font(Typo.mincho(15)); Text("→ \(Self.rules[i].1)").font(Typo.ui(11, .heavy)) }
                        .padding(6).frame(maxWidth: .infinity)
                        .foregroundStyle(on ? Ink.onAkane : Ink.ink)
                        .background(on ? Ink.akane : Ink.chip)
                }
            }
            .padding(10).inkBox()
        }
    }

    private var arrow: some View {
        Text("→").font(.system(size: 22, weight: .heavy)).foregroundStyle(Ink.akane).frame(width: 30).frame(minHeight: 330)
    }

    private func station<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TrackedLabel(text: title, size: 10)
            content()
            Spacer(minLength: 0)
        }
        .padding(14).frame(maxWidth: .infinity, minHeight: 330, alignment: .topLeading)
        .inkBox()
    }

    private func groupNote(_ c: Verb, trap: Bool) -> String {
        if c.group == 1 { return trap ? "It ends in える, but 帰る is Group 1. Memorise the few like it: 帰る · 入る · 走る · 知る." : "Ends in an -u sound and isn't an いる/える verb, so it's Group 1. Its last sound decides the rule." }
        if c.group == 2 { return "Ends in いる or える: Group 2. Just swap る for て." }
        return "Only two verbs are irregular. Learn them by heart."
    }

    /// [correct, wrong, wrong]
    private func options(_ c: Verb) -> [String] {
        if c.v == "行く" { return ["行って", "行いて", "行んで"] }
        if c.v == "する" { return ["して", "すて", "しって"] }
        if c.v == "来る" { return ["来て", "来って", "来いて"] }
        let wrong: [Int: [String]] = [0: ["んで", "いて"], 1: ["って", "いで"], 2: ["って", "んで"], 3: ["いて", "んで"], 4: ["って", "いて"], 5: ["って", "んで"]]
        let stem = c.group == 1 ? String(c.v.dropLast()) : c.teStem
        return [c.teStem + c.teEnd, stem + wrong[c.rule]![0], stem + wrong[c.rule]![1]]
    }
}

// MARK: - 02 Politeness ladder

struct PolitenessLadderView: View {
    @Environment(ProgressStore.self) private var store
    @State private var level = 2
    @State private var dont = false
    static let rungs: [(String, String, String, String, String)] = [
        ("食べろ", "食べるな", "Command", "Rough. Coaches, angry parents, anime", "N4"),
        ("食べて", "食べないで", "Casual request", "Friends, family, people younger than you", "N5"),
        ("食べてください", "食べないでください", "Polite request", "The default with teachers, staff, strangers", "THIS LESSON"),
        ("食べてくださいませんか", "食べないでくださいませんか", "Softer, very polite", "Asking a favour of someone senior", "N4")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            InfoTitle(kicker: "The politeness ladder", title: "Same request, four levels of politeness")
            Segmented(options: [(false, "Do ～てください"), (true, "Don't ～ないでください")], selection: $dont, height: 34)
            HStack(alignment: .top, spacing: 18) {
                VStack(spacing: 0) {
                    Text("POLITE").font(.system(size: 10, weight: .heavy))
                    VStack(spacing: 0) {
                        ForEach((0..<4).reversed(), id: \.self) { i in
                            ZStack {
                                if i == level { Ink.akane } else if i < level { Screentone(density: 0.3 + Double(i) * 0.2, spacing: 5) }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .overlay(alignment: .top) { if i != 3 { Rectangle().fill(Ink.ink).frame(height: 1.5) } }
                        }
                    }
                    .frame(width: 60, height: 300)
                    .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 2))
                    Text("ROUGH").font(.system(size: 10, weight: .heavy))
                }
                VStack(spacing: 8) {
                    ForEach((0..<4).reversed(), id: \.self) { i in
                        let r = Self.rungs[i], on = i == level
                        Button { level = i; Speech.shared.say(dont ? r.1 : r.0) } label: {
                            HStack(spacing: 18) {
                                let jp = dont ? r.1 : r.0
                                JPText(ja: jp, kana: jp.replacingOccurrences(of: "食", with: "た"), size: 24, bold: true, color: on ? Ink.onAkane : Ink.ink)
                                    .frame(width: 330, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r.2).font(Typo.ui(14, .heavy))
                                    Text(r.3).font(Typo.ui(12)).opacity(0.8)
                                }
                                Spacer()
                                Text(r.4).font(.system(size: 10, weight: .heavy)).tracking(1)
                            }
                            .padding(.horizontal, 18).frame(height: 68)
                            .foregroundStyle(on ? Ink.onAkane : Ink.ink).background(on ? Ink.akane : Ink.card)
                            .overlay(Rectangle().strokeBorder(on ? Ink.akane : Ink.ink, lineWidth: 2))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack(spacing: 12) {
                ForEach(scenes, id: \.0) { s in
                    VStack(alignment: .leading, spacing: 3) {
                        TrackedLabel(text: s.0, size: 10)
                        JPText(ja: s.1, kana: Self.kana[s.1] ?? "", size: 18, bold: true)
                        Text(s.2).font(Typo.ui(12))
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading).inkBox()
                    .overlay(alignment: .topTrailing) { SpeakIcon(text: s.1, size: 24).padding(8) }
                }
            }
        }
    }

    static let kana: [String: String] = [
        "写真を撮らないでください": "しゃしんをとらないでください", "心配しないでください": "しんぱいしないでください", "忘れないでください": "わすれないでください",
        "窓を開けてください": "まどをあけてください", "東京駅まで行ってください": "とうきょうえきまでいってください", "ちょっと待ってください": "ちょっとまってください"
    ]

    private var scenes: [(String, String, String)] {
        dont
        ? [("MUSEUM", "写真を撮らないでください", "กรุณาอย่าถ่ายรูป · Please don't take photos"), ("CLINIC", "心配しないでください", "ไม่ต้องกังวลนะ · Please don't worry"), ("CLASS", "忘れないでください", "อย่าลืมนะ · Please don't forget")]
        : [("CLASSROOM", "窓を開けてください", "กรุณาเปิดหน้าต่าง · Please open the window"), ("TAXI", "東京駅まで行ってください", "ไปสถานีโตเกียวครับ · To Tokyo Station, please"), ("SHOP", "ちょっと待ってください", "รอสักครู่นะ · One moment, please")]
    }
}

// MARK: - 03 / 04 〜ている timeline

struct TeiruTimelineView: View {
    @Environment(ProgressStore.self) private var store
    let state: Bool
    @State private var pick = 0

    static let progress: [(String, String, String, String, String, Bool)] = [
        ("食べる → 食べている", "いま、ごはんをたべています。", "今、ご飯を食べています。", "ตอนนี้กำลังกินข้าวอยู่", "I am eating now.", false),
        ("降る → 降っている", "あめがふっています。", "雨が降っています。", "ฝนกำลังตกอยู่", "It is raining.", false),
        ("勉強する → 勉強している", "としょかんでべんきょうしています。", "図書館で勉強しています。", "กำลังเรียนอยู่ที่ห้องสมุด", "I'm studying at the library.", false),
        ("走る → 毎朝走っている", "まいあさこうえんをはしっています。", "毎朝公園を走っています。", "วิ่งที่สวนทุกเช้า (เป็นนิสัย)", "I run in the park every morning.", true)
    ]
    static let states: [(String, String, String, String, String, String)] = [
        ("結婚する → 結婚している", "あねはけっこんしています。", "姉は結婚しています。", "พี่สาวแต่งงานแล้ว", "My sister is married.", "結婚した"),
        ("知る → 知っている", "たなかさんをしっています。", "田中さんを知っています。", "รู้จักคุณทานากะ", "I know Mr Tanaka.", "知った"),
        ("住む → 住んでいる", "とうきょうにすんでいます。", "東京に住んでいます。", "อาศัยอยู่ที่โตเกียว", "I live in Tokyo.", "住み始めた"),
        ("来る → 来ている", "ともだちがきています。", "友達が来ています。", "เพื่อนมาถึงแล้ว (และยังอยู่)", "My friend is here (has come).", "来た")
    ]

    var body: some View {
        let labels = state ? Self.states.map(\.0) : Self.progress.map(\.0)
        let kana = state ? Self.states[pick].1 : Self.progress[pick].1
        let ja = state ? Self.states[pick].2 : Self.progress[pick].2
        let th = state ? Self.states[pick].3 : Self.progress[pick].3
        let en = state ? Self.states[pick].4 : Self.progress[pick].4
        let habit = !state && Self.progress[pick].5
        VStack(alignment: .leading, spacing: 16) {
            InfoTitle(kicker: state ? "〜ている ② · A state after a change" : "〜ている ① · An action in progress",
                      title: state ? "The change happened. ている shows the result is still true now" : "NOW is inside the action, so it hasn't finished")
            Flow(spacing: 6) { ForEach(labels.indices, id: \.self) { i in chip(labels[i], on: i == pick, size: 15) { pick = i } } }
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let axisY = h * 0.58, nowX = w * 0.62
                ZStack(alignment: .topLeading) {
                    Ink.card
                    Rectangle().fill(Ink.ink).frame(width: w - 60, height: 2).position(x: w / 2, y: axisY)
                    Text("▶").font(.system(size: 14, weight: .heavy)).position(x: w - 24, y: axisY)
                    Text("PAST").font(.system(size: 11, weight: .heavy)).tracking(1.5).foregroundStyle(Ink.soft).position(x: 50, y: axisY + 20)
                    Text("FUTURE").font(.system(size: 11, weight: .heavy)).tracking(1.5).foregroundStyle(Ink.soft).position(x: w - 60, y: axisY + 20)
                    if state {
                        Rectangle().fill(Ink.ink).frame(width: w - 30 - w * 0.3, height: 44).position(x: (w * 0.3 + w - 30) / 2, y: axisY)
                        Circle().fill(Ink.akane).frame(width: 28, height: 28).overlay(Circle().strokeBorder(Ink.card, lineWidth: 3)).position(x: w * 0.3, y: axisY)
                        Text(Self.states[pick].5 + " ●").font(Typo.mincho(16)).foregroundStyle(Ink.akane).position(x: w * 0.3, y: axisY - 46)
                    } else if habit {
                        ForEach([0.18, 0.30, 0.42, 0.54, 0.66, 0.78], id: \.self) { x in
                            Screentone(density: 0.6, spacing: 4).frame(width: 16, height: 36).overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 2)).position(x: w * x, y: axisY)
                        }
                    } else {
                        Screentone(density: 0.55, spacing: 5).background(Ink.card).frame(width: w * 0.3, height: 44)
                            .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 2)).position(x: w * 0.59, y: axisY)
                    }
                    Rectangle().fill(Ink.akane).frame(width: 3, height: h - 70).position(x: nowX, y: h / 2 + 4)
                    Text("NOW 今").font(.system(size: 11, weight: .heavy)).tracking(1.5).foregroundStyle(Ink.onAkane)
                        .padding(.horizontal, 10).padding(.vertical, 3).background(Ink.akane).position(x: nowX, y: 22)
                    Text(state ? "the state that follows → still true now" : habit ? "repeated again and again → a habit" : "started before now, not finished yet")
                        .font(Typo.ui(13, .heavy)).position(x: w * 0.6, y: axisY - 72)
                    VStack(alignment: .leading, spacing: 4) {
                        JPText(ja: ja, kana: kana, size: 30, bold: true)
                        Text("\(th) · \(en)").font(Typo.ui(14))
                    }
                    .padding(.leading, 30).padding(.top, h - 110)
                    SpeakIcon(text: kana).position(x: w - 40, y: h - 50)
                }
            }
            .frame(height: 420)
            .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 2))
            HStack(spacing: 20) {
                if state {
                    legend(AnyView(Circle().fill(Ink.akane).frame(width: 14, height: 14)), "the moment it happened (instant)")
                    legend(AnyView(Rectangle().fill(Ink.ink).frame(width: 26, height: 14)), "the resulting state, still true now")
                } else {
                    legend(AnyView(Screentone(density: 0.55, spacing: 4).frame(width: 26, height: 14).overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 1.5))), "action in progress")
                    legend(AnyView(Rectangle().fill(Ink.akane).frame(width: 4, height: 16)), "NOW, inside the action")
                }
            }
        }
    }

    private func legend(_ swatch: AnyView, _ text: String) -> some View {
        HStack(spacing: 8) { swatch; Text(text).font(Typo.ui(12)) }
    }
}

// MARK: - 05 The て chain

struct TeChainView: View {
    @Environment(ProgressStore.self) private var store
    enum Kind: String, CaseIterable { case sequence = "Sequence", reason = "Reason", manner = "Manner" }
    static let chains: [Kind: [(String, String, String, String, String)]] = [
        .sequence: [("起き", "て", "おきて", "ตื่น", "WAKE UP"), ("顔を洗っ", "て", "かおをあらって", "ล้างหน้า", "WASH"), ("朝ご飯を食べ", "て", "あさごはんをたべて", "กินข้าวเช้า", "EAT"), ("学校に行き", "ます", "がっこうにいきます", "ไปโรงเรียน", "GO")],
        .reason: [("風邪をひい", "て", "かぜをひいて", "เป็นหวัด", "CAUSE"), ("学校を休み", "ます", "がっこうをやすみます", "หยุดเรียน", "RESULT")],
        .manner: [("歩い", "て", "あるいて", "เดิน (โดยการเดิน)", "HOW"), ("駅まで行き", "ます", "えきまでいきます", "ไปสถานี", "ACTION")]
    ]

    @State private var kind: Kind = .sequence
    @State private var shown = 4
    @State private var past = false

    var body: some View {
        let list = Self.chains[kind]!
        let n = min(shown, list.count)
        let sentence = list.prefix(n).enumerated().map { i, x in x.0 + (i == list.count - 1 ? (past ? "ました" : "ます") : x.1) }.joined(separator: "、") + (n == list.count ? "。" : "…")
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                InfoTitle(kicker: "The て chain", title: "て links actions. Only the last verb shows the tense")
                Spacer()
                Segmented(options: Kind.allCases.map { ($0, $0.rawValue) }, selection: Binding(get: { kind }, set: { kind = $0; shown = 1 }), height: 34)
            }
            HStack(spacing: 0) {
                ForEach(list.indices, id: \.self) { i in
                    let x = list[i], last = i == list.count - 1, vis = i < n
                    VStack(alignment: .leading, spacing: 6) {
                        Text(x.4).font(.system(size: 10, weight: .heavy)).tracking(1.5).opacity(0.7)
                        let reading = last && past ? x.2.replacingOccurrences(of: "ます", with: "ました") : x.2
                        if store.settings.showFurigana { Text(reading).font(Typo.ui(12)).opacity(0.75) }
                        (Text(x.0) + Text(last ? (past ? "ました" : "ます") : x.1).foregroundColor(last ? Color(hex: 0xE5605B) : Ink.akane).underline(!last, color: Ink.akane))
                            .font(Typo.mincho(24))
                        if store.settings.showRomaji { Text(Romaji.from(reading)).font(Typo.ui(11)).opacity(0.7) }
                        Text(x.3).font(Typo.ui(13))
                        Text(last ? (past ? "TENSE: PAST, FOR ALL" : "TENSE LIVES HERE") : "NO TENSE")
                            .font(.system(size: 10, weight: .heavy)).tracking(1)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .foregroundStyle(last ? Ink.onAkane : Ink.soft)
                            .background(last ? Ink.akane : .clear)
                            .overlay(Rectangle().strokeBorder(last ? .clear : Ink.ink, lineWidth: 1.5))
                    }
                    .padding(16).frame(maxWidth: .infinity, minHeight: 200, alignment: .leading)
                    .foregroundStyle(last ? Ink.onInk : Ink.ink)
                    .background(last ? Ink.ink : Ink.card)
                    .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 2))
                    .opacity(vis ? 1 : 0.12)
                    if !last {
                        Text("て →").font(Typo.mincho(15)).foregroundStyle(Ink.akane).padding(.horizontal, 8).opacity(i + 1 < n ? 1 : 0.15)
                    }
                }
            }
            HStack(spacing: 12) {
                Button(n < list.count ? "Add the next action →" : "Start again") { shown = n < list.count ? n + 1 : 1 }
                    .buttonStyle(InkButtonStyle(kind: .akane, height: 42)).frame(width: 210)
                Button(past ? "Make it present (ます)" : "Make it past (ました)") { past.toggle() }
                    .buttonStyle(InkButtonStyle(kind: .outline, height: 42)).frame(width: 210)
                Text(sentence).font(Typo.mincho(18, bold: false)).textSelection(.enabled)
                Spacer()
                SpeakIcon(text: sentence)
            }
            .padding(12).inkBox()
        }
    }
}
