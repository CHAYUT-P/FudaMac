"""Kana → Hepburn romaji, word-spaced with help from the original kanji text.

The kana (written by hand) gives the readings; the kanji text tells us where
particles sit, so は reads "wa" and particles stand as separate words.
"""
import re

BASE = dict(zip(
    "あいうえおかきくけこがぎぐげごさしすせそざじずぜぞたちつてとだぢづでどなにぬねのはひふへほばびぶべぼぱぴぷぺぽまみむめもやゆよらりるれろわをんゔぁぃぅぇぉ",
    "a i u e o ka ki ku ke ko ga gi gu ge go sa shi su se so za ji zu ze zo ta chi tsu te to da ji zu de do na ni nu ne no ha hi fu he ho ba bi bu be bo pa pi pu pe po ma mi mu me mo ya yu yo ra ri ru re ro wa o n vu a i u e o".split()))
PUNCT = {"、": ",", "。": ".", "！": "!", "？": "?", "…": "…", "・": " ", "「": "", "」": "", "ー": "-"}
SMALL_Y = {"ゃ": "a", "ゅ": "u", "ょ": "o"}
SMALL_V = {"ぁ": "a", "ぃ": "i", "ぅ": "u", "ぇ": "e", "ぉ": "o"}
PARTICLES = {"は": "wa", "へ": "e", "を": "o", "が": "ga", "に": "ni", "で": "de", "と": "to", "も": "mo", "の": "no", "や": "ya"}

def hira(s):
    return "".join(chr(ord(c) - 0x60) if "ァ" <= c <= "ヶ" else c for c in s)

def kind(c):
    if "ぁ" <= c <= "ゖ": return "h"
    if "ァ" <= c <= "ヺ" or c == "ー": return "k"
    if c in PUNCT or c in "、。！？…「」・ 　": return "p"
    if re.match(r"[A-Za-z0-9\-]", c): return "l"
    return "j"   # kanji, 〇, 々 …

def kana_to_romaji(text):
    cs = list(hira(text))
    out, i, dbl = "", 0, False
    while i < len(cs):
        c = cs[i]
        if c == "っ": dbl = True; i += 1; continue
        if c == "ー":
            if out and out[-1] in "aeiou": out += out[-1]
            i += 1; continue
        if c in BASE:
            syl = BASE[c]
            nxt = cs[i + 1] if i + 1 < len(cs) else ""
            if nxt in SMALL_Y and len(syl) >= 2:
                stem = syl[:-1]
                syl = stem + SMALL_Y[nxt] if stem in ("sh", "ch", "j") else stem + "y" + SMALL_Y[nxt]
                i += 1
            elif nxt in SMALL_V and len(syl) >= 2:
                syl = syl[:-1] + SMALL_V[nxt]; i += 1
            if dbl and syl[0].isalpha():
                out += "t" if syl.startswith("ch") else syl[0]
            dbl = False
            if syl == "n" and i + 1 < len(cs) and cs[i + 1] in BASE and BASE[cs[i + 1]][0] in "aeiouy":
                syl = "n'"
            out += syl
        else:
            out += PUNCT.get(c, c)
        i += 1
    return out

def align(ja, kana):
    """Pair each run of the kanji text with its slice of kana: [(run, kind, kana)].
    Kana and punctuation are single-char runs; kanji/latin/digits are merged runs."""
    runs = []
    for c in ja:
        k = kind(c)
        if runs and k in "jl" and kind(runs[-1][-1]) in "jl":
            runs[-1] += c
        else:
            runs.append(c)
    out, ki, kh = [], 0, hira(kana)
    for idx, r in enumerate(runs):
        k = kind(r[0])
        if k in "jl":
            latin = all(kind(c) == "l" for c in r)
            k = "l" if latin else "j"
            nxt = runs[idx + 1] if idx + 1 < len(runs) else None
            if nxt is None:
                end = len(kana)
                while end > ki and kind(kana[end - 1]) == "p": end -= 1
            else:
                # the whole kana stretch that follows (e.g. "んで", "のないように")
                seq = ""
                for j in range(idx + 1, len(runs)):
                    if kind(runs[j][0]) not in "hkp": break
                    seq += runs[j]
                    if kind(runs[j][0]) == "p": break
                # a kanji run reads at least one kana per character
                start = ki + (1 if latin else len(r))
                end = -1
                for probe in (hira(seq), hira(seq[:2]), hira(seq[:1])):
                    pos = start
                    while probe:
                        pos = kh.find(probe, pos)
                        if pos == -1 or pos + 1 >= len(kh) or kh[pos + 1] not in "ゃゅょぁぃぅぇぉ" or len(probe) > 1:
                            break
                        pos += 1
                    if probe and pos != -1:
                        end = pos; break
                if end == -1: return None
            out.append((r, k, kana[ki:end])); ki = end
        else:
            seg = kana[ki:ki + 1]
            if k != "p" and hira(seg) != hira(r):
                return None
            out.append((r, k, seg)); ki += 1
    return out

# Hiragana words that particles commonly follow.
WORDS = ("こちら", "そちら", "あちら", "どちら", "ここ", "そこ", "あそこ", "どこ", "これ", "それ", "あれ", "どれ",
         "なに", "なん", "だれ", "いつ", "わたし", "あなた", "みなさん", "ちょっと", "すこし", "ぜんぶ")
MULTI = ("から", "まで", "より", "だけ", "など")
OKURI_AFTER = set("っるりれらろ")

