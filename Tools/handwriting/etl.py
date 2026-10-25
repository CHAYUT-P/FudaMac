"""Readers for the ETL Character Database (AIST) binary files.

Download the files from https://etlcdb.db.aist.go.jp/ (free registration).
Only these are needed for kana:
  ETL1  (ETL1C_01 … ETL1C_13)  handwritten katakana (+ digits, letters): M-type records
  ETL8G (ETL8G_01 … ETL8G_33)  handwritten hiragana + kanji
  ETL7  (ETL7LC_1, ETL7LC_2 …)  optional extra hiragana: M-type records
  ETL6  (ETL6C_01 … ETL6C_12)   optional extra katakana: M-type records

Every reader yields (char, writer, image) where image is a 2-D uint8 array
(0–255) straight from the scan; preprocess.normalize() does the rest.
"""
import glob, os, struct, unicodedata
import numpy as np
from kana import kata_to_hira

# --- M-type (ETL1, ETL6, ETL7): 2052-byte records, 64×63 pixels, 4 bits each ---
M_FMT = ">H2sH6BI4H4B4x2016s4x"
M_SIZE = 2052
assert struct.calcsize(M_FMT) == M_SIZE

# --- ETL8G: 8199-byte records, 128×127 pixels, 4 bits each ---
G8_FMT = ">2H8sI4B4H2B30x8128s11x"
G8_SIZE = 8199
assert struct.calcsize(G8_FMT) == G8_SIZE


def unpack4(raw: bytes, w: int, h: int) -> np.ndarray:
    """Packed 4-bit pixels (two per byte, high nibble first) → uint8 0–255."""
    b = np.frombuffer(raw, dtype=np.uint8)
    px = np.empty(b.size * 2, dtype=np.uint8)
    px[0::2] = b >> 4
    px[1::2] = b & 0x0F
    return (px[: w * h].reshape(h, w) * 17).astype(np.uint8)


def x0201_to_char(code: int) -> str | None:
    """JIS X 0201 half-width katakana byte → full-width katakana."""
    if not 0xA1 <= code <= 0xDF:
        return None
    return unicodedata.normalize("NFKC", bytes([code]).decode("cp932"))


def read_mtype(path: str, hiragana: bool = False, tag: str = "etl1"):
    """ETL1 / ETL6 / ETL7. ETL7 is hiragana but stores the matching katakana code,
    so pass hiragana=True for ETL7 files."""
    with open(path, "rb") as f:
        while True:
            rec = f.read(M_SIZE)
            if len(rec) < M_SIZE:
                return
            r = struct.unpack(M_FMT, rec)
            ch = x0201_to_char(r[3])
            if ch is None:
                continue
            if hiragana:
                ch = kata_to_hira(ch)
            sheet = r[2]
            yield ch, f"{tag}-{sheet}", unpack4(r[18], 64, 63)


def jis0208_to_char(code: int) -> str | None:
    try:
        return bytes([0x1B, 0x24, 0x42, code >> 8, code & 0xFF, 0x1B, 0x28, 0x42]).decode("iso2022_jp")
    except UnicodeDecodeError:
        return None


def read_etl8g(path: str, tag: str = "etl8g"):
    with open(path, "rb") as f:
        while True:
            rec = f.read(G8_SIZE)
            if len(rec) < G8_SIZE:
                return
            r = struct.unpack(G8_FMT, rec)
            ch = jis0208_to_char(r[1])
            if ch is None:
                continue
            yield ch, f"{tag}-{r[0]}", unpack4(r[14], 128, 127)


def read_folder(root: str, tag: str = "folder"):
    """Images in root/<char>/*.png (e.g. the Kaggle hiragana set or Fuda's own samples).
    Each file counts as its own writer unless the folder name says otherwise."""
    from PIL import Image
    for d in sorted(os.listdir(root)):
        p = os.path.join(root, d)
        if not os.path.isdir(p) or len(d) != 1:
            continue
        for fn in sorted(glob.glob(os.path.join(p, "*.png")) + glob.glob(os.path.join(p, "*.jpg"))):
            img = np.array(Image.open(fn).convert("L"))
            yield d, f"{tag}-{os.path.splitext(os.path.basename(fn))[0]}", img


def find(root: str, pattern: str) -> list[str]:
    """Data files under root matching e.g. 'ETL1C_*' (skips the INFO files)."""
    return sorted(p for p in glob.glob(os.path.join(root, "**", pattern), recursive=True)
                  if os.path.isfile(p) and "INFO" not in os.path.basename(p).upper())
