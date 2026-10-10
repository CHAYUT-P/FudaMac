#!/usr/bin/env python3
"""Tools/conversations.txt + Tools/talks/L*.txt  →  Fuda/Resources/conversations.json (validated).

conversations.txt holds the real-life scenes. Tools/talks/LNN.txt holds each course
lesson's conversation, told twice: with a friend (register: casual) and politely
(register: polite). Extra syntax there:
  lesson: N / register: casual|polite / pair: lNN      scene fields
  role: NAME | EN | TH                                  a speaker not in ROLES
  g: key, key                                           grammar keys the previous line uses
Every grammar point of lesson N must be used by some line of its pair.
Check only:  python3 Tools/build_conversations.py --check [Tools/talks/L08.txt …]"""
import json, re, sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "Tools" / "conversations.txt"
OUT = ROOT / "Fuda" / "Resources" / "conversations.json"

ROLES = {
    "店員": ("Staff", "พนักงาน"), "駅員": ("Station staff", "พนักงานสถานี"),
    "アナウンス": ("Announcement", "ประกาศ"), "フロント": ("Front desk", "แผนกต้อนรับ"),
    "通行人": ("Passer-by", "คนเดินผ่าน"), "受付": ("Reception", "แผนกต้อนรับ"),
    "医者": ("Doctor", "หมอ"), "運転手": ("Driver", "คนขับ"), "田中": ("Tanaka", "ทานากะ"),
    "局員": ("Post clerk", "พนักงานไปรษณีย์"), "警察官": ("Police officer", "ตำรวจ"),
    "美容師": ("Stylist", "ช่างทำผม"),
    # the textbook story cast (lesson conversations)
    "ゆき": ("Yuki (friend)", "ยูกิ (เพื่อน)"), "リン": ("Lin (classmate)", "หลิน (เพื่อนร่วมชั้น)"),
    "ジョン": ("John (classmate)", "จอห์น (เพื่อนร่วมชั้น)"), "山田先生": ("Ms Yamada (teacher)", "ครูยามาดะ"),
    "鈴木さん": ("Mr Suzuki", "คุณซูซูกิ"),
}
PLACES = {"shop", "food", "transport", "daily", "health", "people"}

def fail(n, msg):
    sys.exit(f"{n}: {msg}")

def split(n, s, k):
    parts = [p.strip() for p in s.split(" | ")]
    if len(parts) != k or any(not p for p in parts):
        fail(n, f"expected {k} fields, got {len(parts)}: {s!r}")
    return parts

CHECK = "--check" in sys.argv
content = json.loads((ROOT / "Fuda/Resources/content.json").read_text(encoding="utf-8"))
GRAMMAR = {g["key"] for g in content["grammar"]}
course = json.loads((ROOT / "FudaMac/Resources/course.json").read_text(encoding="utf-8"))
LESSON_GRAMMAR = {l["n"]: l["grammar"] for l in course["lessons"]}

only = [pathlib.Path(a) for a in sys.argv[1:] if a.endswith(".txt")]   # --check Tools/talks/L08.txt
sources = [SRC] + (only or sorted((ROOT / "Tools" / "talks").glob("L*.txt")))
src_lines = [(f"{p.name}:{n}", raw) for p in sources for n, raw in enumerate(p.read_text(encoding="utf-8").splitlines(), 1)]

def hira(t):
    return "".join(chr(ord(c) - 0x60) if "ァ" <= c <= "ヶ" else c for c in t)

def kana_ok(ja, kana):
    """Every non-kanji run of ja appears, in order, in kana (so furigana can align)."""
    pos, k = 0, hira(kana)
    for r in re.split(r"[一-鿿々〆ヶ\x21-\x7e０-９Ａ-Ｚａ-ｚ]+", ja):
        r = hira(r)
        if r:
            i = k.find(r, pos)
            if i < 0:
                return False
            pos = i + len(r)
    return True

