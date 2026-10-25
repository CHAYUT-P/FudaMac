#!/usr/bin/env python3
"""Convert ★ word-order questions in the original exams to the real JLPT style:
the four pieces are the choices and the answer is the piece that goes in ★.
Idempotent. Usage: convert_star.py FILE..."""
import json, re, sys

def convert(q):
    p = q['prompt']
    m = re.search(r'（(1[^（）]*?)）\s*$', p)
    if not m or not any('・' in o for o in q['options']): return False
    pieces = [re.sub(r'^\d+\s*', '', x).strip() for x in m.group(1).split('／')]
    order = [x.replace('★', '').strip() for x in q['options'][q['answer']].split('・')]
    star = [i for i, x in enumerate(q['options'][q['answer']].split('・')) if '★' in x]
    if len(pieces) != 4 or sorted(order) != sorted(pieces) or len(star) != 1: raise ValueError(q['id'])
    sentence = p[:m.start()].rstrip()
    blanks = iter(['＿★＿' if s == '▲★▲' else '＿＿' for s in re.findall(r'___|▲★▲', sentence)])
    sentence = re.sub(r'___|▲★▲', lambda _: next(blanks), sentence)
    filled = iter(order)
    full = re.sub(r'＿★＿|＿＿', lambda _: next(filled), sentence).replace(' ', '')
    q['prompt'] = sentence + '\n（' + '／'.join(f'{i + 1} {x}' for i, x in enumerate(pieces)) + '）'
    q['options'] = pieces
    q['answer'] = pieces.index(order[star[0]])
    q['optionNotes'] = []
    q['explainTH'] = f"ลำดับที่ถูก: {full} — ช่อง ★ คือ「{order[star[0]]}」\n" + q['explainTH']
    return True

for f in sys.argv[1:]:
    d = json.load(open(f))
    n = sum(convert(q) for s in d['sets'] for p in s['parts'] for b in p['blocks'] for q in b['questions'])
    json.dump(d, open(f, 'w'), ensure_ascii=False, indent=1)
    print(f, n, 'converted')
