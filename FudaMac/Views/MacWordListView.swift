import SwiftUI

// MARK: - 語 Word List — N5 + N4 words by theme, read as a list or type the meanings

@Observable
final class WordListState {
    enum Selection: Hashable { case category(String), sub(String) }
    /// list = read; test = see the word, type its meaning; recall = see the meaning, type the word.
    enum Mode: String {
        case list, test, recall
        var isTyping: Bool { self != .list }
        /// Results are kept per direction: "" = meaning, "jp:" = typing the Japanese.
        var markPrefix: String { self == .recall ? "jp:" : "" }
    }
    enum LevelFilter: String { case both, n5, n4 }

    var selection: Selection = .sub("food.dish")
    var expanded: Set<String> = ["food"]
    var mode: Mode = .list
    var level: LevelFilter = .both
    /// Typing mode only: random order every time (remembered between launches).
    var randomOrder: Bool = UserDefaults.standard.object(forKey: "wordList.randomOrder") as? Bool ?? true {
        didSet { UserDefaults.standard.set(randomOrder, forKey: "wordList.randomOrder") }
    }
    var showKana = true
    var showRomaji = true

    var order: [String] = []            // typing mode: shuffled ids (fresh on every start)
    var onlyIDs: Set<String>? = nil     // "retry wrong": just these words
    var answers: [String: String] = [:] // typed meanings
    var checked = false
    var results: [String: Bool] = [:]   // after checking

    func restart(keepOnly ids: Set<String>? = nil) {
        onlyIDs = ids
        answers = [:]
        results = [:]
        checked = false
        order = []
    }
}

