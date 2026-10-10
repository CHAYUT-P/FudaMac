#!/usr/bin/env python3
"""Build the N5 + N4 word list.

Sources (this folder):
  taxonomy.json      categories → subcategories
  assignments.json   vocab id → {sub, en, thAlt} for every word in content.json
  extra_vocab.json   words the Tone export lacked (full entries + sub/en/thAlt)

Outputs:
  Fuda/Resources/wordlist.json     categories + per-word meta (read by WordList.swift)
  Fuda/Resources/vocab-extra.json  the extra words as Vocab records (merged into DB)

Optional coverage check against JLPT reference lists (CSV with expression,reading
columns, e.g. the tanos.co.uk lists):  build_wordlist.py --reference DIR
where DIR holds n5.csv and n4.csv.
"""
import csv, json, pathlib, re, sys, collections

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE.parent))
from romaji import kana_to_romaji, romanize  # noqa: E402

POS = {"noun", "verb", "adj", "adv", "counter", "particle", "suffix", "prefix", "interj", "pron"}


def fail(msg):
    sys.exit("build_wordlist: " + msg)


def hira(s):
    return "".join(chr(ord(c) - 0x60) if "ァ" <= c <= "ヶ" else c for c in s)


def is_kanji(c):
    return "一" <= c <= "鿿" or c in "々〆"


def kana_ok(ja, kana):
    """Every non-kanji run of ja must appear in kana, in order."""
    runs = re.split(r"[一-鿿々〆]+", ja)
    pos = 0
    k = hira(kana)
    for r in runs:
        r = hira(r)
        if not r:
            continue
        i = k.find(r, pos)
        if i < 0:
            return False
        pos = i + len(r)
    return True


taxonomy = json.loads((HERE / "taxonomy.json").read_text())
subs = {s["id"] for c in taxonomy for s in c["subs"]}
assign = json.loads((HERE / "assignments.json").read_text())
extra = json.loads((HERE / "extra_vocab.json").read_text())
content = json.loads((ROOT / "Fuda/Resources/content.json").read_text())

vocab_ids = [v["id"] for v in content["vocab"]]
missing = [i for i in vocab_ids if i not in assign]
if missing:
    fail(f"{len(missing)} words have no category, e.g. {missing[:5]}")
unknown = [i for i in assign if i not in set(vocab_ids)]
if unknown:
    fail(f"assignments for words not in content.json: {unknown[:5]}")

extra_records, have = [], set(vocab_ids)
for e in extra:
    for k in ("level", "kanji", "kana", "pos", "th", "en", "exJA", "exKana", "exEN", "exTH", "sub"):
        if not str(e.get(k, "")).strip():
            fail(f"extra word {e.get('kanji')}: empty {k}")
    if e["pos"] not in POS:
        fail(f"extra word {e['kanji']}: unknown pos {e['pos']}")
    if not kana_ok(e["exJA"], e["exKana"]):
        fail(f"extra word {e['kanji']}: exKana does not match exJA: {e['exJA']} / {e['exKana']}")
    vid = f"{e['kanji']}_{e['kana']}"
    if vid in have:
        fail(f"extra word {vid} already exists")
    have.add(vid)
    extra_records.append({
        "id": vid, "level": e["level"], "kanji": e["kanji"], "kana": e["kana"],
        "romaji": kana_to_romaji(e["kana"].replace("〜", "")), "pos": e["pos"], "th": e["th"],
        "exJA": e["exJA"], "exKana": e["exKana"], "exRomaji": romanize(e["exJA"], e["exKana"]),
        "exEN": e["exEN"], "exTH": e["exTH"],
        **({"plus": True} if e.get("plus") else {}),
    })
    assign[vid] = {"sub": e["sub"], "en": e["en"], "thAlt": e.get("thAlt", []), **({"more": e["more"]} if e.get("more") else {})}

bad = {i: a["sub"] for i, a in assign.items() if a["sub"] not in subs}
bad.update({i: a["more"] for i, a in assign.items() if any(m not in subs for m in a.get("more", []))})
if bad:
    fail(f"unknown subcategories: {list(bad.items())[:5]}")
for i, a in assign.items():
    if not a.get("en", "").strip():
        fail(f"{i}: empty English gloss")