def romanize(ja, kana):
    parts = align(ja, kana)
    if not parts:
        return tidy(kana_to_romaji(kana))
    out = []            # finished romaji pieces
    buf = ""            # kana of the word being built
    buf_kind = ""       # kind of the first char in buf

    def flush(space_after=False):
        nonlocal buf, buf_kind
        if buf:
            out.append(kana_to_romaji(buf))
        buf, buf_kind = "", ""

    def word(text):
        out.append(" " + text + " ")

    n = len(parts)
    i = 0
    prev = "p"          # kind of the previous ja char
    while i < n:
        run, k, ks = parts[i]
        nxt = parts[i + 1][0] if i + 1 < n else ""
        if k == "p":
            flush(); out.append(PUNCT.get(run, run) + ("" if run in "「" else " ")); prev = "p"; i += 1; continue
        if k == "l":
            flush(); word(run); prev = "l"; i += 1; continue
        if run == "ー" and prev == "h":
            buf += "ー"; i += 1; continue
        if k == "h":
            after_word = prev in "jkl" or (prev == "h" and any(hira(buf).endswith(w) for w in WORDS))
            # multi-char particles (から, まで …)
            rest = "".join(p[0] for p in parts[i:i + 3] if p[1] == "h")
            m = next((w for w in MULTI if rest.startswith(w)), None)
            if m and after_word:
                tail = parts[i + len(m)] if i + len(m) < n else None
                word_like = (rest + (tail[0] if tail else "")).startswith(("からあ", "からい", "からだ", "までに"))
                if not word_like:
                    flush(); word(kana_to_romaji(m)); i += len(m); prev = "p"; continue
            is_particle = False
            if run in ("を", "へ"):
                is_particle = True
            elif run == "は":
                is_particle = not (nxt in ("い", "じ") and (prev == "p" or not buf))
            elif run in PARTICLES and after_word:
                is_particle = not (run == "で" and nxt in ("す", "し")) and not (nxt in OKURI_AFTER)
                if run == "の" and buf in ("こ", "そ", "あ", "ど"):
                    is_particle = False
            if is_particle:
                r = PARTICLES[run]
                if nxt in ("は", "も") and run in ("に", "で", "と", "へ"):
                    r += PARTICLES[nxt]; i += 1
                flush(); word(r); prev = "p"; i += 1; continue
            if prev == "p" and buf == "":
                pass
            buf += ks; prev = "h"; i += 1; continue
        # kanji or katakana run
        if prev == "h" and buf:
            if hira(buf).endswith(("お", "ご")) and len(buf) > 1:
                head, pre = buf[:-1], buf[-1]
                buf = head; flush(); buf = pre
            elif hira(buf) in ("お", "ご"):
                pass                                   # prefix stays attached
            else:
                flush()
        elif prev == "k" and k == "j" or prev == "j" and k == "k":
            flush()
        buf += ks; prev = k; i += 1
    flush()
    s = ""
    for piece in out:
        if s and not s.endswith(" ") and not piece.startswith((" ", ",", ".", "!", "?", "…")) and piece[:1].isalpha():
            s += " "
        s += piece
    return tidy(s)

FIX = [("deha,", "dewa,"), ("deha ", "dewa "), ("de wa,", "dewa,"), ("konnichiha", "konnichiwa"), ("konnichi wa", "konnichiwa"),
       ("ka getsu", "kagetsu"), ("itsu tsume", "itsutsu me"), ("moushi wake", "moushiwake"), ("taihenmoushi", "taihen moushi"),
       ("kudasaine", "kudasai ne"), (" ,", ","), (" .", "."), (" !", "!"), (" ?", "?")]

def tidy(s):
    s = re.sub(r"\s+", " ", s)
    s = re.sub(r"(desu|masu|masen|deshita|mashita|deshou|mashou)(ka|ne|yo|ga|kara|node|kedo)\b", r"\1 \2", s)
    s = re.sub(r"(?<=\S)(kudasai|gozaimasu|gozaimasen|desu|deshita|deshou)\b", r" \1", s)
    s = re.sub(r"(?<=[a-z])arigatou", " arigatou", s)
    s = s.replace("arigatougozai", "arigatou gozai")
    s = re.sub(r"(?<=[a-z])kudasai", " kudasai", s)
    for _ in range(2):
        for a, b in FIX: s = s.replace(a, b)
    s = re.sub(r"\s+", " ", s)
    return s.strip()

if __name__ == "__main__":
    tests = [("すみません、トイレはありますか。", "すみません、トイレはありますか。"),
             ("はい、奥にございます。どうぞ。", "はい、おくにございます。どうぞ。"),
             ("袋代が三円かかりますが、よろしいですか。", "ふくろだいがさんえんかかりますが、よろしいですか。"),
             ("年齢確認のため、画面のボタンを押してください。", "ねんれいかくにんのため、がめんのボタンをおしてください。"),
             ("保険証はありません。旅行者です。", "ほけんしょうはありません。りょこうしゃです。"),
             ("日本には何をしに来たんですか。", "にほんにはなにをしにきたんですか。"),
             ("Suicaで。", "スイカで。"), ("お部屋は八階の805号室です。", "おへやははちかいのはちまるごごうしつです。"),
             ("では、全額自己負担になりますが、よろしいですか。", "では、ぜんがくじこふたんになりますが、よろしいですか。")]
    for j, k in tests: print(j, "→", romanize(j, k))
