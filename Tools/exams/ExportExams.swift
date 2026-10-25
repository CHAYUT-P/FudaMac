import Foundation
struct QOut: Codable { let id: String; let no: Int; let img: String; let prompt: String; let options: [String]; let answer: Int; let explainTH: String; let explainEN: String; let script: [String]; let spokenOptions: [String]; let questionLine: String; let optionNotes: [String]; let grammarKeys: [String] }
struct BOut: Codable { let id, nameJA, nameTH, nameEN, instructionJA, passageJA, passageKana, audio: String; let questions: [QOut] }
struct POut: Codable { let id, titleJA, titleTH, titleEN: String; let minutes: Int; let blocks: [BOut] }
struct SOut: Codable { let id, level, titleJA, titleTH, titleEN, source, subtitle, noteTH: String; let parts: [POut] }
var out: [SOut] = []
for l in JLPTLevel.allCases {
  for s in ExamData.sets(for: l) {
    out.append(SOut(id: s.id, level: l.rawValue, titleJA: s.titleJA, titleTH: s.titleTH, titleEN: s.titleEN, source: s.source, subtitle: s.subtitle, noteTH: s.noteTH,
      parts: s.parts.map { p in POut(id: p.id, titleJA: p.titleJA, titleTH: p.titleTH, titleEN: p.titleEN, minutes: p.minutes,
        blocks: p.blocks.map { b in BOut(id: b.id, nameJA: b.nameJA, nameTH: b.nameTH, nameEN: b.nameEN, instructionJA: b.instructionJA, passageJA: b.passageJA, passageKana: b.passageKana, audio: b.audio,
          questions: b.questions.map { q in QOut(id: q.id, no: q.no, img: q.img, prompt: q.promptJA, options: q.options, answer: q.answer, explainTH: q.explainTH, explainEN: q.explainEN, script: q.script, spokenOptions: q.spokenOpts, questionLine: q.questionLine, optionNotes: q.optionNotes, grammarKeys: q.grammarKeys) }) }) }))
  }
}
let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
FileManager.default.createFile(atPath: CommandLine.arguments[1], contents: try! enc.encode(out))