scenes, cur, last = [], None, None
for n, raw in src_lines:
    line = raw.rstrip()
    if not line or line.startswith("#"):
        continue
    if line.startswith("@scene "):
        cur = {"id": line.split()[1], "lines": [], "roles": {}, "extraRoles": {}}
        scenes.append(cur); last = None; continue
    if cur is None:
        fail(n, "content before @scene")
    m = re.match(r"^(title|en|th|glyph|level|place|about|lesson|register|pair|role):\s*(.*)$", line)
    if m:
        k, v = m.groups()
        if k == "about":
            cur["aboutEN"], cur["aboutTH"] = split(n, v, 2)
        elif k == "role":
            name, en, th = split(n, v, 3)
            cur["extraRoles"][name] = (en, th)
        elif k == "lesson":
            cur["lesson"] = int(v)
        else:
            cur[k] = v
        continue
    if line.startswith("g:"):
        if not last: fail(n, "g: without a line")
        keys = [k.strip() for k in line[2:].split(",") if k.strip()]
        bad = [k for k in keys if k not in GRAMMAR]
        if bad: fail(n, f"unknown grammar key(s) {bad}")
        last["grammar"] = keys; continue
    if line.startswith("--- "):
        ja, en, th = split(n, line[4:], 3)
        cur["lines"].append({"kind": "section", "ja": ja, "en": en, "th": th}); last = None; continue
    if line.startswith("alt:"):
        if not last: fail(n, "alt without a line")
        ja, kana, th, en = split(n, line[4:].strip(), 4)
        if not kana_ok(ja, kana): fail(n, f"alt kana does not match the Japanese: {ja} / {kana}")
        last["alts"].append({"ja": ja, "kana": kana, "th": th, "en": en}); continue
    if line.startswith("note:"):
        if not last: fail(n, "note without a line")
        last["noteEN"], last["noteTH"] = split(n, line[5:].strip(), 2); continue
    m = re.match(r"^([^:|]+?)(\*?):\s*(.+)$", line)
    if not m:
        fail(n, f"unrecognised line: {line!r}")
    role, star, rest = m.groups()
    ja, kana, th, en = split(n, rest, 4)
    you = role == "You"
    if not you:
        known = cur["extraRoles"].get(role) or ROLES.get(role)
        if not known: fail(n, f"unknown role {role} (declare it with role: NAME | EN | TH)")
        cur["roles"][role] = {"en": known[0], "th": known[1]}
    last = {"kind": "line", "speaker": "" if you else role, "you": you, "key": bool(star),
            "ja": ja, "kana": kana, "th": th, "en": en, "noteEN": "", "noteTH": "", "alts": [], "grammar": []}
    if not kana_ok(ja, kana): fail(n, f"kana does not match the Japanese: {ja} / {kana}")
    if re.search(r"[一-鿿]", kana): fail(n, f"kanji left in kana: {kana}")
    cur["lines"].append(last)

ids = set()
for s in scenes:
    for k in ("title", "en", "th", "glyph", "level", "place", "aboutEN"):
        if k not in s: sys.exit(f"scene {s['id']}: missing {k}")
    if s["level"] not in ("n5", "n4"): sys.exit(f"scene {s['id']}: bad level")
    if s["place"] not in PLACES: sys.exit(f"scene {s['id']}: bad place")
    if s["id"] in ids: sys.exit(f"duplicate scene {s['id']}")
    ids.add(s["id"])
    for l in s["lines"]:
        if l["kind"] == "line" and re.search(r"[฀-๿]", l["ja"] + l["kana"]):
            sys.exit(f"scene {s['id']}: Thai text inside Japanese field: {l['ja']}")

# Lesson conversations: a casual + a polite telling per lesson, covering its grammar.
pairs = {}
for s in scenes:
    del s["extraRoles"]
    if "lesson" not in s:
        continue
    if s.get("register") not in ("casual", "polite"): sys.exit(f"scene {s['id']}: register must be casual or polite")
    if "pair" not in s: sys.exit(f"scene {s['id']}: missing pair")
    spoken = [l for l in s["lines"] if l["kind"] == "line"]
    if len(spoken) < 12: sys.exit(f"scene {s['id']}: only {len(spoken)} lines (need 12+)")
    if sum(l["you"] for l in spoken) < 4: sys.exit(f"scene {s['id']}: fewer than 4 lines for You")
    pairs.setdefault(s["pair"], []).append(s)
for pid, ss in pairs.items():
    if sorted(x["register"] for x in ss) != ["casual", "polite"]: sys.exit(f"pair {pid}: needs one casual and one polite scene")
    n = ss[0]["lesson"]
    used = {k for x in ss for l in x["lines"] for k in l.get("grammar", [])}
    missing = [k for k in LESSON_GRAMMAR.get(n, []) if k not in used]
    if missing: sys.exit(f"pair {pid} (lesson {n}): grammar not used in any line: {missing}")
if CHECK:
    print(f"ok: {len(scenes)} scenes, {len(pairs)} lesson pairs")
    sys.exit(0)

# Romaji from the hand-checked kana, spaced using the kanji text.
from romaji import romanize
for sc in scenes:
    for l in sc["lines"]:
        if l["kind"] == "line":
            for x in [l] + l["alts"]:
                x["romaji"] = romanize(x["ja"], x["kana"])

OUT.write_text(json.dumps({"scenes": scenes}, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
total = sum(1 for s in scenes for l in s["lines"] if l["kind"] == "line")
print(f"{len(scenes)} scenes, {total} lines → {OUT.relative_to(ROOT)}")
for s in scenes:
    ls = [l for l in s["lines"] if l["kind"] == "line"]
    print(f"  {s['id']:18} {s['level']} {len(ls):3} lines  {sum(l['you'] for l in ls):2} yours  {sum(l['key'] for l in ls):2} key  {sum(len(l['alts']) for l in ls):2} alts")
