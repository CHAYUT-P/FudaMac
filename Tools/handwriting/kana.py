"""The 92 classes: 46 basic hiragana + 46 basic katakana, in 五十音 order."""

HIRAGANA = "あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん"
KATAKANA = "".join(chr(ord(c) + 0x60) for c in HIRAGANA)
CLASSES = list(HIRAGANA) + list(KATAKANA)
INDEX = {c: i for i, c in enumerate(CLASSES)}

ROMAJI = ("a i u e o ka ki ku ke ko sa shi su se so ta chi tsu te to na ni nu ne no "
          "ha hi fu he ho ma mi mu me mo ya yu yo ra ri ru re ro wa wo n").split()

assert len(HIRAGANA) == 46 and len(CLASSES) == 92 and len(ROMAJI) == 46


def kata_to_hira(s: str) -> str:
    return "".join(chr(ord(c) - 0x60) if "ァ" <= c <= "ヶ" else c for c in s)


def label(i: int) -> str:
    """Class name for charts: the kana itself, or romaji + H/K when no Japanese font exists."""
    return CLASSES[i] if jp_font() else ROMAJI[i % 46] + ("H" if i < 46 else "K")


_FONT = []
def jp_font():
    """A Japanese font matplotlib can use (Colab: apt-get install fonts-noto-cjk), else None."""
    if not _FONT:
        try:
            from matplotlib import font_manager
            names = {f.name for f in font_manager.fontManager.ttflist}
            _FONT.append(next((n for n in ["Noto Sans CJK JP", "Hiragino Sans", "Hiragino Maru Gothic ProN",
                                           "Hiragino Kaku Gothic Pro", "IPAexGothic", "TakaoGothic"] if n in names), None))
        except Exception:
            _FONT.append(None)
    return _FONT[0]