struct MacWordListView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(MacRouter.self) private var router
    @FocusState private var focus: String?

    private var state: WordListState { router.wordList }
    private let wl = WordList.shared

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            detail
        }
        .onAppear { prepareOrder() }
        .onChange(of: state.selection) { _, _ in prepareOrder() }
        .onChange(of: state.level) { _, _ in prepareOrder() }
        .onChange(of: state.mode) { _, _ in state.restart(); prepareOrder() }
        .onChange(of: state.randomOrder) { _, _ in prepareOrder() }
        .onChange(of: focus) { _, f in router.typing = f != nil }
        .onDisappear { router.typing = false }
    }

    // MARK: Words in view

    private func baseWords() -> [ListWord] {
        let all: [ListWord]
        switch state.selection {
        case .category(let c): all = wl.words(category: c)
        case .sub(let s): all = wl.words(sub: s)
        }
        return all.filter { w in
            switch state.level {
            case .both: true
            case .n5: w.level == .n5
            case .n4: w.level == .n4
            }
        }
    }

    /// Words in display order. Reading: by subcategory, N5 then N4.
    /// Typing with Random on: the shuffled order, so position gives nothing away.
    private func words() -> [ListWord] {
        let base = baseWords().filter { state.onlyIDs?.contains($0.id) ?? true }
        let subRank = Dictionary(uniqueKeysWithValues: wl.categories.flatMap(\.subs).enumerated().map { ($1.id, $0) })
        let byCategory: Bool = { if case .category = state.selection { return true }; return false }()
        let ordered = base.enumerated().sorted { a, b in
            if byCategory, a.element.meta.sub != b.element.meta.sub {
                return (subRank[a.element.meta.sub] ?? 0) < (subRank[b.element.meta.sub] ?? 0)
            }
            if a.element.level != b.element.level { return a.element.level == .n5 }
            return a.offset < b.offset
        }.map(\.element)
        guard state.mode.isTyping, state.randomOrder, !state.order.isEmpty else { return ordered }
        let pos = Dictionary(uniqueKeysWithValues: state.order.enumerated().map { ($1, $0) })
        return ordered.sorted { (pos[$0.id] ?? .max) < (pos[$1.id] ?? .max) }
    }

    /// A fresh shuffle for typing mode (on opening a list, Again, Retry, Random).
    private func prepareOrder() {
        state.order = state.mode.isTyping && state.randomOrder ? baseWords().map(\.id).shuffled() : []
    }

    private func select(_ s: WordListState.Selection) {
        guard s != state.selection else { return }
        state.selection = s
        state.restart()
    }

    /// Random subcategory, weighted towards the ones with the most words you don't know yet.
    private func randomPick() {
        let subs = wl.categories.flatMap(\.subs).filter { !wl.words(sub: $0.id).isEmpty }
        let weighted = subs.map { s -> (WordSub, Int) in
            let ids = wl.words(sub: s.id).map(markKey)
            return (s, max(1, ids.count - store.listKnown(ids)))
        }.filter { $0.0.id != currentSubID }
        let total = weighted.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return }
        var r = Int.random(in: 0..<total)
        for (s, w) in weighted {
            if r < w {
                if let c = wl.category(of: s.id) { state.expanded.insert(c.id) }
                state.selection = .sub(s.id)
                if state.mode == .list { state.mode = .test }
                state.restart()
                prepareOrder()
                DispatchQueue.main.async { focus = words().first?.id }
                return
            }
            r -= w
        }
    }

    /// Progress key for the direction on screen (reading counts as the meaning direction).
    private func markKey(_ w: ListWord) -> String { state.mode.markPrefix + w.id }

    private var currentSubID: String? {
        if case .sub(let s) = state.selection { return s }
        return nil
    }

    // MARK: Sidebar

    private var sidebar: some View {
        let all = wl.all
        let known = store.listKnown(all.map(markKey))
        return ListColumn(width: 330) {
            VStack(alignment: .leading, spacing: 12) {
                TrackedLabel(text: "語 · Word list")
                Text("N5 + N4 · \(all.count) words").font(Typo.ui(13, .bold))
                levelBar("N5", all.filter { $0.level == .n5 })
                levelBar("N4", all.filter { $0.level == .n4 })
                Button(action: randomPick) {
                    HStack(spacing: 8) {
                        Image(systemName: "die.face.5")
                        Text("สุ่มหมวด · Random list")
                        Spacer()
                        Kbd("⌘R", light: true)
                    }
                    .padding(.horizontal, 14)
                }
                .buttonStyle(InkButtonStyle(kind: .akane, height: 44))
                .keyboardShortcut("r", modifiers: .command)
                Text(state.mode == .recall
                     ? "พิมพ์ญี่ปุ่นได้ \(known) จาก \(all.count) คำ · typing the word"
                     : "รู้ความหมาย \(known) จาก \(all.count) คำ · known = last answer right")
                    .font(Typo.ui(11)).foregroundStyle(Ink.soft)
            }
            .padding(.horizontal, 22).padding(.top, 22).padding(.bottom, 8)

            ForEach(wl.categories) { c in categoryRow(c) }
        }
    }

    private func levelBar(_ label: String, _ ws: [ListWord]) -> some View {
        let known = store.listKnown(ws.map(markKey))
        let f = ws.isEmpty ? 0 : Double(known) / Double(ws.count)
        return HStack(spacing: 8) {
            Text(label).font(Typo.ui(11, .heavy)).frame(width: 24, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Ink.card
                    Ink.ink.frame(width: g.size.width * f)
                }
            }
            .frame(height: 8)
            .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 1))
            Text("\(known)/\(ws.count)").font(Typo.ui(11, .bold)).foregroundStyle(Ink.soft).frame(width: 64, alignment: .trailing)
        }
    }

    private func categoryRow(_ c: WordCategory) -> some View {
        let ws = wl.words(category: c.id)
        let known = store.listKnown(ws.map(markKey))
        let f = ws.isEmpty ? 0 : Double(known) / Double(ws.count)
        let open = state.expanded.contains(c.id)
        let on = state.selection == .category(c.id)
        return VStack(spacing: 0) {
            Button {
                if open && on { state.expanded.remove(c.id) } else { state.expanded.insert(c.id) }
                select(.category(c.id))
            } label: {
                HStack(spacing: 12) {
                    Text(c.glyph).font(Typo.mincho(18))
                        .frame(width: 36, height: 36)
                        .foregroundStyle(f >= 1 ? Ink.onInk : Ink.ink)
                        .background { ZStack { if f >= 1 { Ink.ink } else { Ink.paper; if f > 0 { Screentone(density: 0.2 + f * 0.5, spacing: 4) } } } }
                        .overlay(Rectangle().strokeBorder(Ink.ink, lineWidth: 1.5))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(c.ja).font(Typo.mincho(15))
                        Text("\(c.th) · \(c.en)").font(Typo.ui(11)).opacity(0.75).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Text("\(ws.count)").font(Typo.ui(12, .heavy)).opacity(0.7)
                    Image(systemName: open ? "chevron.down" : "chevron.right").font(.system(size: 10, weight: .bold)).opacity(0.6)
                }
                .padding(.horizontal, 10).frame(minHeight: 48)
                .foregroundStyle(on ? Ink.onInk : Ink.ink)
                .background(on ? Ink.ink : .clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)

            if open {
                ForEach(c.subs) { s in subRow(s) }
            }
        }
    }

    @ViewBuilder private func subRow(_ s: WordSub) -> some View {
        let ws = wl.words(sub: s.id)
        if !ws.isEmpty {
            let known = store.listKnown(ws.map(markKey))
            let on = state.selection == .sub(s.id)
            Button { select(.sub(s.id)) } label: {
                HStack(spacing: 8) {
                    Rectangle().fill(on ? Ink.akane : Ink.line).frame(width: 2, height: 22)
                    Text(s.ja).font(Typo.mincho(14))
                    Text(s.th).font(Typo.ui(11)).opacity(0.75).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(known == ws.count ? "済 \(ws.count)" : "\(known)/\(ws.count)")
                        .font(Typo.ui(11, .heavy))
                        .foregroundStyle(known == ws.count ? (on ? Color(hex: 0xE5605B) : Ink.akane) : (on ? Ink.line : Ink.soft))
                }
                .padding(.leading, 30).padding(.trailing, 12).frame(minHeight: 32)
                .foregroundStyle(on ? Ink.onInk : Ink.ink)
                .background(on ? Ink.ink : .clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
        }
    }

    // MARK: Detail

    private var titles: (kicker: String, title: String, sub: String) {
        switch state.selection {
        case .category(let id):
            let c = wl.categories.first { $0.id == id }
            return ("ALL SUBCATEGORIES", c?.ja ?? "", "\(c?.th ?? "") · \(c?.en ?? "")")
        case .sub(let id):
            let c = wl.category(of: id), s = wl.sub(id)
            return ("\(c?.en.uppercased() ?? "") · \(c?.ja ?? "")", s?.ja ?? "", "\(s?.th ?? "") · \(s?.en ?? "")")
        }
    }

    private var detail: some View {
        @Bindable var state = state
        let ws = words()
        let n5 = ws.filter { $0.level == .n5 }, n4 = ws.filter { $0.level == .n4 && !$0.isPlus }, plus = ws.filter(\.isPlus)
        let known = store.listKnown(ws.map(markKey))
        let t = titles
        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                PaneHeader(kicker: t.kicker, title: t.title,
                           subtitle: state.mode.isTyping
                               ? "\(t.sub)  ·  \(ws.count) words  ·  รู้แล้ว \(known)/\(ws.count)"
                               : "\(t.sub)  ·  \(ws.count) words (N5 \(n5.count) · N4 \(n4.count)\(plus.isEmpty ? "" : " · N4+ \(plus.count)"))  ·  รู้แล้ว \(known)/\(ws.count)") {
                    Button(action: randomPick) { Label("Random", systemImage: "die.face.5") }
                        .buttonStyle(InkButtonStyle(kind: .akaneOutline, height: 40)).frame(width: 120)
                }
                HStack(spacing: 10) {
                    Segmented(options: [(WordListState.Mode.list, "一覧 Read"), (.test, "意味 Type meaning"), (.recall, "日本語 Type Japanese")],
                              selection: Binding(get: { state.mode }, set: { m in
                                  state.mode = m
                                  if m.isTyping { DispatchQueue.main.async { focus = words().first?.id } }
                              }), height: 32)
                    Segmented(options: [(WordListState.LevelFilter.both, "N5+N4"), (.n5, "N5"), (.n4, "N4")], selection: $state.level, height: 32)
                    Spacer()
                    if state.mode != .recall {
                        ToggleSquare(text: "かな", on: $state.showKana, label: "Show hiragana")
                        ToggleSquare(text: "Romaji", on: $state.showRomaji, label: "Show romaji")
                    }
                    if state.mode.isTyping {
                        ToggleSquare(text: "สุ่ม Random", on: $state.randomOrder, label: "Random order")
                    }
                }
                if state.mode == .test {
                    Text("พิมพ์ความหมายเป็นภาษาไทยหรืออังกฤษ แล้วกด ⌘↩ ตรวจ · Return ไปคำถัดไป · Type each meaning in Thai or English, Return moves to the next word.")
                        .font(Typo.ui(12)).foregroundStyle(Ink.soft)
                } else if state.mode == .recall {
                    Text("อ่านความหมายแล้วพิมพ์คำภาษาญี่ปุ่น เป็นคันจิ ฮิรางานะ หรือโรมาจิก็ได้ แล้วกด ⌘↩ ตรวจ · Read the meaning and type the word — kanji, hiragana or romaji (taberu, たべる, 食べる).")
                        .font(Typo.ui(12)).foregroundStyle(Ink.soft)
                }
            }
            .padding(.horizontal, 32).padding(.top, 26).padding(.bottom, 14)

            header
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if ws.isEmpty {
                            Text("ไม่มีคำในหมวดนี้สำหรับระดับที่เลือก · No words at this level here.")
                                .font(Typo.ui(13)).foregroundStyle(Ink.soft).padding(30)
                        }
                        let numbered = Dictionary(uniqueKeysWithValues: ws.enumerated().map { ($1.id, $0 + 1) })
                        ForEach(sections(ws), id: \.id) { sec in
                            if !sec.tag.isEmpty { sectionHeader(sec) }
                            ForEach(sec.words, id: \.id) { w in
                                row(w, numbered[w.id] ?? 0, next: nextID(after: w, in: ws), tagLevel: sec.tagLevel)
                                    .id("\(w.id)#\(numbered[w.id] ?? 0)")
                            }
                        }
                    }
                    .padding(.horizontal, 32).padding(.bottom, 24)
                }
                .onChange(of: focus) { _, f in
                    if let f, let n = ws.firstIndex(where: { $0.id == f }) {
                        withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo("\(f)#\(n + 1)", anchor: .center) }
                    }
                }
            }
            if state.mode.isTyping { footer(ws) }
        }
    }

    private func nextID(after w: ListWord, in ws: [ListWord]) -> String? {
        guard let i = ws.firstIndex(of: w), i + 1 < ws.count else { return nil }
        return ws[i + 1].id
    }

    private var header: some View {
        Group {
            if state.mode == .recall {
                HStack(spacing: 14) {
                    Text("#").frame(width: 30, alignment: .trailing)
                    Text("ความหมาย · MEANING").frame(width: 360, alignment: .leading)
                    Text("คำตอบ · 漢字 / かな / ROMAJI").frame(maxWidth: .infinity, alignment: .leading)
                    Text("").frame(width: 30)
                }
            } else {
                columnsHeader
            }
        }
        .font(.system(size: 10, weight: .heavy)).tracking(1.4).foregroundStyle(Ink.soft)
        .padding(.horizontal, 32).padding(.vertical, 6)
        .overlay(alignment: .bottom) { Rectangle().fill(Ink.ink).frame(height: 2).padding(.horizontal, 32) }
    }

    private var columnsHeader: some View {
        HStack(spacing: 14) {
            Text("#").frame(width: 30, alignment: .trailing)
            Text("漢字").frame(width: 150, alignment: .leading)
            if state.showKana { Text("ひらがな").frame(width: 140, alignment: .leading) }
            if state.showRomaji { Text("ROMAJI").frame(width: 130, alignment: .leading) }
            Text(state.mode == .test ? "ความหมาย · YOUR ANSWER" : "ความหมาย · MEANING").frame(maxWidth: .infinity, alignment: .leading)
            Text("").frame(width: 30)
        }
    }

    private struct Section {
        let id: String
        let tag: String          // "N5" / "N4" chip, or the subcategory name
        let tagIsLevel: Bool
        let note: String
        let words: [ListWord]
        var tagLevel: Bool { !tagIsLevel }   // per-row level chips when sections are subcategories
    }

    /// A subcategory: N5 block then N4 block. A whole category: one block per subcategory.
    private func sections(_ ws: [ListWord]) -> [Section] {
        // Typing: one plain list — no level or subcategory headers to hint at the answer.
        if state.mode.isTyping { return [Section(id: "all", tag: "", tagIsLevel: true, note: "", words: ws)] }
        if case .category = state.selection {
            var out: [Section] = []
            for s in wl.categories.flatMap(\.subs) {
                let part = ws.filter { $0.meta.sub == s.id }
                guard !part.isEmpty else { continue }
                let n5 = part.filter { $0.level == .n5 }.count, plus = part.filter(\.isPlus).count
                out.append(Section(id: s.id, tag: s.ja, tagIsLevel: false,
                                   note: "\(s.th) · \(s.en) · \(part.count)  (N5 \(n5) · N4 \(part.count - n5 - plus)\(plus > 0 ? " · N4+ \(plus)" : ""))", words: part))
            }
            return out
        }
        let n5 = ws.filter { $0.level == .n5 }, n4 = ws.filter { $0.level == .n4 && !$0.isPlus }, plus = ws.filter(\.isPlus)
        return [Section(id: "n5", tag: "N5", tagIsLevel: true, note: "พื้นฐาน เรียนก่อน · learn first · \(n5.count)", words: n5),
                Section(id: "n4", tag: "N4", tagIsLevel: true, note: "ต่อยอด · builds on N5 · \(n4.count)", words: n4),
                Section(id: "plus", tag: "N4+", tagIsLevel: true, note: "ใช้บ่อยในชีวิตจริง เหนือ N4 นิดหน่อย · everyday words a step above N4 · \(plus.count)", words: plus)]
            .filter { !$0.words.isEmpty }
    }

    private func sectionHeader(_ sec: Section) -> some View {
        HStack(spacing: 10) {
            if sec.tagIsLevel {
                Text(sec.tag).font(Typo.ui(12, .heavy)).foregroundStyle(Ink.onInk)
                    .padding(.horizontal, 7).padding(.vertical, 2).background(sec.tag == "N5" ? Ink.ink : Ink.akane)
            } else {
                Text(sec.tag).font(Typo.mincho(17)).foregroundStyle(Ink.ink)
            }
            Text(sec.note).font(Typo.ui(12, .bold)).foregroundStyle(Ink.soft).lineLimit(1)
            Rectangle().fill(Ink.line).frame(height: 1)
        }
        .padding(.top, 16).padding(.bottom, 4)
    }

    // MARK: Row

    @ViewBuilder private func row(_ w: ListWord, _ n: Int, next: String?, tagLevel: Bool = false) -> some View {
        if state.mode == .recall { recallRow(w, n, next: next) } else { wordRow(w, n, next: next, tagLevel: tagLevel) }
    }

    /// Meaning → Japanese: the word stays hidden until the list is checked.
    @ViewBuilder private func recallRow(_ w: ListWord, _ n: Int, next: String?) -> some View {
        let result = state.results[w.id]
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text("\(n)").font(Typo.ui(12, .bold)).foregroundStyle(Ink.soft).frame(width: 30, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(w.th).font(Typo.ui(16, .semibold)).foregroundStyle(Ink.ink)
                Text(w.en).font(Typo.ui(12)).foregroundStyle(Ink.soft)
            }
            .frame(width: 360, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    TextField("漢字 / かな / romaji…", text: Binding(get: { state.answers[w.id] ?? "" }, set: { state.answers[w.id] = $0 }))
                        .textFieldStyle(.plain).font(Typo.mincho(18, bold: false))
                        .padding(.horizontal, 10).frame(height: 36)
                        .inkBox(Ink.card, border: result == nil ? (focus == w.id ? Ink.ink : Ink.line) : (result! ? Ink.ink : Ink.akane), width: focus == w.id || result != nil ? 2 : 1.5)
                        .focused($focus, equals: w.id)
                        .onSubmit { focus = next }
                        .disabled(state.checked)
                    if let result {
                        Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 18)).foregroundStyle(result ? Ink.ink : Ink.akane)
                            .accessibilityLabel(result ? "Correct" : "Wrong")
                    }
                }
                if let result {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(w.word).font(Typo.mincho(20)).foregroundStyle(result ? Ink.soft : Ink.ink)
                        if !w.kanaOnly { Text(w.kana).font(Typo.ui(14, .medium)).foregroundStyle(Ink.ink) }
                        Text(w.romaji).font(Typo.ui(13)).foregroundStyle(Ink.soft)
                        if !w.meta.also.isEmpty { Text("also " + w.meta.also.joined(separator: " · ")).font(Typo.ui(11)).foregroundStyle(Ink.soft).lineLimit(1) }
                        if !result {
                            Button("ฉันตอบถูก · I was right") {
                                state.results[w.id] = true
                                store.fixListMark(markKey(w))
                            }
                            .buttonStyle(.plain).font(Typo.ui(11, .heavy)).foregroundStyle(Ink.akane)
                            .lineLimit(1).fixedSize()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Group {
                if result != nil {
                    Button { Speech.shared.say(w.kana.replacingOccurrences(of: "〜", with: "")) } label: {
                        Image(systemName: "speaker.wave.2").foregroundStyle(Ink.soft)
                    }
                    .buttonStyle(.plain).accessibilityLabel("Play \(w.kana)")
                }
            }
            .frame(width: 30, alignment: .trailing)
        }
        .padding(.vertical, 9)
        .background(result == false ? Ink.akane.opacity(0.06) : .clear)
        .overlay(alignment: .bottom) { Rectangle().fill(Ink.line).frame(height: 1) }
    }

    @ViewBuilder private func wordRow(_ w: ListWord, _ n: Int, next: String?, tagLevel: Bool) -> some View {
        let result = state.results[w.id]
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text("\(n)").font(Typo.ui(12, .bold)).foregroundStyle(Ink.soft).frame(width: 30, alignment: .trailing)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(w.word).font(Typo.mincho(24)).lineLimit(1).minimumScaleFactor(0.5)
                    if tagLevel && w.level == .n4 {
                        Text(w.vocab.levelTag).font(.system(size: 9, weight: .heavy)).foregroundStyle(Ink.akane)
                            .padding(.horizontal, 3).overlay(Rectangle().strokeBorder(Ink.akane, lineWidth: 1))
                    }
                }
                if !w.meta.also.isEmpty {
                    Text("also " + w.meta.also.joined(separator: " · ")).font(Typo.ui(10)).foregroundStyle(Ink.soft).lineLimit(1)
                }
            }
            .frame(width: 150, alignment: .leading)
            .textSelection(.enabled)
            if state.showKana {
                Text(w.kanaOnly ? "—" : w.kana).font(Typo.ui(16, .medium))
                    .foregroundStyle(w.kanaOnly ? Ink.line : Ink.ink)
                    .lineLimit(1).minimumScaleFactor(0.6).frame(width: 140, alignment: .leading)
            }
            if state.showRomaji {
                Text(w.romaji).font(Typo.ui(14)).foregroundStyle(Ink.soft).lineLimit(1).frame(width: 130, alignment: .leading)
            }
            Group {
                if state.mode == .list { meaning(w) } else { answerField(w, result: result, next: next) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 6) {
                if state.mode == .list, let last = store.listMarks[w.id]?.last {
                    Image(systemName: last ? "checkmark" : "xmark").font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(last ? Ink.ink : Ink.akane)
                }
                Button { Speech.shared.say(w.kana.replacingOccurrences(of: "〜", with: "")) } label: {
                    Image(systemName: "speaker.wave.2").foregroundStyle(Ink.soft)
                }
                .buttonStyle(.plain).accessibilityLabel("Play \(w.kana)")
            }
            .frame(width: 30, alignment: .trailing)
        }
        .padding(.vertical, 9)
        .background(result == false ? Ink.akane.opacity(0.06) : .clear)
        .overlay(alignment: .bottom) { Rectangle().fill(Ink.line).frame(height: 1) }
    }

    private func meaning(_ w: ListWord) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(w.th).font(Typo.ui(15)).foregroundStyle(Ink.ink)
            if store.settings.showEnglish { Text(w.en).font(Typo.ui(12)).foregroundStyle(Ink.soft) }
        }
        .textSelection(.enabled)
    }

    @ViewBuilder private func answerField(_ w: ListWord, result: Bool?, next: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                TextField("ความหมาย… / meaning…", text: Binding(get: { state.answers[w.id] ?? "" }, set: { state.answers[w.id] = $0 }))
                    .textFieldStyle(.plain).font(Typo.ui(15))
                    .padding(.horizontal, 10).frame(height: 34)
                    .inkBox(Ink.card, border: result == nil ? (focus == w.id ? Ink.ink : Ink.line) : (result! ? Ink.ink : Ink.akane), width: focus == w.id || result != nil ? 2 : 1.5)
                    .focused($focus, equals: w.id)
                    .onSubmit { focus = next }
                    .disabled(state.checked)
                if let result {
                    Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 18)).foregroundStyle(result ? Ink.ink : Ink.akane)
                        .accessibilityLabel(result ? "Correct" : "Wrong")
                }
            }
            if let result {
                HStack(spacing: 8) {
                    Text(w.th).font(Typo.ui(13, .semibold)).foregroundStyle(result ? Ink.soft : Ink.ink)
                    Text("· \(w.en)").font(Typo.ui(12)).foregroundStyle(Ink.soft).lineLimit(1).layoutPriority(-1)
                    if !result {
                        Button("ฉันตอบถูก · I was right") {
                            state.results[w.id] = true
                            store.fixListMark(markKey(w))
                        }
                        .buttonStyle(.plain).font(Typo.ui(11, .heavy)).foregroundStyle(Ink.akane)
                        .lineLimit(1).fixedSize()
                    }
                }
            }
        }
    }

    // MARK: Footer

    @ViewBuilder private func footer(_ ws: [ListWord]) -> some View {
        let answered = ws.filter { !(state.answers[$0.id] ?? "").trimmingCharacters(in: .whitespaces).isEmpty }.count
        let right = ws.filter { state.results[$0.id] == true }.count
        let wrong = ws.filter { state.results[$0.id] == false }
        HStack(spacing: 14) {
            if state.checked {
                if right == ws.count && !ws.isEmpty { StampBadge(text: "済", size: 40) }
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(right) / \(ws.count) ถูก").font(Typo.mincho(22))
                    Text(right == ws.count ? "จำได้ครบทั้งหมวด · every word right" : "ผิด \(wrong.count) คำ · ทบทวนแล้วลองใหม่").font(Typo.ui(12)).foregroundStyle(Ink.soft)
                        .lineLimit(1).fixedSize()
                }
                Spacer()
                if !wrong.isEmpty {
                    Button("ลองเฉพาะที่ผิด · Retry \(wrong.count) wrong") {
                        state.restart(keepOnly: Set(wrong.map(\.id)))
                        prepareOrder()
                        DispatchQueue.main.async { focus = words().first?.id }
                    }
                    .buttonStyle(InkButtonStyle(kind: .outline, height: 44)).frame(width: 250)
                }
                Button("อีกครั้ง · Again") {
                    state.restart(); prepareOrder()
                    DispatchQueue.main.async { focus = words().first?.id }
                }
                .buttonStyle(InkButtonStyle(kind: .outline, height: 44)).frame(width: 140)
                Button(action: randomPick) { Text("หมวดถัดไป · Next random →") }
                    .buttonStyle(InkButtonStyle(kind: .akane, height: 44)).frame(width: 220)
            } else {
                Text("ตอบแล้ว \(answered) / \(ws.count)").font(Typo.ui(13, .bold)).foregroundStyle(Ink.soft)
                Text("ช่องว่างนับเป็นไม่รู้ · blanks count as “don't know”").font(Typo.ui(11)).foregroundStyle(Ink.soft)
                Spacer()
                Button { check(ws) } label: {
                    HStack { Text("ตรวจคำตอบ · Check"); Kbd("⌘↩", light: true) }
                }
                .buttonStyle(InkButtonStyle(kind: .akane, height: 44)).frame(width: 220)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(ws.isEmpty)
            }
        }
        .padding(.horizontal, 32).padding(.vertical, 12)
        .background(Ink.paper)
        .overlay(alignment: .top) { Rectangle().fill(Ink.ink).frame(height: 2) }
    }

    private func check(_ ws: [ListWord]) {
        focus = nil
        for w in ws {
            let typed = state.answers[w.id] ?? ""
            var ok = state.mode == .recall ? JapaneseCheck.isCorrect(typed, w) : MeaningCheck.isCorrect(typed, w)
            if !ok, state.mode == .recall {
                // Two words in the list can share a meaning (美味しい / うまい = อร่อย): either one is right.
                let mine = Set(MeaningCheck.answers(w))
                ok = ws.contains { o in o.id != w.id && !mine.isDisjoint(with: MeaningCheck.answers(o)) && JapaneseCheck.isCorrect(typed, o) }
            }
            state.results[w.id] = ok
            store.recordList(markKey(w), correct: ok)
        }
        state.checked = true
        let right = state.results.values.filter { $0 }.count
        right == ws.count ? Haptic.success() : Haptic.warning()
    }
}
