import AppKit

// 語 Word list → clipboard, ready to paste into Gemini (or any chat AI):
// the words of the list on screen plus a short Thai prompt asking for
// sentences, a story, or sentence-making practice.

enum WordExport: String, CaseIterable, Identifiable {
    case sentences, story, practice, list
    var id: String { rawValue }

    var title: String {
        switch self {
        case .sentences: "ประโยคตัวอย่าง คำละประโยค"
        case .story: "เรื่องสั้น / บทสนทนา ใช้ทุกคำ"
        case .practice: "ฝึกแต่งประโยคเอง ให้ AI ตรวจ"
        case .list: "รายการคำอย่างเดียว"
        }
    }
    var subtitle: String {
        switch self {
        case .sentences: "One natural sentence per word, with reading, romaji and Thai"
        case .story: "A short story or dialogue that uses the words together"
        case .practice: "Gemini gives you a word and a situation, you write the sentence, it corrects you"
        case .list: "Just the words: kanji, kana, romaji, meaning"
        }
    }
    var glyph: String {
        switch self { case .sentences: "文"; case .story: "話"; case .practice: "練"; case .list: "語" }
    }

    /// The text to paste: prompt (unless .list), then the numbered words.
    func text(title: String, words: [ListWord]) -> String {
        let lines = words.enumerated().map { i, w in
            let reading = w.kanaOnly ? w.romaji : "\(w.kana) / \(w.romaji)"
            return "\(i + 1). \(w.word)（\(reading)）— \(w.th) · \(w.en)"
        }
        let list = "คำศัพท์: \(title) · \(words.count) คำ\n" + lines.joined(separator: "\n")
        let me = "ฉันเป็นคนไทยที่กำลังเรียนภาษาญี่ปุ่นระดับ N5–N4 เพื่อพูดได้จริง และจำคำศัพท์ได้ดีที่สุดเมื่อเห็นในประโยค"
        switch self {
        case .list:
            return list
        case .sentences:
            return """
            \(me)
            ช่วยแต่งประโยคภาษาญี่ปุ่นสั้นๆ ที่เป็นธรรมชาติ คำละ 1 ประโยค สำหรับคำศัพท์ด้านล่าง
            - ใช้ไวยากรณ์และคำศัพท์ระดับ N5–N4 เป็นหลัก
            - เป็นสถานการณ์ในชีวิตจริงที่ญี่ปุ่น (ร้านค้า ที่ทำงาน กับเพื่อน ฯลฯ)
            - แต่ละข้อเขียน: ประโยคญี่ปุ่น / คำอ่านฮิรางานะ / โรมาจิ / คำแปลไทย
            - ถ้าพูดกับเพื่อนกับพูดแบบสุภาพไม่เหมือนกัน ให้บอกทั้งสองแบบ
            - ตอนจบ ให้ทวน 3 คำที่จำสลับกันง่าย พร้อมเทคนิคจำสั้นๆ

            \(list)
            """
        case .story:
            return """
            \(me)
            ช่วยแต่งเรื่องสั้นหรือบทสนทนาสั้นๆ (ประมาณ 8–12 ประโยค) ที่ใช้คำศัพท์ด้านล่างให้ได้มากที่สุด
            - ใช้ไวยากรณ์ระดับ N5–N4 เป็นเรื่องในชีวิตประจำวันที่ญี่ปุ่น
            - ทำตัวหนาคำศัพท์จากรายการทุกครั้งที่ใช้
            - เขียนทีละประโยค: ประโยคญี่ปุ่น / คำอ่านฮิรางานะ / โรมาจิ / คำแปลไทย
            - ตอนจบ บอกว่าคำไหนในรายการที่ยังไม่ได้ใช้ แล้วแต่งประโยคเพิ่มให้คำเหล่านั้น

            \(list)
            """
        case .practice:
            return """
            \(me)
            ช่วยเป็นครูฝึกแต่งประโยคให้หน่อย ใช้คำศัพท์ด้านล่าง:
            - ให้โจทย์ทีละคำ: บอกคำศัพท์ และสถานการณ์สั้นๆ เป็นภาษาไทย (เช่น "บอกเพื่อนว่า…")
            - รอให้ฉันพิมพ์ประโยคภาษาญี่ปุ่นเอง (อาจพิมพ์เป็นโรมาจิ)
            - ตรวจให้: ถูกหรือผิด อธิบายจุดผิดเป็นภาษาไทย แล้วให้แบบที่คนญี่ปุ่นพูดจริง ทั้งแบบเพื่อนและแบบสุภาพ
            - แล้วค่อยไปคำถัดไป ทุก 5 คำ ให้สรุปจุดที่ฉันพลาดบ่อย
            เริ่มจากคำแรกเลย

            \(list)
            """
        }
    }

    static let geminiURL = URL(string: "https://gemini.google.com/app")!

    static func copy(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
}
