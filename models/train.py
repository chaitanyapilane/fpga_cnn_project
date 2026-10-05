import sys, os, copy, torch, torch.nn as nn, torchvision, numpy as np
import torchvision.transforms as T
from torch.utils.data import DataLoader
from nets import LeNet5, SmallCNN

name = sys.argv[1]                      # lenet | smallcnn
epochs = int(sys.argv[2]) if len(sys.argv) > 2 else 5
if name == "lenet":
    model, ds = LeNet5(), torchvision.datasets.MNIST
else:
    model, ds = SmallCNN(), torchvision.datasets.CIFAR10

tf = T.ToTensor()
tr = DataLoader(ds("../data", train=True,  download=True, transform=tf), batch_size=128, shuffle=True)
te = DataLoader(ds("../data", train=False, download=True, transform=tf), batch_size=512)

def evaluate(m):
    m.eval(); ok = n = 0
    with torch.no_grad():
        for x, y in te:
            ok += (m(x).argmax(1) == y).sum().item(); n += len(y)
    return 100.0 * ok / n

opt = torch.optim.Adam(model.parameters(), lr=1e-3)
for ep in range(epochs):
    model.train()
    for x, y in tr:
        opt.zero_grad(); nn.functional.cross_entropy(model(x), y).backward(); opt.step()
    print(f"epoch {ep+1}/{epochs}  float acc {evaluate(model):.2f}%", flush=True)

# INT8 weight quantization (symmetric, per-layer scale)
qmodel = copy.deepcopy(model)
out = f"../quant/{name}"; os.makedirs(out, exist_ok=True)
for lname, p in list(qmodel.named_parameters()):
    if p.dim() > 1:                      # weights
        scale = p.detach().abs().max().item() / 127.0
        q = torch.clamp(torch.round(p.detach() / scale), -128, 127).to(torch.int8)
        p.data = q.float() * scale       # fake-quant for accuracy check
        arr = q.numpy()
        np.save(f"{out}/{lname}.npy", arr)
        with open(f"{out}/{lname}.mem", "w") as f:
            for v in arr.flatten():
                f.write(f"{int(v) & 0xFF:02x}\n")
        with open(f"{out}/{lname}.scale", "w") as f:
            f.write(f"{scale}\n")
        print(f"exported {lname} shape={tuple(arr.shape)} scale={scale:.6f}")
print(f"INT8-weight accuracy: {evaluate(qmodel):.2f}%  (float: {evaluate(model):.2f}%)")
torch.save(model.state_dict(), f"{out}/model_float.pt")
