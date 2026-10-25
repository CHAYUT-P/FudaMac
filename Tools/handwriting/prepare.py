"""Build the training set: read every source, keep the 92 kana, clean each image,
and split by WRITER (never by image) into train / val / test.

  python prepare.py --etl /path/to/etl --out kana.npz [--folder kaggle_hiragana/] [--grid grid.png]
"""
import argparse, collections, hashlib, sys
import numpy as np
import etl
from kana import CLASSES, INDEX, jp_font, label
from preprocess import normalize, SIZE


def split_of(writer: str) -> str:
    """Stable writer-level split: ~80% train, 10% val, 10% test."""
    h = int(hashlib.md5(writer.encode()).hexdigest(), 16) % 10
    return "test" if h == 0 else "val" if h == 1 else "train"


def sources(args):
    if args.etl:
        for p in etl.find(args.etl, "ETL1C_*"):
            yield "ETL1", etl.read_mtype(p, tag="etl1")
        for p in etl.find(args.etl, "ETL6C_*"):
            yield "ETL6", etl.read_mtype(p, tag="etl6")
        for p in etl.find(args.etl, "ETL7*C_*"):
            yield "ETL7", etl.read_mtype(p, hiragana=True, tag="etl7")
        for p in etl.find(args.etl, "ETL8G_*"):
            yield "ETL8G", etl.read_etl8g(p)
    for f in args.folder or []:
        yield f"folder:{f}", etl.read_folder(f, tag="kaggle")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--etl", help="folder with the unzipped ETL files")
    ap.add_argument("--folder", action="append", help="extra image folder(s): <root>/<char>/*.png")
    ap.add_argument("--out", default="kana.npz")
    ap.add_argument("--grid", default="grid.png", help="sample image per class, to eyeball the labels")
    args = ap.parse_args()

    X, y, writers, srcs = [], [], [], []
    per_source = collections.Counter()
    for name, it in sources(args):
        for ch, writer, img in it:
            if ch not in INDEX:
                continue
            X.append((normalize(img) * 255).astype(np.uint8))
            y.append(INDEX[ch]); writers.append(writer); srcs.append(name)
            per_source[name] += 1
    if not X:
        sys.exit("No kana found. Check --etl points at the unzipped ETL folders (ETL1C_01 …, ETL8G_01 …).")
    X = np.stack(X); y = np.array(y, np.int16); writers = np.array(writers)
    split = np.array([split_of(w) for w in writers])

    counts = collections.Counter(y.tolist())
    print("images per source:", dict(per_source))
    print(f"{len(X)} images, {len(set(writers))} writers, {len(counts)}/{len(CLASSES)} classes")
    missing = [c for i, c in enumerate(CLASSES) if counts[i] == 0]
    if missing: print("MISSING classes:", "".join(missing))
    low = sorted((counts[i], c) for i, c in enumerate(CLASSES) if 0 < counts[i] < 100)
    if low: print("few samples:", low)
    for s in ("train", "val", "test"):
        print(f"  {s:5}: {(split == s).sum():6} images, {len(set(writers[split == s]))} writers")

    np.savez_compressed(args.out, X=X, y=y, writers=writers, split=split, source=np.array(srcs), classes=np.array(CLASSES))
    print("saved", args.out)

    # One random sample per class, so a wrong label (e.g. ETL7 mapping) is obvious at a glance.
    try:
        import matplotlib; matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        if jp_font(): plt.rcParams["font.family"] = jp_font()
        rng = np.random.default_rng(0)
        fig, axes = plt.subplots(8, 12, figsize=(12, 8))
        for i, ax in enumerate(axes.flat):
            ax.axis("off")
            if i < len(CLASSES) and counts[i]:
                idx = rng.choice(np.nonzero(y == i)[0])
                ax.imshow(X[idx], cmap="gray"); ax.set_title(label(i), fontsize=9)
        plt.tight_layout(); plt.savefig(args.grid, dpi=80)
        print("saved", args.grid)
    except Exception as e:
        print("grid skipped:", e)


if __name__ == "__main__":
    main()
