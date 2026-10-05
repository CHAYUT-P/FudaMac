#!/usr/bin/env python3
"""Validate textbook lesson files.  Usage: validate.py [NN ...]  (default: all)

ERROR = must fix (app would break or show wrong readings).
WARN  = please review (thin content, unusual kanji, …)."""
import json, re, sys, glob, os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RES = os.path.join(ROOT, 'FudaMac', 'Resources')
content = json.load(open(os.path.join(ROOT, 'Fuda', 'Resources', 'content.json')))
course = json.load(open(os.path.join(RES, 'course.json')))
N5_KANJI = {k['id'] for k in content['kanji'] if k['level'] == 'n5'}
ALL_KANJI = {k['id'] for k in content['kanji']}

def is_kanji(c): return '一' <= c <= '鿿' or c in '々〆ヶ'
def to_hira(s): return ''.join(chr(ord(c) - 0x60) if 'ァ' <= c <= 'ヶ' else c for c in s)
KANA_OK = re.compile(r'^[぀-ヿ　-〿！-～0-9A-Za-z\s。、・ー〜！？「」『』（）()…―—：:%％]*$')

def aligns(ja, kana):
    runs = re.findall(r'[一-鿿々〆ヶ]+|[^一-鿿々〆ヶ]+', ja)
    if not any(is_kanji(r[0]) for r in runs): return to_hira(ja.replace(' ', '')) == to_hira(kana.replace(' ', ''))
    pat = '^' + ''.join('(.+?)' if is_kanji(r[0]) else re.escape(to_hira(r.replace(' ', '').replace('　', ''))) for r in runs) + '$'
    return re.match(pat, to_hira(kana.replace(' ', '').replace('　', ''))) is not None

