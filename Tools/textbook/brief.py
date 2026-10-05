#!/usr/bin/env python3
"""Print everything an author needs to write textbook lesson NN:
title, grammar points to teach (with the existing data as reference), the
lesson's vocab and kanji, and what earlier lessons already taught.
Usage: brief.py NN"""
import json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
content = json.load(open(os.path.join(ROOT, 'Fuda', 'Resources', 'content.json')))
course = json.load(open(os.path.join(ROOT, 'FudaMac', 'Resources', 'course.json')))
G = {g['key']: g for g in content['grammar']}
V = {v['id']: v for v in content['vocab']}
n = int(sys.argv[1])
L = course['lessons'][n]

print(f'# Lesson {n} — {L["ja"]} / {L["th"]} / {L["en"]}  (level {L["level"].upper()})\n')
print('## Grammar to teach (one grammar section each; the data below is reference, write your own deeper teaching)')
for k in L['grammar']:
    g = G.get(k, {})
    print(f'\n### {k} — {g.get("pattern")}  ({g.get("th")} / {g.get("en")})')
    for f in ('formationTH', 'explainTH', 'mistakesTH'):
        if g.get(f): print(f'- {f}: {g[f]}')
    for e in g.get('examples', [])[:3]:
        print(f'  ex: {e["ja"]} ({e["kana"]}) — {e["th"]}')

print('\n## This lesson\'s vocabulary (kanji form / kana / Thai)')
words = [i for s in L['sections'] for i in s.get('ids', [])]
print(', '.join(f'{V[i]["kanji"] or V[i]["kana"]}({V[i]["kana"]}) {V[i]["th"]}' if i in V else i for i in words))
print('\n## This lesson\'s kanji:', ' '.join(L['kanji']))

print('\n## Already taught in earlier lessons (you may use these freely)')
for p in course['lessons'][1:n]:
    print(f'- L{p["n"]} {p["ja"]} ({p["th"]}): ' + ', '.join(f'{k}={G[k]["pattern"]}' if k in G else k for k in p['grammar']))
prev = [i.split('_')[0] for p in course['lessons'][1:n] for s in p['sections'] for i in s.get('ids', [])]
print(f'\nEarlier vocabulary ({len(prev)} words): ' + '、'.join(prev))
print('\n## Taught LATER (do not rely on these yet; if you must, gloss in Thai)')
for p in course['lessons'][n + 1:]:
    print(f'- L{p["n"]}: ' + ', '.join(G[k]['pattern'] if k in G else k for k in p['grammar']))