# Same word listed twice in the source data (spelling variants, 〜 forms, noun /
# する-verb pairs): show one entry, list the other spellings under it, accept
# all their meanings.
MERGE: dict[str, list[str]] = {}   # duplicates are now removed from the data by fix_vocab.py
vocab_by_id = {v["id"]: v for v in content["vocab"]}
for a in assign.values():
    a.setdefault("also", [])
for keep, dups in MERGE.items():
    if keep not in assign:
        fail(f"merge: {keep} not found")
    for d in dups:
        if d not in assign:
            fail(f"merge: {d} not found")
        dv, da = vocab_by_id[d], assign.pop(d)
        k = assign[keep]
        k["also"].append(dv["kanji"])
        th_parts = [t.strip() for t in re.split(r"[/,、]", dv["th"]) if t.strip()]
        k["thAlt"] = list(dict.fromkeys(k["thAlt"] + th_parts + da.get("thAlt", [])))
        en = [e.strip() for e in k["en"].split(";")]
        k["en"] = "; ".join(dict.fromkeys(en + [e.strip() for e in da["en"].split(";")]))
hidden = sum(len(d) for d in MERGE.values())

used = collections.Counter(a["sub"] for a in assign.values())
empty = sorted(subs - set(used))

ref_note = ("Coverage checked against the tanos.co.uk JLPT N5/N4 lists "
            "(Jonathan Waller) — the de-facto standard since JLPT stopped publishing lists.")
out = {"categories": taxonomy, "words": assign, "reference": ref_note}
(ROOT / "Fuda/Resources/wordlist.json").write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")))
(ROOT / "Fuda/Resources/vocab-extra.json").write_text(json.dumps(extra_records, ensure_ascii=False, indent=1))

levels = collections.Counter(v["level"] for v in content["vocab"]) + collections.Counter(e["level"] for e in extra)
print(f"{len(assign)} words in the list (N5 {levels['n5']}, N4 {levels['n4']} in the database, "
      f"{hidden} duplicates merged) in {len(taxonomy)} categories, "
      f"{len(subs) - len(empty)} subcategories used; {len(extra_records)} extra words")
if empty:
    print("  empty subcategories:", ", ".join(empty))
smallest = sorted((n, s) for s, n in used.items())[:5]
print("  smallest:", ", ".join(f"{s} {n}" for n, s in smallest))
print("  largest:", ", ".join(f"{s} {n}" for s, n in used.most_common(5)))

# Optional coverage check
if "--reference" in sys.argv:
    ref = pathlib.Path(sys.argv[sys.argv.index("--reference") + 1])
    words = content["vocab"] + extra_records

    def clean(s):
        return re.sub(r"[～〜~\s]", "", s)

    def variants(s):
        out = set()
        for part in re.split(r"[;、,]", re.sub(r"\((.*?)\)", r"|\1", s)):
            p = clean(part)
            if "|" in p:
                a, b = p.split("|", 1)
                out |= {a, a + b}
            elif p:
                out.add(p)
        return out

    by_k = collections.defaultdict(list)
    by_r = collections.defaultdict(list)
    for v in words:
        for k in v["kanji"].split(" / "):
            by_k[clean(k)].append(v)
        for k in v["kana"].split(" / "):
            by_r[hira(clean(k))].append(v)
    for lvl in ("n5", "n4"):
        rows = list(csv.DictReader(open(ref / f"{lvl}.csv", encoding="utf-8")))
        gaps = []
        for r in rows:
            ex = variants(r["expression"])
            rd = {hira(x) for x in variants(r["reading"] or r["expression"])}
            rd |= {x[:-2] for x in rd if x.endswith("する") and len(x) > 2}
            if any(by_k.get(e) for e in ex):
                continue
            hits = [v for x in rd for v in by_r.get(x, [])]
            if hits and (any(not any(map(is_kanji, e)) for e in ex) or any(not any(map(is_kanji, v["kanji"])) for v in hits)):
                continue
            if hits:
                # same reading, different kanji — fine only for spelling variants of one word
                gaps.append(f"{r['expression']} ({r['reading']}) ~ have {', '.join(v['kanji'] for v in hits)}")
            else:
                gaps.append(f"{r['expression']} ({r['reading']}) {r['meaning']}")
        print(f"  {lvl.upper()}: {len(rows) - len(gaps)}/{len(rows)} reference words found")
        for g in gaps:
            print("     ?", g)
