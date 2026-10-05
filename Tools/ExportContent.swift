import Foundation

struct VOut: Codable { let id, level, kanji, kana, romaji, pos, th, exJA, exKana, exRomaji, exEN, exTH: String }
struct KEx: Codable { let w, r, m: String }
struct KOut: Codable { let id, level, th, en, on, kun, cat, reading, romaji: String; let strokes: Int; let examples: [KEx] }
struct GEx: Codable { let ja, kana, th, en, romaji: String }
struct GQ: Codable { let prompt, kana, captionTH, captionEN, explainTH, explainEN: String; let options: [String]; let answer: Int; let accepted: [String] }
struct GOut: Codable { let key, level, pattern, th, en, structure, explainTH, explainEN, cat, formationTH, formationEN, mistakesTH, mistakesEN: String; let examples: [GEx]; let exercises: [GQ]; let related: [String] }
struct All: Codable { let vocab: [VOut]; let kanji: [KOut]; let grammar: [GOut] }

func rom(_ ja: String, _ kana: String) -> String { RomajiService.sentenceToRomaji(ja.isEmpty ? kana : ja, kanaSentence: kana) }

var vocab: [VOut] = []
for lvl in JLPTLevel.allCases {
  for v in VocabJPData.forLevel(lvl) {
    vocab.append(VOut(id: v.id, level: lvl.rawValue, kanji: v.kanji, kana: v.kana, romaji: v.romaji, pos: v.pos, th: v.thai, exJA: v.exJA, exKana: v.exKana, exRomaji: v.exRomaji.isEmpty ? rom(v.exJA, v.exKana) : v.exRomaji, exEN: v.exEN, exTH: v.exTH))
  }
}
var kanji: [KOut] = []
for lvl in JLPTLevel.allCases {
  for k in KanjiData.forLevel(lvl) {
    kanji.append(KOut(id: k.char, level: lvl.rawValue, th: k.thai, en: k.english, on: k.on, kun: k.kun, cat: "\(k.category)", reading: k.primaryReading, romaji: rom(k.primaryReading, k.primaryReading), strokes: k.strokes, examples: k.examples.map { KEx(w: $0.word, r: $0.reading, m: $0.meaning) }))
  }
}
var grammar: [GOut] = []
for lvl in JLPTLevel.allCases {
  for raw in GrammarData.forLevel(lvl) {
    let p = GrammarEnrichment.apply(raw)
    let exs = p.allExamples.map { GEx(ja: $0.ja, kana: $0.kana, th: $0.th, en: $0.en, romaji: $0.romaji) }
    let qs = p.exercises.map { e -> GQ in
      let pl = e.placed
      return GQ(prompt: e.promptJA, kana: e.kana, captionTH: e.captionTH, captionEN: e.captionEN, explainTH: e.explainTH, explainEN: e.explainEN, options: pl.opts, answer: pl.ans, accepted: e.accepted)
    }
    grammar.append(GOut(key: p.key, level: lvl.rawValue, pattern: p.pattern, th: p.meaningTH, en: p.meaningEN, structure: p.structure, explainTH: p.explainTH, explainEN: p.explainEN, cat: "\(p.category)", formationTH: p.formationTH, formationEN: p.formationEN, mistakesTH: p.mistakesTH, mistakesEN: p.mistakesEN, examples: exs, exercises: qs, related: p.related))
  }
}
let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
let data = try! enc.encode(All(vocab: vocab, kanji: kanji, grammar: grammar))
try! data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("vocab", vocab.count, "kanji", kanji.count, "grammar", grammar.count, "exercises", grammar.reduce(0) { $0 + $1.exercises.count })
