# Fuda textbook lessons — authoring guide & file format

One JSON file per lesson: `FudaMac/Resources/textbook-L01.json` … `textbook-L32.json`
(N5 = lessons 1–14, N4 = lessons 15–32; lesson 0 is the kana chart and has no file).

The app shows each lesson like a textbook + video course (in the spirit of
Minna no Nihongo's structure, but **all text is original** — never copy sentences,
dialogues or explanations from Minna no Nihongo, Genki or any other book).

**Teaching language: Thai.** The learner is Thai. Every explanation, subtitle,
instruction and translation is natural, friendly, clear Thai (ภาษาไทยที่อ่านง่าย
เหมือนครูอธิบาย). English appears only in optional `en` fields.

## Quality bar (the reason this exists)

The old lessons were "a formula + two examples". That is NOT enough. Each grammar
point must be *taught*: what it means, why it works that way, how it differs from
similar things, the common mistakes Thai speakers make, and many natural examples.
Write like a patient teacher sitting next to the student. Prefer 3 short clear
sentences over 1 dense one. Explain every new Japanese word inside explanations.

## Cast (use the same people in every lesson)

| Name | Who |
|---|---|
| タム (Tam) | Thai student, 22, studies at a Japanese language school in Tokyo — the learner's stand-in |
| 田中ゆき (Tanaka Yuki) | Japanese office worker, Tam's friend and neighbour |
| 山田先生 (Yamada-sensei) | Tam's Japanese teacher |
| リン (Lin) | Chinese classmate |
| ジョン (John) | American classmate |
| 鈴木さん (Suzuki-san) | shop/station/restaurant staff, landlord etc. as needed |

## Language rules (checked by `Tools/textbook/validate.py`)

1. Every Japanese item has `ja` (normal writing with kanji) and `kana` (the full
   reading in hiragana; katakana words may stay katakana). `kana` must be `ja`
   with each kanji replaced by its reading — same punctuation, **no spaces**,
   same particles (write は/へ/を as written, not わ/え/お).
2. Use only vocabulary and grammar the learner has met: the lesson's own word
   list, earlier lessons' words, and the lesson's grammar + earlier grammar.
   A few extra words are OK if you gloss them in Thai.
3. Use kanji that a learner at that level would see (N5 kanji in N5 lessons);
   otherwise write the word in kana.
4. Polite です/ます style everywhere in N5 except where the lesson teaches plain form.

## File format

