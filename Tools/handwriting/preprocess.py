"""The one image cleanup used everywhere: training data, your own drawings, and
(ported line by line) the app — FudaMac/Data/Handwriting.swift. If you change a
constant here, change it there too, or the app will see different images than
the model was trained on.

Steps: ink bright on black → drop faint noise → crop to the ink → pad to a
square with a margin → resize to 64×64 → float 0…1.
"""
import numpy as np
from PIL import Image

SIZE = 64          # model input is SIZE×SIZE
MARGIN = 0.15      # empty border added around the character, as a share of its longer side
NOISE = 0.20       # pixels fainter than this (after scaling to 0…1) count as background


def normalize(img: np.ndarray) -> np.ndarray:
    a = img.astype(np.float32)
    a = (a - a.min()) / max(1e-6, a.max() - a.min())
    # Ink must be bright on a dark background: if the border is bright, invert.
    border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    if np.median(border) > 0.5:
        a = 1.0 - a
    a[a < NOISE] = 0.0
    ys, xs = np.nonzero(a)
    if len(xs) == 0:
        return np.zeros((SIZE, SIZE), np.float32)
    a = a[ys.min(): ys.max() + 1, xs.min(): xs.max() + 1]
    h, w = a.shape
    side = int(round(max(h, w) * (1 + 2 * MARGIN)))
    sq = np.zeros((side, side), np.float32)
    y0, x0 = (side - h) // 2, (side - w) // 2
    sq[y0: y0 + h, x0: x0 + w] = a
    out = Image.fromarray((sq * 255).astype(np.uint8)).resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    out = np.asarray(out, np.float32) / 255.0
    return out / max(1e-6, out.max())
