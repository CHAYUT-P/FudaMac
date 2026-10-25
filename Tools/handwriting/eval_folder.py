"""Accuracy on your own drawings (exported from Fuda's 書 Handwriting → Collect).

  python eval_folder.py --model run1/best.pt --folder my_samples/

The folder holds <char>/*.png; each image goes through the same preprocess.normalize().
"""
import argparse, collections
import numpy as np, torch
import etl
from kana import CLASSES, INDEX
from preprocess import normalize
from train import KanaNet


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True)
    ap.add_argument("--folder", required=True)
    ap.add_argument("--width", type=int, default=32)
    args = ap.parse_args()
    model = KanaNet(len(CLASSES), args.width)
    model.load_state_dict(torch.load(args.model, map_location="cpu")); model.eval()
    ok, n, wrong = 0, 0, collections.Counter()
    for ch, _, img in etl.read_folder(args.folder, tag="me"):
        if ch not in INDEX:
            continue
        x = torch.tensor(normalize(img))[None, None]
        with torch.no_grad():
            p = model(x).argmax(1).item()
        n += 1; ok += p == INDEX[ch]
        if p != INDEX[ch]: wrong[(ch, CLASSES[p])] += 1
    print(f"{ok}/{n} = {ok / max(1, n) * 100:.1f}% on your drawings")
    print("mistakes:", ", ".join(f"{a}→{b} ×{c}" for (a, b), c in wrong.most_common(15)))


if __name__ == "__main__":
    main()
