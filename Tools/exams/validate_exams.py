#!/usr/bin/env python3
"""Check the exam files.  Usage: validate_exams.py [file ...]  (default: all in FudaMac/Resources/Exams)"""
import glob, json, os, re, sys, collections

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DIR = os.path.join(ROOT, 'FudaMac', 'Resources', 'Exams')

# Official counts since 2020: section → [(block name contains, count)]
FORMAT = {
    'n5': {'vocab': [('漢字読み', 7), ('表記', 5), ('文脈規定', 6), ('言い換え', 3)],
           'grammar': [('文の文法１', 9), ('文の文法２', 4), ('文章の文法', 4), ('短文', 2), ('中文', 2), ('情報検索', 1)],
           'listening': [('課題理解', 7), ('ポイント理解', 6), ('発話表現', 5), ('即時応答', 6)]},
    'n4': {'vocab': [('漢字読み', 7), ('表記', 5), ('文脈規定', 8), ('言い換え', 4), ('用法', 4)],
           'grammar': [('文の文法１', 13), ('文の文法２', 4), ('文章の文法', 4), ('短文', 3), ('中文', 3), ('情報検索', 2)],
           'listening': [('課題理解', 8), ('ポイント理解', 7), ('発話表現', 5), ('即時応答', 8)]},
}
MINUTES = {'n5': {'vocab': 20, 'grammar': 40, 'listening': 30}, 'n4': {'vocab': 25, 'grammar': 55, 'listening': 35}}

def check_set(s, errs, warns, ids, strict):
    E = lambda m: errs.append(f"{s.get('id')}: {m}")
    W = lambda m: warns.append(f"{s.get('id')}: {m}")
    for f in ['id', 'level', 'kind', 'label', 'parts']:
        if f not in s: E(f'missing {f}')
    lvl = s.get('level')
    answers = collections.Counter()
    for p in s.get('parts', []):
        sec = p.get('section')
        if sec not in ('vocab', 'grammar', 'listening'): E(f'part {p.get("id")}: bad section {sec}')
        for b in p.get('blocks', []):
            for q in b.get('questions', []):
                where = f'{q.get("id")}'
                if q.get('id') in ids: E(f'duplicate id {q.get("id")}')
                ids.add(q.get('id'))
                opts = q.get('options') or []
                if len(opts) < 3: E(f'{where}: needs 3–4 options')
                if not isinstance(q.get('answer'), int) or not 0 <= q['answer'] < len(opts): E(f'{where}: bad answer index')
                if len(set(opts)) != len(opts): E(f'{where}: duplicate options')
                if not q.get('explainTH'): E(f'{where}: missing explainTH')
                if q.get('type') not in ('vocab', 'grammar', 'reading', 'listening'): E(f'{where}: bad type {q.get("type")}')
                if sec == 'listening':
                    if not q.get('script'): E(f'{where}: listening needs a script')
                    if opts and opts[0] == '1' and not q.get('spokenOptions') and not q.get('img'): E(f'{where}: numbered options need spokenOptions or a picture')
                    if q.get('spokenOptions') and len(q['spokenOptions']) != len(opts): E(f'{where}: spokenOptions count must match options')
                else:
                    if not q.get('prompt') and not b.get('passageJA'): E(f'{where}: empty prompt')
                if q.get('optionNotes') and len(q['optionNotes']) != len(opts): W(f'{where}: optionNotes count != options')
                if '★' in q.get('prompt', '') or any('★' in o for o in opts):
                    if q['prompt'].count('＿★＿') != 1 or q['prompt'].count('＿＿') < 3 or any('・' in o or '★' in o for o in opts) or len(opts) != 4:
                        E(f'{where}: ★ question must be real style: one ＿★＿ + three ＿＿ blanks, the 4 pieces as options')
                answers[q.get('answer')] += 1
    if strict:
        if s.get('kind') != 'original': E('kind must be "original"')
        fmt = FORMAT.get(lvl, {})
        secs = [p.get('section') for p in s.get('parts', [])]
        if secs != ['vocab', 'grammar', 'listening']: E(f'sections must be vocab, grammar, listening (got {secs})')
        for p in s.get('parts', []):
            sec = p.get('section')
            if p.get('minutes') != MINUTES.get(lvl, {}).get(sec): E(f'{sec}: minutes should be {MINUTES[lvl][sec]}')
            for name, want in fmt.get(sec, []):
                got = sum(len(b['questions']) for b in p['blocks'] if name in b.get('nameJA', ''))
                if got != want: E(f'{sec}: {name} has {got} questions, the real test has {want}')
            nums = [q['no'] for b in p['blocks'] for q in b['questions']]
            if nums != list(range(1, len(nums) + 1)): E(f'{sec}: question numbers must run 1…{len(nums)} (got {nums[:5]}…)')
        total = sum(answers.values())
        if total and max(answers.values()) > total * 0.4: W(f'answer positions uneven: {dict(answers)}')

files = sys.argv[1:] or sorted(glob.glob(os.path.join(DIR, 'exams-*.json')))
bad = 0
for f in files:
    errs, warns, ids = [], [], set()
    try:
        d = json.load(open(f))
    except Exception as e:
        print(f'{os.path.basename(f)}: invalid JSON: {e}'); bad += 1; continue
    strict = 'original' in os.path.basename(f)
    for s in d.get('sets', []): check_set(s, errs, warns, ids, strict)
    n = sum(len(b['questions']) for s in d.get('sets', []) for p in s['parts'] for b in p['blocks'])
    print(f'{os.path.basename(f)}: {len(d.get("sets", []))} sets, {n} questions, {len(errs)} errors, {len(warns)} warnings')
    for e in errs[:40]: print('  ERROR', e)
    for w in warns[:20]: print('  WARN ', w)
    bad += len(errs)
sys.exit(1 if bad else 0)