def check(n):
    path = os.path.join(RES, f'textbook-L{n:02d}.json')
    errs, warns = [], []
    E = lambda m: errs.append(m)
    W = lambda m: warns.append(m)
    try:
        L = json.load(open(path))
    except FileNotFoundError:
        return [f'missing {path}'], []
    except json.JSONDecodeError as e:
        return [f'invalid JSON: {e}'], []
    level = 'n5' if n <= 14 else 'n4'
    # kanji the learner has seen: the level's kanji list + kanji in vocab of lessons up to n
    seen = {c for l in course['lessons'][:n + 1] for s in l['sections'] for i in s.get('ids', []) for c in i.split('_')[0]}
    kanji_ok = (N5_KANJI if level == 'n5' else ALL_KANJI) | seen | set('田鈴')  # + cast names

    def jp(item, where, need_th=True):
        if not isinstance(item, dict): E(f'{where}: not an object'); return
        ja, kana = item.get('ja', ''), item.get('kana', '')
        if not ja: E(f'{where}: missing ja'); return
        if not kana: E(f'{where}: missing kana ({ja})'); return
        if need_th and not item.get('th'): E(f'{where}: missing th ({ja})')
        if any(is_kanji(c) for c in kana): E(f'{where}: kana has kanji: {kana}')
        if ' ' in kana or '　' in kana: E(f'{where}: kana has spaces: {kana}')
        if not aligns(ja, kana): E(f'{where}: kana does not match ja → {ja} / {kana}')
        odd = [c for c in ja if is_kanji(c) and c not in kanji_ok]
        if odd: W(f'{where}: kanji outside {level.upper()} list {"".join(sorted(set(odd)))} in {ja}')

    for f in ['n', 'titleJA', 'titleTH', 'goalsTH', 'patterns', 'examples', 'conversation', 'grammar', 'video', 'drillA', 'drillB', 'drillC', 'quiz']:
        if f not in L: E(f'missing field {f}')
    if errs: return errs, warns
    if L['n'] != n: E(f'n is {L["n"]}, expected {n}')
    if not (3 <= len(L['goalsTH']) <= 6): W('goalsTH should have 3–5 items')

    if len(L['patterns']) < 3: W('fewer than 3 patterns')
    for i, p in enumerate(L['patterns']): jp(p, f'patterns[{i}]')
    if len(L['examples']) < 8: W(f'only {len(L["examples"])} examples (want 8–12)')
    for i, e in enumerate(L['examples']):
        jp(e.get('q'), f'examples[{i}].q'); jp(e.get('a'), f'examples[{i}].a')

    c = L['conversation']
    if len(c.get('lines', [])) < 10: W(f'conversation has {len(c.get("lines", []))} lines (want 10–16)')
    for i, l in enumerate(c.get('lines', [])):
        if not l.get('speaker'): E(f'conversation.lines[{i}]: missing speaker')
        jp(l, f'conversation.lines[{i}]')

    keys = set(course['lessons'][n]['grammar'])
    covered = set()
    for gi, g in enumerate(L['grammar']):
        where = f'grammar[{gi}] {g.get("titleJA", "")}'
        if g.get('key'): covered.add(g['key'])
        covered.update(g.get('keys', []))
        bl = g.get('blocks', [])
        kinds = [b.get('t') for b in bl]
        if kinds.count('p') < 3: W(f'{where}: only {kinds.count("p")} paragraphs (want ≥ 3)')
        if kinds.count('ex') < 4: W(f'{where}: only {kinds.count("ex")} examples (want ≥ 4)')
        if 'warn' not in kinds and 'compare' not in kinds: W(f'{where}: no warn/compare block')
        for bi, b in enumerate(bl):
            t = b.get('t')
            if t not in ('p', 'ex', 'table', 'tip', 'warn', 'compare'): E(f'{where}.blocks[{bi}]: unknown t={t}')
            if t in ('p', 'tip', 'warn') and not b.get('th'): E(f'{where}.blocks[{bi}]: missing th')
            if t == 'ex': jp(b, f'{where}.blocks[{bi}]')
            if t == 'compare': jp(b.get('left'), f'{where}.blocks[{bi}].left'); jp(b.get('right'), f'{where}.blocks[{bi}].right')
            if t == 'table' and (not b.get('rows') or len({len(r) for r in b['rows']}) != 1): E(f'{where}.blocks[{bi}]: table rows missing or uneven')
    missing = keys - covered
    if missing: W(f'grammar keys not covered by a section: {sorted(missing)}')

    beats = 0
    for ci, ch in enumerate(L['video']):
        if not ch.get('chapterTH'): E(f'video[{ci}]: missing chapterTH')
        for bi, b in enumerate(ch.get('beats', [])):
            beats += 1
            where = f'video[{ci}].beats[{bi}]'
            if not b.get('th'): E(f'{where}: missing th subtitle')
            if 'say' in b and b['say'] and any(is_kanji(x) for x in b['say']): E(f'{where}: say must be kana: {b["say"]}')
            ids = []
            for r in b.get('rows', []):
                for t in r:
                    ids.append(t.get('id'))
                    if not t.get('id') or not t.get('text'): E(f'{where}: token missing id/text'); continue
                    if t.get('k', 'plain') not in ('plain', 'key', 'ink', 'ghost', 'op', 'strike', 'label', 'note'): E(f'{where}: token {t["id"]} bad kind {t.get("k")}')
                    if t.get('s', 'big') not in ('huge', 'big', 'mid', 'small'): E(f'{where}: token {t["id"]} bad size {t.get("s")}')
                    if t.get('k') not in ('label', 'note') and any(is_kanji(x) for x in t['text']):
                        if not t.get('r'): E(f'{where}: token "{t["text"]}" has kanji but no r (reading)')
                        elif not aligns(t['text'], t['r']): E(f'{where}: token reading mismatch {t["text"]} / {t["r"]}')
            dup = {i for i in ids if ids.count(i) > 1}
            if dup: E(f'{where}: duplicate token ids {sorted(dup)}')
            if not b.get('rows') and not b.get('timeline'): W(f'{where}: empty stage')
    if beats < 20: W(f'video has {beats} beats (want 20–40)')
    if beats > 60: W(f'video has {beats} beats (too long, max ~50)')

    for di, d in enumerate(L['drillA']):
        for ri, r in enumerate(d.get('rows', [])):
            jp(r, f'drillA[{di}].rows[{ri}]')
            for s in r.get('slots', []):
                if s not in r.get('ja', ''): E(f'drillA[{di}].rows[{ri}]: slot "{s}" not in {r.get("ja")}')
    for di, d in enumerate(L['drillB']):
        if len(d.get('items', [])) < 5: W(f'drillB[{di}]: only {len(d.get("items", []))} items')
        for ii, it in enumerate(d.get('items', [])):
            jp(it.get('prompt'), f'drillB[{di}].items[{ii}].prompt', need_th=False)
            jp(it.get('answer'), f'drillB[{di}].items[{ii}].answer', need_th=False)
    for di, d in enumerate(L['drillC']):
        nslots = len(d.get('choices', []))
        if any(len(ch) != len(d['choices'][0]) for ch in d.get('choices', [])): E(f'drillC[{di}]: every choices list needs the same number of options')
        for li, l in enumerate(d.get('lines', [])):
            used = set(int(x) for x in re.findall(r'\{(\d)\}', l.get('ja', '')))
            if any(u >= nslots for u in used): E(f'drillC[{di}].lines[{li}]: placeholder without choices')
            if set(re.findall(r'\{\d\}', l.get('ja', ''))) != set(re.findall(r'\{\d\}', l.get('kana', ''))): E(f'drillC[{di}].lines[{li}]: placeholders differ between ja and kana')
            # check alignment with the first choice filled in
            fill = lambda s, key: re.sub(r'\{(\d)\}', lambda m: d['choices'][int(m.group(1))][0][key], s)
            try: jp({'ja': fill(l['ja'], 'ja'), 'kana': fill(l['kana'], 'kana'), 'th': l.get('th', 'x')}, f'drillC[{di}].lines[{li}]')
            except (KeyError, IndexError): E(f'drillC[{di}].lines[{li}]: bad placeholder/choices')
        for ci, ch in enumerate(d.get('choices', [])):
            for oi, o in enumerate(ch): jp(o, f'drillC[{di}].choices[{ci}][{oi}]')

    if len(L['quiz']) < 10: W(f'quiz has {len(L["quiz"])} items (want 10–15)')
    for qi, q in enumerate(L['quiz']):
        t = q.get('type')
        if t not in ('choice', 'listen', 'order'): E(f'quiz[{qi}]: bad type {t}'); continue
        if not q.get('questionTH'): E(f'quiz[{qi}]: missing questionTH')
        if t in ('choice', 'listen'):
            if not q.get('options') or not isinstance(q.get('answer'), int) or not (0 <= q['answer'] < len(q['options'])): E(f'quiz[{qi}]: options/answer invalid')
        if t == 'listen' and not q.get('kana'): E(f'quiz[{qi}]: listen needs kana')
        if t == 'order':
            if not q.get('tiles') or len(q['tiles']) < 3: E(f'quiz[{qi}]: order needs ≥ 3 tiles')
            if not q.get('kana'): E(f'quiz[{qi}]: order needs kana of the full sentence')
            elif not aligns(''.join(q['tiles']), q['kana']): E(f'quiz[{qi}]: order kana does not match tiles {"".join(q["tiles"])}')
        if t == 'choice' and q.get('ja') and q.get('kana') and not aligns(q['ja'], q['kana']): E(f'quiz[{qi}]: kana does not match ja')
    return errs, warns

nums = [int(a) for a in sys.argv[1:]] or sorted(int(re.search(r'L(\d+)', p).group(1)) for p in glob.glob(os.path.join(RES, 'textbook-L*.json')))
bad = 0
for n in nums:
    errs, warns = check(n)
    status = 'OK' if not errs else f'{len(errs)} ERROR'
    print(f'Lesson {n:02d}: {status}, {len(warns)} warn')
    for e in errs: print('  ERROR', e)
    for w in warns: print('  WARN ', w)
    bad += len(errs)
sys.exit(1 if bad else 0)
