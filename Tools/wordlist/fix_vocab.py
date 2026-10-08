#!/usr/bin/env python3
"""Apply the vocabulary audit (Tools/wordlist/vocab_fixes.json) to the app data.

  "set":    [{"id", "set": {field: value}, "why"}]   corrections (kanji, kana, pos, th, en_gloss,
                                                     exJA, exKana, exEN, exTH)
  "remove": [{"id", "keep", "why"}]                  duplicates: drop "id", point every
                                                     reference at "keep"

Touches Fuda/Resources/content.json (vocab + N5 lesson ids), FudaMac/Resources/course.json,
Tools/wordlist/assignments.json and Tools/wordlist/extra_vocab.json, and records every
changed id in Fuda/Resources/vocab-renames.json so saved progress follows the word. Safe to run again:
fixes already applied are no-ops. Run build_wordlist.py afterwards.
"""
import json, pathlib, re, sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE.parent))
from romaji import kana_to_romaji, romanize  # noqa: E402

P_CONTENT = ROOT / "Fuda/Resources/content.json"
P_COURSE = ROOT / "FudaMac/Resources/course.json"
P_ASSIGN = HERE / "assignments.json"
P_EXTRA = HERE / "extra_vocab.json"
P_RENAMES = ROOT / "Fuda/Resources/vocab-renames.json"   # old id → new id, read by ProgressStore

fixes = json.loads((HERE / "vocab_fixes.json").read_text())
content = json.loads(P_CONTENT.read_text())
course = json.loads(P_COURSE.read_text())
assign = json.loads(P_ASSIGN.read_text())
extra = json.loads(P_EXTRA.read_text())


def hira(s):
    return "".join(chr(ord(c) - 0x60) if "ァ" <= c <= "ヶ" else c for c in s)


def kana_ok(ja, kana):
    pos, k = 0, hira(kana)
    for r in re.split(r"[一-鿿々〆]+", ja):
        r = hira(r)
        if r:
            i = k.find(r, pos)
            if i < 0:
                return False
            pos = i + len(r)
    return True


# One view over both sources: content vocab records and extra words (which carry sub/en).
records = {v["id"]: ("content", v) for v in content["vocab"]}
for e in extra:
    records[f"{e['kanji']}_{e['kana']}"] = ("extra", e)

remap = {}          # old id → new id (kana changes and removed duplicates)
changed = removed = 0

for f in fixes.get("set", []):
    vid = remap.get(f["id"], f["id"])
    if vid not in records:
        continue                                   # already applied (id changed) or gone
    src, rec = records[vid]
    s = dict(f["set"])
    en = s.pop("en_gloss", None)
    if en is not None:
        if src == "extra":
            rec["en"] = en
        elif vid in assign:
            assign[vid]["en"] = en
    for k, val in s.items():
        rec[k] = val
    if "exJA" in s or "exKana" in s:
        if not kana_ok(rec["exJA"], rec["exKana"]):
            sys.exit(f"fix_vocab: {vid}: exKana does not match exJA: {rec['exJA']} / {rec['exKana']}")
        if src == "content" and "exRomaji" not in s:
            rec["exRomaji"] = romanize(rec["exJA"], rec["exKana"])
    if "kana" in s or "kanji" in s:
        if src == "content":
            rec["romaji"] = " / ".join(kana_to_romaji(k.replace("〜", "")) for k in rec["kana"].split(" / "))
        new = f"{rec['kanji']}_{rec['kana']}"
        if new != vid:
            if src == "content":
                rec["id"] = new
            if vid in assign:
                assign[new] = assign.pop(vid)
            records[new] = records.pop(vid)
            remap[vid] = new
    changed += 1

for r in fixes.get("remove", []):
    vid, keep = remap.get(r["id"], r["id"]), remap.get(r["keep"], r["keep"])
    if vid not in records:
        continue
    if keep not in records:
        sys.exit(f"fix_vocab: remove {vid}: kept word {keep} not found")
    src, rec = records.pop(vid)
    if src == "content":
        content["vocab"] = [v for v in content["vocab"] if v["id"] != vid]
    else:
        extra[:] = [e for e in extra if f"{e['kanji']}_{e['kana']}" != vid]
    # The kept entry lists the removed spelling and accepts its meanings.
    meta_keep = assign.get(keep)
    gone = assign.pop(vid, None)
    if meta_keep is not None:
        also = meta_keep.setdefault("also", [])
        _, kept_rec = records[keep]
        if rec["kanji"] != kept_rec["kanji"] and rec["kanji"] not in also:
            also.append(rec["kanji"])
        th_parts = [t.strip() for t in re.split(r"[/,、]", rec["th"]) if t.strip()]
        meta_keep["thAlt"] = list(dict.fromkeys(meta_keep.get("thAlt", []) + th_parts + (gone or {}).get("thAlt", [])))
        if gone:
            en = [e.strip() for e in meta_keep["en"].split(";")] + [e.strip() for e in gone["en"].split(";")]
            meta_keep["en"] = "; ".join(dict.fromkeys(e for e in en if e))
    remap[vid] = keep
    removed += 1

# Example romaji must spell exactly what exKana says (old data had guesses such as
# 入れます → "hairemasu"). Keep it when it does, else regenerate it from the kana.
def romaji_matches(romaji, kana):
    want = re.sub(r"[^a-z]", "", kana_to_romaji(kana).lower())
    toks = [t for t in re.split(r"[\s.,!?\"「」『』~〜…()（）、。！？/-]+", romaji.lower().replace("'", "")) if t]
    for i, t in enumerate(toks):
        if t in ("wa", "e"):        # particle は / へ: only after a real word, never inside one (は|っきり)
            prev, nxt = toks[i - 1] if i else "", toks[i + 1] if i + 1 < len(toks) else ""
            if (len(prev) <= 2 and prev != "no") or re.match(r"([bcdfghjkmprstz])\1", nxt):
                return False
    return "".join({"wa": "ha", "e": "he"}.get(t, t) for t in toks) == want

regenerated = 0
for v in content["vocab"]:
    if not romaji_matches(v["exRomaji"], v["exKana"]):
        g = romanize(v["exJA"], v["exKana"])
        if romaji_matches(g, v["exKana"]):
            v["exRomaji"] = g
            regenerated += 1

# Point lesson word lists at the new ids (keeping order, no repeats).
def fix_ids(ids):
    out = []
    for i in ids:
        j = remap.get(i, i)
        while j in remap:
            j = remap[j]
        if j not in out:
            out.append(j)
    return out

for l in content["lessons"]:
    for s in l["sections"]:
        s["ids"] = fix_ids(s["ids"])
for l in course["lessons"]:
    for s in l.get("sections", []):
        s["ids"] = fix_ids(s["ids"])

renames = json.loads(P_RENAMES.read_text()) if P_RENAMES.exists() else {}
renames.update(remap)
for old in renames:
    while renames[old] in renames:
        renames[old] = renames[renames[old]]

P_RENAMES.write_text(json.dumps(dict(sorted(renames.items())), ensure_ascii=False, indent=1))
P_CONTENT.write_text(json.dumps(content, ensure_ascii=False, separators=(",", ":")))
P_COURSE.write_text(json.dumps(course, ensure_ascii=False, separators=(",", ":")))
P_ASSIGN.write_text(json.dumps(assign, ensure_ascii=False, indent=0))
P_EXTRA.write_text(json.dumps(extra, ensure_ascii=False, indent=1))
print(f"fix_vocab: {changed} corrections applied, {removed} duplicates removed, {regenerated} example romaji regenerated")
