"""Train the kana CNN, evaluate it once on the held-out writers, export to Core ML.

  python train.py --data kana.npz --out run1 [--epochs 40]

Writes to --out: best.pt, metrics.json, confusion.png, errors.png,
KanaRecognizer.mlpackage (for the app) and kana.onnx (for a web demo).
"""
import argparse, json, math, os, time
import numpy as np
import torch, torch.nn as nn, torch.nn.functional as F

# ---------------- model ----------------

class Block(nn.Module):
    def __init__(self, cin, cout, stride):
        super().__init__()
        self.c1 = nn.Conv2d(cin, cout, 3, stride, 1, bias=False); self.b1 = nn.BatchNorm2d(cout)
        self.c2 = nn.Conv2d(cout, cout, 3, 1, 1, bias=False); self.b2 = nn.BatchNorm2d(cout)
        self.skip = None if stride == 1 and cin == cout else nn.Sequential(nn.Conv2d(cin, cout, 1, stride, bias=False), nn.BatchNorm2d(cout))

    def forward(self, x):
        y = F.relu(self.b1(self.c1(x)))
        y = self.b2(self.c2(y))
        return F.relu(y + (x if self.skip is None else self.skip(x)))


class KanaNet(nn.Module):
    """A small ResNet: 64×64×1 → 92 classes, about 1.2M parameters."""
    def __init__(self, n_classes=92, width=32):
        super().__init__()
        w = width
        self.stem = nn.Sequential(nn.Conv2d(1, w, 3, 1, 1, bias=False), nn.BatchNorm2d(w), nn.ReLU())
        self.body = nn.Sequential(Block(w, w, 1), Block(w, 2 * w, 2), Block(2 * w, 2 * w, 1),
                                  Block(2 * w, 4 * w, 2), Block(4 * w, 4 * w, 1), Block(4 * w, 8 * w, 2))
        self.head = nn.Sequential(nn.AdaptiveAvgPool2d(1), nn.Flatten(), nn.Dropout(0.3), nn.Linear(8 * w, n_classes))

    def forward(self, x):
        return self.head(self.body(self.stem(x)))


# ---------------- augmentation (on the GPU, per batch) ----------------

def augment(x):
    n = x.shape[0]
    dev = x.device
    ang = (torch.rand(n, device=dev) * 2 - 1) * math.radians(12)
    scale = 0.85 + torch.rand(n, device=dev) * 0.3
    shear = (torch.rand(n, device=dev) * 2 - 1) * 0.15
    tx, ty = [(torch.rand(n, device=dev) * 2 - 1) * 0.08 for _ in range(2)]
    cos, sin = torch.cos(ang) / scale, torch.sin(ang) / scale
    theta = torch.stack([torch.stack([cos, -sin + shear, tx], 1), torch.stack([sin, cos, ty], 1)], 1)
    grid = F.affine_grid(theta, x.shape, align_corners=False)
    x = F.grid_sample(x, grid, align_corners=False, padding_mode="zeros")
    # Stroke thickness: some samples thicker (dilate), some thinner (erode).
    r = torch.rand(n, device=dev)
    thick = F.max_pool2d(x, 3, 1, 1)
    thin = -F.max_pool2d(-x, 3, 1, 1)
    x = torch.where((r < 0.2)[:, None, None, None], thick, torch.where((r > 0.85)[:, None, None, None], thin, x))
    return x.clamp(0, 1)


# ---------------- training ----------------

# Pairs drawn identically in hiragana and katakana: no model can tell them apart without context.
SAME_SHAPE = ["へヘ", "ヘへ"]

