#!/usr/bin/env python3
"""Builds FudaMac/Resources/course.json: 33 lessons (N5 0-14, N4 15-32),
Tone's lesson dialogues and stories.  Input: the JSON written by
Tools/ExportCourse.swift, proto/n5_course.json and Fuda/Resources/content.json."""
import json, sys
raw = json.load(open(sys.argv[1]))
content = json.load(open('Fuda/Resources/content.json'))
course = json.load(open('/Users/chayut/project/mobile/proto/n5_course.json'))
ch = course['chapters'] if isinstance(course, dict) else course
gram = {g['key']: g for g in content['grammar']}

EN5 = {0:'Hiragana & katakana',1:'Your first sentences',2:'Pointing & asking',3:'Where things are',4:'Everyday verbs',5:'Adjectives & change',6:'Comparing',7:'Wanting & going to do',8:'The te-form',9:'Permission & prohibition',10:'Dictionary form & can',11:'Past & experience',12:'Time & sequence',13:'Reasons & opinions',14:'Quantities & endings'}
EN4 = ['Explaining with んです','More te-form','Giving & receiving','Time & duration','Commands & bans','The four conditionals','Intention & decisions','Guessing & hearsay','Potential & appearance','Purpose & method','Someone, everyone, emphasis','Quoting & embedding','Passive & causative','Advanced connectors','Feelings & tendencies','Start, redo, finish','Viewpoint & evidence','Keigo']
SEC = {'คำศัพท์':'Words','คำถาม & คำชี้':'Questions & pointing','ของใช้':'Everyday things','อาหาร & เครื่องดื่ม':'Food & drink','สถานที่':'Places','ตำแหน่ง & ทิศทาง':'Position & direction','ภายในบ้าน':'Around the house','กริยา & กิจกรรมประจำวัน':'Verbs & daily routine','เวลา & ความถี่':'Time & frequency','คำคุณศัพท์ & สภาพ':'Adjectives & states','ปฏิทิน & วันที่':'Calendar & dates','เวลา & ลำดับ':'Time & order','การนับ & ลักษณนาม':'Counting & counters','จำนวน & ปริมาณ':'Numbers & amounts'}

lessons = []
for x in ch:
    lessons.append({'n': x['n'], 'level': 'n5', 'ja': x['titleJA'], 'th': x['titleTH'], 'en': EN5[x['n']],
        'grammar': x['grammarKeys'],
        'sections': [{'en': SEC[s['titleTH']], 'th': s['titleTH'], 'ids': s['vocabIDs']} for s in x.get('vocabSections', [])],
        'kanji': x['kanjiChars'], 'dialogues': x.get('dialogueKeys', []), 'stories': x.get('storyKeys', [])})

# N4: grammar from Tone's course plan; words/kanji matched to the lesson whose
# grammar examples use them, the rest spread to keep lessons even.
n4ch = [c for c in raw['chapters'] if c['level'] == 'n4']
n4v = [v for v in content['vocab'] if v['level'] == 'n4']
n4k = [k for k in content['kanji'] if k['level'] == 'n4']
texts = [' '.join(e['ja'] for k in c['keys'] if k in gram for e in gram[k]['examples']) for c in n4ch]
words = [[] for _ in n4ch]
for v in n4v:
    hit = next((i for i, t in enumerate(texts) if len(v['kanji']) > 1 and v['kanji'] in t), None)
    if hit is not None: words[hit].append(v['id'])
    else: min(words, key=len).append(v['id'])
vword = {v['id']: v['kanji'] for v in n4v}
kan = [[] for _ in n4ch]
for k in n4k:
    hit = next((i for i, ws in enumerate(words) if any(k['id'] in vword[w] for w in ws)), None)
    (kan[hit] if hit is not None and len(kan[hit]) < 14 else min(kan, key=len)).append(k['id'])
n4d = [d['key'] for d in raw['dialogues'] if d['level'] == 'n4']
n4s = [s['key'] for s in raw['stories'] if s['level'] == 'n4']
for i, c in enumerate(n4ch):
    n = 15 + i
    lessons.append({'n': n, 'level': 'n4', 'ja': c['ja'], 'th': c['th'], 'en': EN4[i], 'grammar': c['keys'],
        'sections': [{'en': 'Words', 'th': 'คำศัพท์', 'ids': words[i]}] if words[i] else [],
        'kanji': kan[i],
        'dialogues': [n4d[(i - 1) // 3]] if i % 3 == 1 and (i - 1) // 3 < len(n4d) else [],
        'stories': [n4s[(i - 2) // 3]] if i % 3 == 2 and (i - 2) // 3 < len(n4s) else []})

missing = [k for l in lessons for k in l['grammar'] if k not in gram]
assert not missing, missing
out = {'lessons': lessons, 'stories': raw['stories'], 'dialogues': raw['dialogues'], 'registers': raw['registers']}
json.dump(out, open('FudaMac/Resources/course.json', 'w'), ensure_ascii=False, separators=(',', ':'))
print(len(lessons), 'lessons;', sum(len(l['grammar']) for l in lessons), 'grammar;',
      sum(len(s['ids']) for l in lessons for s in l['sections']), 'words;', sum(len(l['kanji']) for l in lessons), 'kanji')
print([len(w) for w in words], [len(k) for k in kan])
