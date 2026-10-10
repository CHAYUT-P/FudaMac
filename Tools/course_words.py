#!/usr/bin/env python3
"""Spreads every N5 + N4 word over the one course (FudaMac/Resources/course.json).

The course is a single path, lesson 0 → 32: grammar in teaching order (N4 grammar
builds on N5 grammar), words mixed by topic. Every word in the word list is taught
in exactly one lesson:

  1. Lessons 1–14 keep the words their textbook chapters use (proto n5_course.json),
     and words in Tools/wordlist/course_anchor.json go to their pinned lesson
     (greetings early; textbook words where the textbook teaches them).
  2. Every other word goes to a lesson with room (about 44 words each):
     a lesson whose grammar examples use it, else a lesson already teaching that
     topic, else the lightest lesson. Easier (N5) words go as early as they fit;
     N4 words start from lesson 6, once basic sentences are in place, and the
     everyday N4+ words (a step above N4) from lesson 15.

Run after Tools/build_course.py and Tools/wordlist/fix_vocab.py:
  python3 Tools/course_words.py
"""
import json, math, pathlib, collections

ROOT = pathlib.Path(__file__).resolve().parent.parent
P_COURSE = ROOT / "FudaMac/Resources/course.json"
content = json.loads((ROOT / "Fuda/Resources/content.json").read_text())
extra = json.loads((ROOT / "Fuda/Resources/vocab-extra.json").read_text())
wordlist = json.loads((ROOT / "Fuda/Resources/wordlist.json").read_text())
renames = json.loads((ROOT / "Fuda/Resources/vocab-renames.json").read_text())
proto = json.loads(pathlib.Path("/Users/chayut/project/mobile/proto/n5_course.json").read_text())
course = json.loads(P_COURSE.read_text())

SEC = {'คำศัพท์': 'Words', 'คำถาม & คำชี้': 'Questions & pointing', 'ของใช้': 'Everyday things',
       'อาหาร & เครื่องดื่ม': 'Food & drink', 'สถานที่': 'Places', 'ตำแหน่ง & ทิศทาง': 'Position & direction',
       'ภายในบ้าน': 'Around the house', 'กริยา & กิจกรรมประจำวัน': 'Verbs & daily routine',
       'เวลา & ความถี่': 'Time & frequency', 'คำคุณศัพท์ & สภาพ': 'Adjectives & states',
       'ปฏิทิน & วันที่': 'Calendar & dates', 'เวลา & ลำดับ': 'Time & order',
       'การนับ & ลักษณนาม': 'Counting & counters', 'จำนวน & ปริมาณ': 'Numbers & amounts'}

vocab = content["vocab"] + extra
level = {v["id"]: ("plus" if v.get("plus") else v["level"]) for v in vocab}
kanji_of = {v["id"]: v["kanji"] for v in vocab}
meta = wordlist["words"]
cats = {c["id"]: c for c in wordlist["categories"]}
cat_of = lambda vid: meta[vid]["sub"].split(".")[0]
every = [v["id"] for v in vocab if v["id"] in meta]          # the 1,403 list words, N5 first
every.sort(key=lambda i: ["n5", "n4", "plus"].index(level[i]))

lessons = {l["n"]: l for l in course["lessons"]}
taught = set()

# 1. Textbook words stay where the book uses them.
chapters = proto["chapters"] if isinstance(proto, dict) else proto
for ch in chapters:
    l = lessons[ch["n"]]
    l["sections"] = []
    for s in ch.get("vocabSections", []):
        ids = []
        for i in s["vocabIDs"]:
            i = renames.get(i, i)
            if i in meta and i not in taught:
                ids.append(i); taught.add(i)
        if ids:
            l["sections"].append({"en": SEC[s["titleTH"]], "th": s["titleTH"], "ids": ids})
for n, l in lessons.items():
    if n > 14:
        l["sections"] = []

# 1b. Words pinned to the lesson where a textbook teaches them (greetings, Minna words).
anchors = json.loads((ROOT / "Tools/wordlist/course_anchor.json").read_text())
pinned = collections.defaultdict(list)
for i, n in anchors.items():
    if i in meta and i not in taught and n in lessons:
        pinned[n].append(i); taught.add(i)

# 2. Everything else, by room, grammar examples and topic.
order = [n for n in sorted(lessons) if n > 0]
cap = math.ceil(len(every) / len(order))
load = collections.Counter({n: sum(len(s["ids"]) for s in lessons[n]["sections"]) + len(pinned[n]) for n in order})
topics = {n: collections.Counter(cat_of(i) for s in lessons[n]["sections"] for i in s["ids"]) for n in order}
gram = {g["key"]: g for g in content["grammar"]}
examples = {n: " ".join(e["ja"] for k in lessons[n]["grammar"] if k in gram for e in gram[k]["examples"]) for n in order}
added = collections.defaultdict(list, {n: list(ids) for n, ids in pinned.items()})

for i in every:
    if i in taught:
        continue
    first = {"n5": 1, "n4": 6, "plus": 15}[level[i]]
    room = [n for n in order if n >= first and load[n] < cap] or [n for n in order if n >= first]
    word = kanji_of[i].replace("〜", "")
    used = [n for n in room if len(word) > 1 and word in examples[n] and (level[i] != "n5" or n <= 14)]
    topical = [n for n in room if topics[n][cat_of(i)]]
    if used:
        n = used[0]
    elif level[i] == "n5":
        n = (topical or room)[0]
    else:
        n = min(topical or room, key=lambda n: (load[n], n))
    added[n].append(i); taught.add(i)
    load[n] += 1
    topics[n][cat_of(i)] += 1

for n, ids in added.items():
    by_cat = collections.defaultdict(list)
    for i in ids:
        by_cat[cat_of(i)].append(i)
    for c, cids in by_cat.items():
        lessons[n]["sections"].append({"en": cats[c]["en"], "th": cats[c]["th"], "ids": cids})

P_COURSE.write_text(json.dumps(course, ensure_ascii=False, separators=(",", ":")))
counts = [load[n] for n in order]
n4_early = sum(1 for n in order if n <= 14 for i in added[n] if level[i] != "n5")
print(f"course_words: {len(taught)}/{len(every)} words in {len(order)} lessons "
      f"({min(counts)}–{max(counts)} per lesson, cap {cap}); {n4_early} N4 words mixed into lessons 1–14")
