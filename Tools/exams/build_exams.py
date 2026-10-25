#!/usr/bin/env python3
"""Build the Mac app's exam library from Tone's exam export.

1. Export Tone's exams (see ExportExams.swift header) → exams_raw.json
2. python3 Tools/exams/build_exams.py exams_raw.json ~/project/mobile/Tone

Writes FudaMac/Resources/Exams/exams-real.json and copies the listening audio
(Audio/*.m4a) and picture options (Assets.xcassets/*.imageset/*.png) next to it.
Real JLPT material stays out of git (see .gitignore); original exams live in
exams-original-n5.json / -n4.json and are built by hand.
"""
import json, os, re, shutil, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, 'FudaMac', 'Resources', 'Exams')

# Official section times (minutes): language knowledge (vocab), (grammar)・reading, listening.
TIMES = {('n5', 'new'): [20, 40, 30], ('n5', 'old'): [25, 50, 30],
         ('n4', 'new'): [25, 55, 35], ('n4', 'old'): [30, 60, 35]}

# id → (kind, format, date label, sort key). kind: full = real, every part incl. real
# listening audio; partial = real but not the whole test.
META = {
    'set4': ('full', 'new', 'ข้อสอบจริง ธ.ค. 2021', 'Dec 2021', 1),
    'set5': ('full', 'old', 'ข้อสอบจริง ก.ค. 2018', 'Jul 2018', 2),
    'set2': ('full', 'old', 'แบบฝึกหัดทางการ 2018', 'Official workbook 2018', 3),
    'set3': ('full', 'old', 'แบบฝึกหัดทางการ 2012', 'Official workbook 2012', 4),
    'set8': ('partial', 'new', 'ข้อสอบจริง ธ.ค. 2025', 'Dec 2025', 5),
    'set7': ('partial', 'new', 'ข้อสอบจริง ก.ค. 2025', 'Jul 2025', 6),
    'set6': ('partial', 'new', 'ข้อสอบจริง 2024', '2024', 7),
    'set1': ('partial', 'old', 'ตัวอย่างข้อสอบทางการ 2009', 'Official sample 2009', 8),
}

# Transcription slips in the source: a distractor duplicated the right answer.
PATCH_OPTIONS = {('n5s3.v2_q12', 3): '飴みました', ('n4s4_p1_m1_q1', 2): 'しゅっはつ'}

def section(part_title):
    if '聴解' in part_title: return 'listening'
    if '文字' in part_title: return 'vocab'
    return 'grammar'

def qtype(block_name, sec):
    if sec == 'listening': return 'listening'
    if sec == 'vocab': return 'vocab'
    return 'reading' if re.search(r'内容理解|読解|情報検索', block_name) else 'grammar'

raw = json.load(open(sys.argv[1]))
# ★ word-order questions rewritten in the real style (pieces as choices, answer = the ★ piece).
STAR = json.load(open(os.path.join(ROOT, 'Tools', 'exams', 'star_fixes.json'))) if os.path.exists(os.path.join(ROOT, 'Tools', 'exams', 'star_fixes.json')) else {}
tone = sys.argv[2]
os.makedirs(os.path.join(OUT, 'Audio'), exist_ok=True)
os.makedirs(os.path.join(OUT, 'Images'), exist_ok=True)
sets, audio, images = [], set(), set()
for s in raw:
    key = s['id'].split('.')[1]
    kind, fmt, label, labelEN, order = META[key]
    if key == 'set6':   # N5's 2024 sitting is July, N4's is December
        label = s['subtitle']; labelEN = 'Jul 2024' if s['level'] == 'n5' else 'Dec 2024'
    lvl = s['level']
    times = TIMES[(lvl, fmt)]
    parts = []
    for i, p in enumerate(s['parts']):
        sec = section(p['titleJA'])
        n = sum(len(b['questions']) for b in p['blocks'])
        minutes = times[['vocab', 'grammar', 'listening'].index(sec)]
        if key == 'set1':  # the sample has only a few questions per part: scale the time down
            minutes = max(5, round(minutes * n / {'vocab': 33, 'grammar': 32, 'listening': 24}[sec]))
        blocks = []
        for b in p['blocks']:
            if b['audio']: audio.add(b['audio'])
            qs = []
            for q in b['questions']:
                if q['img']: images.add(q['img'])
                q = dict(q); q['type'] = qtype(b['nameJA'], sec)
                if q['id'] in STAR:
                    f = STAR[q['id']]
                    q.update(prompt=f['prompt'] + '\n（' + '／'.join(f'{i + 1} {x}' for i, x in enumerate(f['options'])) + '）',
                             options=f['options'], answer=f['answer'], optionNotes=[],
                             explainTH=f"ลำดับที่ถูก: {f['order']} — ช่อง ★ คือ「{f['options'][f['answer']]}」\n" + f.get('explainTH', ''))
                for (qid, i), v in PATCH_OPTIONS.items():
                    if q['id'] == qid: q['options'] = q['options'][:i] + [v] + q['options'][i + 1:]
                qs.append(q)
            blocks.append(dict(b, questions=qs))
        parts.append(dict(id=p['id'], section=sec, titleJA=p['titleJA'], titleTH=p['titleTH'], minutes=minutes, blocks=blocks))
    secs = {p['section'] for p in parts}
    missing = [x for x in ('vocab', 'grammar', 'listening') if x not in secs]
    sets.append(dict(id=f'{lvl}.{key}', level=lvl, kind=kind, format=fmt, order=order, label=label, labelEN=labelEN,
                     titleJA=f'JLPT {lvl.upper()} {labelEN}', noteTH=s['noteTH'], source=s['source'], missing=missing, parts=parts))
sets.sort(key=lambda x: (x['level'] != 'n5', x['order']))
json.dump({'sets': sets}, open(os.path.join(OUT, 'exams-real.json'), 'w'), ensure_ascii=False, separators=(',', ':'))

for a in sorted(audio):
    shutil.copy(os.path.join(tone, 'Audio', a + '.m4a'), os.path.join(OUT, 'Audio', a + '.m4a'))
for im in sorted(images):
    d = os.path.join(tone, 'Assets.xcassets', im + '.imageset')
    pngs = [f for f in os.listdir(d) if f.endswith('.png')]
    shutil.copy(os.path.join(d, pngs[0]), os.path.join(OUT, 'Images', im + '.png'))
for s in sets:
    n = sum(len(b['questions']) for p in s['parts'] for b in p['blocks'])
    print(f"{s['id']:9} {s['kind']:8} {s['format']}  {n:3} questions  missing={s['missing']}  {[p['minutes'] for p in s['parts']]}")
print(len(audio), 'audio tracks,', len(images), 'images')