```jsonc
{
  "n": 1,
  "titleJA": "はじめまして",
  "titleTH": "ประโยคแรก: แนะนำตัว",
  "goalsTH": ["บอกชื่อและอาชีพของตัวเองได้", "..."],          // 3–5 can-do goals

  // 1 · 文型 — the lesson's key patterns (3–5)
  "patterns": [
    { "ja": "私はタムです。", "kana": "わたしはたむです。", "th": "ฉันชื่อตัม",
      "noteTH": "Nは Nです = N คือ N ใช้แนะนำตัว บอกอาชีพ ฯลฯ" }
  ],

  // 1 · 例文 — question/answer pairs (8–12)
  "examples": [
    { "q": { "ja": "…", "kana": "…", "th": "…" },
      "a": { "ja": "…", "kana": "…", "th": "…" } }
  ],

  // 4 · 会話 — the lesson's main conversation (10–16 lines), uses the cast
  "conversation": {
    "titleJA": "はじめまして", "titleTH": "ยินดีที่ได้รู้จัก",
    "sceneTH": "วันแรกที่โรงเรียนภาษา ตัมเจอคุณทานากะ…",
    "lines": [ { "speaker": "タム", "ja": "…", "kana": "…", "th": "…" } ]
  },

  // 3 · 文法解説 — one section per grammar point, deep Thai explanation
  "grammar": [
    { "key": "n5.desu",                 // grammar key from the course (optional)
      // "keys": ["n5.p.ne", "n5.p.yo"]  // instead of key: one section may cover several SMALL related points
      "titleJA": "Nは Nです", "titleTH": "…คือ…",
      "blocks": [
        { "t": "p",    "th": "paragraph of explanation" },
        { "t": "ex",   "ja": "…", "kana": "…", "th": "…" },
        { "t": "table","rows": [["header","header"],["cell","cell"]] },
        { "t": "tip",  "th": "helpful hint" },
        { "t": "warn", "th": "common mistake for Thai learners" },
        { "t": "compare", "th": "what the difference is",
          "left":  { "ja": "…", "kana": "…", "th": "…" },
          "right": { "ja": "…", "kana": "…", "th": "…" } }
      ] }
  ],
  // each grammar section: ≥ 3 "p", ≥ 4 "ex", and at least one "warn" or "compare"
  // Every grammar key of the lesson must be covered by some section (key or keys).

  // 2 · ビデオ — the video lesson: chapters of beats. Each beat = one animated
  // scene + one Thai subtitle. Tokens keep their `id` across beats, so the same
  // id in the next beat MOVES (that is the animation). New ids pop in; missing
  // ids fade out. Think "Keynote magic move" lesson, 20–40 beats in total.
  "video": [
    { "chapterTH": "1. Nは Nです",
      "beats": [
        { "th": "subtitle (Thai, 1–2 short sentences)",
          "say": "わたしはたむです",         // optional: Japanese spoken aloud (kana)
          "kicker": "optional small label",
          "rows": [                          // stage rows, top to bottom
            [ { "id": "s", "text": "私", "k": "plain", "s": "huge", "r": "わたし" },
              { "id": "wa", "text": "は", "k": "key", "s": "huge" },
              { "id": "n", "text": "タム", "k": "plain", "s": "huge" },
              { "id": "desu", "text": "です", "k": "ink", "s": "huge" } ]
          ],
          "timeline": null                   // optional, see below
        }
      ] }
  ],

  // 6 · 練習A — substitution tables (2–4). The frame shows the slots; each row
  // fills them. `slots` are the substrings of `ja` that change.
  "drillA": [
    { "titleTH": "แนะนำตัว", "frame": "＿＿は ＿＿です。",
      "rows": [ { "ja": "私は学生です。", "kana": "わたしはがくせいです。", "th": "ฉันเป็นนักเรียน", "slots": ["私", "学生"] } ] }
  ],

  // 6 · 練習B — transformation drills the learner TYPES (2–4 sets × 5–8 items).
  // The first item of each set is shown as the worked example.
  "drillB": [
    { "instructionTH": "เปลี่ยนเป็นประโยคปฏิเสธ",
      "items": [ { "prompt": { "ja": "学生です。", "kana": "がくせいです。", "th": "…" },
                   "answer": { "ja": "学生じゃありません。", "kana": "がくせいじゃありません。" },
                   "accept": ["学生ではありません。"] } ] }
  ],

  // 6 · 練習C — mini conversations with swappable parts (2–3). {0}, {1} … in
  // ja/kana/th are filled from choices[0], choices[1] … Every choices list has
  // the same number of options (3); variant i uses option i of EVERY list, so
  // the options line up (choices[0][1] goes with choices[1][1]).
  "drillC": [
    { "situationTH": "ถามอาชีพ",
      "lines": [ { "speaker": "A", "ja": "{0}さんは先生ですか。", "kana": "{0}さんはせんせいですか。", "th": "คุณ{0}เป็นครูไหม" },
                 { "speaker": "B", "ja": "いいえ、{1}です。", "kana": "いいえ、{1}です。", "th": "ไม่ใช่ เป็น{1}" } ],
      "choices": [ [ { "ja": "田中", "kana": "たなか", "th": "ทานากะ" }, … ],
                   [ { "ja": "会社員", "kana": "かいしゃいん", "th": "พนักงานบริษัท" }, … ] ] }
  ],

  // 7 · 問題 — the lesson check (10–15 items, mixed types)
  "quiz": [
    { "type": "choice", "questionTH": "เลือกคำที่ถูก", "ja": "私（　）タムです。", "kana": "わたし（　）たむです。",
      "options": ["は", "を", "に"], "answer": 0, "explainTH": "…" },
    { "type": "listen", "questionTH": "ฟังแล้วเลือกความหมาย", "kana": "がくせいですか。",
      "options": ["เป็นนักเรียนไหม", "เป็นครูไหม", "เป็นหมอไหม"], "answer": 0, "explainTH": "…" },
    { "type": "order", "questionTH": "เรียงประโยค: ฉันไม่ใช่ครู",
      "tiles": ["私は", "先生", "じゃありません。"], "kana": "わたしはせんせいじゃありません。", "explainTH": "…" }
  ]
}
```

### Tokens (video stage)

| field | values |
|---|---|
| `id` | stable id — reuse it in the next beat to make the token move |
| `text` | what's shown |
| `k` kind | `plain` · `key` (red, the thing being taught) · `ink` (black block) · `ghost` (dashed, empty slot / options) · `op` (+ → = / arrows) · `strike` (crossed out, wrong) · `label` (small English/Thai tag) · `note` (a card of Thai text) |
| `s` size | `huge` · `big` · `mid` · `small` |
| `r` | reading in hiragana — **required whenever `text` contains kanji** |
| `c` | small caption under the token (e.g. "topic", "หัวเรื่อง") |

Timelines go on the beat (drawn above the token rows):
`"timeline": { "bar": [0.35, 0.85], "solid": false, "event": 0.3, "eventLabel": "結婚した", "ticks": [0.2,0.4], "caption": "…" }`
(fractions of the axis; NOW is at 0.6). Use only when time is the point (ている, past, まえに/あとで …).

Good video technique:
- Build sentences piece by piece across beats (add one token per beat).
- Show a WRONG version with `strike`, then the right one.
- Swap one slot (same ids for the frame, new id for the swapped word) to show a pattern.
- Put the Thai meaning as a `label` row under the sentence.
- End each chapter with a recap beat.

## Workflow
1. Write `FudaMac/Resources/textbook-LNN.json`.
2. Run `python3 Tools/textbook/validate.py NN` — fix every ERROR, read every WARN.