def evaluate(model, X, y, bs=2048):
    model.eval(); preds = []
    with torch.no_grad(), torch.autocast(X.device.type, dtype=torch.bfloat16, enabled=X.device.type == "cuda"):
        for i in range(0, len(X), bs):
            preds.append(model(X[i:i + bs]).argmax(1))
    p = torch.cat(preds)
    return (p == y).float().mean().item(), p


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="kana.npz")
    ap.add_argument("--out", default="run1")
    ap.add_argument("--epochs", type=int, default=40)
    ap.add_argument("--bs", type=int, default=512)
    ap.add_argument("--lr", type=float, default=3e-3)
    ap.add_argument("--width", type=int, default=32)
    ap.add_argument("--seed", type=int, default=0)
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    torch.manual_seed(args.seed); np.random.seed(args.seed)
    dev = torch.device("cuda" if torch.cuda.is_available() else "mps" if torch.backends.mps.is_available() else "cpu")
    print("device:", dev)

    d = np.load(args.data, allow_pickle=False)
    classes = [str(c) for c in d["classes"]]
    X = torch.tensor(d["X"], dtype=torch.float32, device=dev)[:, None] / 255.0
    y = torch.tensor(d["y"].astype(np.int64), device=dev)
    split = d["split"]
    tr, va, te = [torch.tensor(np.nonzero(split == s)[0], device=dev) for s in ("train", "val", "test")]
    print(f"train {len(tr)} · val {len(va)} · test {len(te)}")

    # Katakana (ETL1) has far more images than hiragana (ETL8G): sample classes evenly.
    counts = torch.bincount(y[tr], minlength=len(classes)).float()
    w = (1.0 / counts.clamp(min=1))[y[tr]]

    model = KanaNet(len(classes), args.width).to(dev)
    print(f"parameters: {sum(p.numel() for p in model.parameters()) / 1e6:.2f}M")
    steps = args.epochs * math.ceil(len(tr) / args.bs)
    opt = torch.optim.AdamW(model.parameters(), lr=args.lr, weight_decay=5e-4)
    sched = torch.optim.lr_scheduler.OneCycleLR(opt, max_lr=args.lr, total_steps=steps, pct_start=0.15)
    loss_fn = nn.CrossEntropyLoss(label_smoothing=0.1)

    best, history = 0.0, []
    for ep in range(args.epochs):
        model.train(); t0 = time.time(); tot = 0.0
        order = tr[torch.multinomial(w, len(tr), replacement=True)]
        for i in range(0, len(order), args.bs):
            idx = order[i:i + args.bs]
            xb = augment(X[idx])
            with torch.autocast(dev.type, dtype=torch.bfloat16, enabled=dev.type == "cuda"):
                loss = loss_fn(model(xb), y[idx])
            opt.zero_grad(set_to_none=True); loss.backward(); opt.step(); sched.step()
            tot += loss.item() * len(idx)
        acc, _ = evaluate(model, X[va], y[va])
        history.append({"epoch": ep + 1, "loss": tot / len(order), "val_acc": acc})
        print(f"epoch {ep + 1:3}/{args.epochs}  loss {tot / len(order):.4f}  val {acc * 100:.2f}%  ({time.time() - t0:.1f}s)")
        if acc >= best:
            best = acc
            torch.save(model.state_dict(), os.path.join(args.out, "best.pt"))

    # The test set is used once, with the best model by validation accuracy.
    model.load_state_dict(torch.load(os.path.join(args.out, "best.pt"), map_location=dev))
    test_acc, p = evaluate(model, X[te], y[te])
    yt, pt = y[te].cpu().numpy(), p.cpu().numpy()
    conf = np.zeros((len(classes), len(classes)), int)
    np.add.at(conf, (yt, pt), 1)
    per_class = {classes[i]: round(conf[i, i] / max(1, conf[i].sum()), 4) for i in range(len(classes))}
    pairs = sorted(((conf[i, j], classes[i], classes[j]) for i in range(len(classes)) for j in range(len(classes)) if i != j and conf[i, j]), reverse=True)[:20]
    metrics = {"test_acc": round(test_acc, 4), "best_val_acc": round(best, 4), "test_images": int(len(te)),
               "test_writers": int(len(set(d["writers"][split == "test"]))),
               "test_acc_same_shape_ok": round(float(((pt == yt) | np.isin([classes[i] + classes[j] for i, j in zip(yt, pt)], SAME_SHAPE)).mean()), 4),
               "hiragana_test_acc": round(float((pt == yt)[yt < 46].mean()), 4), "katakana_test_acc": round(float((pt == yt)[yt >= 46].mean()), 4),
               "worst_classes": sorted(per_class.items(), key=lambda kv: kv[1])[:10],
               "top_confusions": [{"true": a, "predicted": b, "count": int(n)} for n, a, b in pairs],
               "history": history}
    json.dump(metrics, open(os.path.join(args.out, "metrics.json"), "w"), ensure_ascii=False, indent=1)
    print(f"\nTEST accuracy: {test_acc * 100:.2f}%  (hiragana {metrics['hiragana_test_acc'] * 100:.2f}% · katakana {metrics['katakana_test_acc'] * 100:.2f}%)")
    print("most confused:", ", ".join(f"{c['true']}→{c['predicted']} ×{c['count']}" for c in metrics["top_confusions"][:8]))

    plots(conf, classes, X[te][pt != yt].cpu().numpy(), yt[pt != yt], pt[pt != yt], args.out)
    export(model.cpu().eval(), classes, args.out)


