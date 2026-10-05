#!/usr/bin/env python3
"""Tools/conversations.txt  →  Fuda/Resources/conversations.json (validated)."""
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
}
PLACES = {"shop", "food", "transport", "daily", "health", "people"}

def fail(n, msg):
    sys.exit(f"conversations.txt:{n}: {msg}")

def split(n, s, k):
    parts = [p.strip() for p in s.split(" | ")]
    if len(parts) != k or any(not p for p in parts):
        fail(n, f"expected {k} fields, got {len(parts)}: {s!r}")
    return parts

scenes, cur, last = [], None, None
for n, raw in enumerate(SRC.read_text(encoding="utf-8").splitlines(), 1):
    line = raw.rstrip()
    if not line or line.startswith("#"):
        continue
    if line.startswith("@scene "):
        cur = {"id": line.split()[1], "lines": [], "roles": {}}
        scenes.append(cur); last = None; continue
    if cur is None:
        fail(n, "content before @scene")
    m = re.match(r"^(title|en|th|glyph|level|place|about):\s*(.*)$", line)
    if m:
        k, v = m.groups()
        if k == "about":
            cur["aboutEN"], cur["aboutTH"] = split(n, v, 2)
        else:
            cur[k] = v
        continue
    if line.startswith("--- "):
        ja, en, th = split(n, line[4:], 3)
        cur["lines"].append({"kind": "section", "ja": ja, "en": en, "th": th}); last = None; continue
    if line.startswith("alt:"):
        if not last: fail(n, "alt without a line")
        ja, kana, th, en = split(n, line[4:].strip(), 4)
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
        if role not in ROLES: fail(n, f"unknown role {role}")
        cur["roles"][role] = {"en": ROLES[role][0], "th": ROLES[role][1]}
    last = {"kind": "line", "speaker": "" if you else role, "you": you, "key": bool(star),
            "ja": ja, "kana": kana, "th": th, "en": en, "noteEN": "", "noteTH": "", "alts": []}
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
