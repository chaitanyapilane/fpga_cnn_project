import sys; sys.path.insert(0, "models")
import torch, torch.nn as nn
from nets import LeNet5, SmallCNN

def count(model, shape, name):
    rows = []
    def hook(m, i, o):
        if isinstance(m, nn.Conv2d):
            k = m.kernel_size[0] * m.kernel_size[1] * m.in_channels
            macs = o.numel() * k
        else:
            macs = m.in_features * m.out_features
        rows.append((type(m).__name__, tuple(o.shape[1:]), macs))
    hs = [l.register_forward_hook(hook) for l in model.modules()
          if isinstance(l, (nn.Conv2d, nn.Linear))]
    model.eval(); model(torch.zeros(1, *shape))
    for h in hs: h.remove()
    total = sum(r[2] for r in rows)
    print(f"\n{name}")
    for t, s, m in rows:
        print(f"  {t:7s} out={str(s):14s} MACs={m:>9,}  ({100*m/total:4.1f}%)")
    print(f"  TOTAL MACs/inference = {total:,}")

count(LeNet5(), (1, 28, 28), "LeNet-5")
count(SmallCNN(), (3, 32, 32), "SmallCNN")