def plots(conf, classes, err_imgs, err_true, err_pred, out):
    try:
        import matplotlib; matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        from kana import jp_font, label
        if jp_font(): plt.rcParams["font.family"] = jp_font()
        names = [label(i) for i in range(len(classes))]
        norm = conf / conf.sum(1, keepdims=True).clip(min=1)
        fig, ax = plt.subplots(figsize=(14, 14))
        ax.imshow(np.log1p(norm * 100), cmap="magma")
        ax.set_xticks(range(len(classes)), names, fontsize=6, rotation=90); ax.set_yticks(range(len(classes)), names, fontsize=6)
        ax.set_xlabel("predicted"); ax.set_ylabel("true"); plt.tight_layout(); plt.savefig(os.path.join(out, "confusion.png"), dpi=90); plt.close()
        k = min(48, len(err_imgs))
        if k:
            fig, axes = plt.subplots(4, 12, figsize=(12, 4.6))
            for i, ax in enumerate(axes.flat):
                ax.axis("off")
                if i < k:
                    ax.imshow(err_imgs[i, 0], cmap="gray"); ax.set_title(f"{names[err_true[i]]}→{names[err_pred[i]]}", fontsize=8)
            plt.tight_layout(); plt.savefig(os.path.join(out, "errors.png"), dpi=90); plt.close()
    except Exception as e:
        print("plots skipped:", e)


class WithSoftmax(nn.Module):
    def __init__(self, m): super().__init__(); self.m = m
    def forward(self, x): return F.softmax(self.m(x), dim=1)


def export(model, classes, out):
    ex = torch.zeros(1, 1, 64, 64)
    wrapped = WithSoftmax(model).eval()
    try:
        torch.onnx.export(wrapped, ex, os.path.join(out, "kana.onnx"), input_names=["image"], output_names=["probs"], opset_version=17)
        print("saved kana.onnx")
    except Exception as e:
        print("onnx skipped:", e)
    try:
        import coremltools as ct
        traced = torch.jit.trace(wrapped, ex)
        ml = ct.convert(traced, inputs=[ct.TensorType(name="image", shape=(1, 1, 64, 64))],
                        classifier_config=ct.ClassifierConfig(classes), convert_to="mlprogram",
                        minimum_deployment_target=ct.target.macOS14)
        ml.short_description = "Fuda kana recognizer: 64×64 grayscale (ink=1, background=0) → 92 kana"
        ml.user_defined_metadata["classes"] = "".join(classes)
        ml.save(os.path.join(out, "KanaRecognizer.mlpackage"))
        print("saved KanaRecognizer.mlpackage")
    except Exception as e:
        print("Core ML export failed:", e)


if __name__ == "__main__":
    main()
