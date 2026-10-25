# Fuda exams — file format and rules for ORIGINAL practice exams

Real past exams come from Tone (`build_exams.py` → `FudaMac/Resources/Exams/exams-real.json`).
Original exams (written for Fuda, never copied from any real or published test) go in
`FudaMac/Resources/Exams/exams-original-n5.json` and `exams-original-n4.json`:

```json
{ "sets": [ { ...set... }, { ...set... } ] }
```

Check with `python3 Tools/exams/validate_exams.py`.

## The real test format (since 2020) — an original exam must match it exactly

### N5 — 3 sections
| Section | Time | もんだい | Questions |
|---|---|---|---|
| 言語知識（文字・語彙）`vocab` | 20 min | 1 漢字読み 7 · 2 表記 5 · 3 文脈規定 6 · 4 言い換え類義 3 | 21 |
| 言語知識（文法）・読解 `grammar` | 40 min | 1 文の文法１ 9 · 2 文の文法２ 4 · 3 文章の文法 4 · 4 内容理解（短文）2 · 5 内容理解（中文）2 · 6 情報検索 1 | 22 |
| 聴解 `listening` | 30 min | 1 課題理解 7 · 2 ポイント理解 6 · 3 発話表現 5 · 4 即時応答 6 | 24 |

### N4 — 3 sections
| Section | Time | もんだい | Questions |
|---|---|---|---|
| 言語知識（文字・語彙）`vocab` | 25 min | 1 漢字読み 7 · 2 表記 5 · 3 文脈規定 8 · 4 言い換え類義 4 · 5 用法 4 | 28 |
| 言語知識（文法）・読解 `grammar` | 55 min | 1 文の文法１ 13 · 2 文の文法２ 4 · 3 文章の文法 4 · 4 内容理解（短文）3 · 5 内容理解（中文）3 · 6 情報検索 2 | 29 |
| 聴解 `listening` | 35 min | 1 課題理解 8 · 2 ポイント理解 7 · 3 発話表現 5 · 4 即時応答 8 | 28 |

Question numbers (`no`) run from 1 through each section, like the real booklet.

## JSON

```jsonc
{
  "id": "n5.orig1", "level": "n5", "kind": "original", "format": "new", "order": 9,
  "label": "ข้อสอบที่แต่งขึ้น ชุด 1", "labelEN": "Original 1",
  "titleJA": "JLPT N5 Original 1", "noteTH": "ข้อสอบที่ Fuda แต่งขึ้นตามรูปแบบจริงทุกพาร์ต …",
  "source": "Fuda original", "missing": [],
  "parts": [
    { "id": "n5o1.p1", "section": "vocab", "titleJA": "言語知識（文字・語彙）", "titleTH": "คำศัพท์และตัวอักษร", "minutes": 20,
      "blocks": [
        { "id": "n5o1.p1.m1", "nameJA": "もんだい1　漢字読み", "nameTH": "อ่านคันจิ", "nameEN": "Kanji reading",
          "instructionJA": "（the official-style instruction in Japanese）",
          "passageJA": "", "passageKana": "", "audio": "",
          "questions": [
            { "id": "n5o1.v1", "no": 1, "type": "vocab", "img": "",
              "prompt": "らいしゅう ▲山▲に のぼります。",
              "options": ["やま", "かわ", "うみ", "そら"], "answer": 0,
              "explainTH": "山 อ่านว่า やま = ภูเขา …", "explainEN": "",
              "optionNotes": ["✓ やま = ภูเขา", "かわ = 川 แม่น้ำ", "…", "…"],
              "grammarKeys": [], "script": [], "spokenOptions": [], "questionLine": "" } ] } ] } ]
}
```

### Marks inside `prompt`
- `▲word▲` — the underlined word being tested (漢字読み, 表記, 言い換え, 用法).
- `（　）` — the blank (文脈規定, 文の文法１, 文章の文法 uses `（14）` style numbers inside the passage).
- 文の文法２ (★ ordering), like the real test: blanks `＿＿` with one `＿★＿`, then a new line with the
  four numbered pieces: `この ＿＿ ＿★＿ ＿＿ ＿＿ とき べんりです。\n（1 りょこうの／2 じょうぶだから／3 かばんは／4 かるくて）`;
  `options` are the four pieces in that order and `answer` is the piece that goes in ★. Start `explainTH`
  with the full correct sentence. (`convert_star.py` turns the older full-order style into this.)
- Reading blocks put the text in the block's `passageJA` (and `passageKana` = the same text all in kana, optional).
  情報検索 passages are notices / schedules / price lists written as plain text with line breaks.

### Listening (no recorded audio: the app reads the `script` aloud with two voices)
- `script`: lines in order, each starting with the speaker: `"Ｆ：…"` (woman), `"Ｍ：…"` (man), or no prefix for the narrator.
  First line = the narrator's setup + question, last line = the question again (like the real test).
- `questionLine`: the question asked.
- 課題理解 / ポイント理解: `options` are the four printed choices **as text** (no pictures), `spokenOptions` = [].
- 発話表現: `prompt` = the situation (e.g. 先生の部屋に入ります。何と言いますか。), `options` = ["1","2","3"],
  `spokenOptions` = the three utterances (spoken, not printed).
- 即時応答: `prompt` = the first speaker's line, `script` = [that line], `options` = ["1","2","3"], `spokenOptions` = three replies.
- `type` is `"listening"`; every other question uses `"vocab"`, `"grammar"` or `"reading"`.

## Writing rules
1. **Original only.** Never copy or lightly edit questions, passages or scripts from any real JLPT test, the
   official workbooks, Tone/Fuda's real exams or any published book. Write fresh sentences.
2. **Level-true.** Only N5 words/kanji in N5 exams (N5 + N4 in N4 exams). Mirror the real difficulty: distractors
   must be plausible (similar kanji, similar sound, same word class), exactly one answer correct.
3. Kana spacing like the real N5/N4 booklets (words separated by spaces in vocab/grammar items is fine).
4. `explainTH`: clear Thai explanation of why the answer is right; `optionNotes`: one Thai note per option
   (mark the right one with ✓).
5. Vary the answer position evenly (roughly the same number of 0/1/2/3).
