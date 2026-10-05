import sys; sys.path.insert(0, "models")
import numpy as np, torch, torch.nn.functional as F, torchvision
from nets import LeNet5
torch.set_default_dtype(torch.float64)

names = ["features.0", "features.3", "classifier.1", "classifier.3", "classifier.5"]
kind  = ["conv", "conv", "fc", "fc", "fc"]
sd = torch.load("quant/lenet/model_float.pt")
W  = {n: torch.tensor(np.load(f"quant/lenet/{n}.weight.npy").astype(np.float64)) for n in names}
SW = {n: float(open(f"quant/lenet/{n}.weight.scale").read()) for n in names}
M = {}

def forward(x, calibrate=False, keep=None):
    s = 1 / 127.0                                   # input scale
    for i, n in enumerate(names):
        b = torch.round(sd[n + ".bias"].double() / (s * SW[n]))
        if kind[i] == "conv": dot = F.conv2d(x, W[n]); acc = dot + b.view(1, -1, 1, 1)
        else:                 dot = x.flatten(1) @ W[n].T; acc = dot + b
        if keep is not None: keep[i] = (x, dot)
        if i == len(names) - 1: return acc
        a = acc.clamp(min=0)                         # ReLU
        if calibrate:
            s_out = a.max().item() * s * SW[n] / 127.0
            M[n] = (round(s * SW[n] / s_out * 65536), s_out)
        mult, s_out = M[n]
        x = torch.floor((a * mult + 32768) / 65536).clamp(0, 127)   # requant to int8
        s = s_out
        if kind[i] == "conv": x = F.max_pool2d(x, 2)

def prep(d): return torch.round(d.double() / 255 * 127).unsqueeze(1)
tr = torchvision.datasets.MNIST("data", train=True,  download=False)
te = torchvision.datasets.MNIST("data", train=False, download=False)
forward(prep(tr.data[:500]), calibrate=True)

N = 2000
X, Y = prep(te.data[:N]), te.targets[:N]
int_acc = (forward(X).argmax(1) == Y).double().mean().item() * 100
fm = LeNet5(); fm.load_state_dict(sd); fm.eval()
with torch.no_grad():
    fl_acc = (fm(te.data[:N].double().div(255).unsqueeze(1)).argmax(1) == Y).double().mean().item() * 100
print(f"first {N} test images:  float {fl_acc:.2f}%   full-integer {int_acc:.2f}%")

keep = {}; forward(X[:1], keep=keep)
cfg = open("tb/layers.cfg", "w")
for i, n in enumerate(names):
    xin, dot = keep[i]
    P = F.unfold(xin, W[n].shape[-1])[0].T if kind[i] == "conv" else xin.flatten(1)
    L, K = P.shape; nf = W[n].shape[0]; Kp = -(-K // 16) * 16
    Pp = torch.zeros(L, Kp); Pp[:, :K] = P
    Wp = torch.zeros(nf, Kp); Wp[:, :K] = W[n].reshape(nf, -1)
    Pp, Wp = Pp.numpy().astype(np.int64), Wp.numpy().astype(np.int64)
    E = dot.reshape(nf, L).numpy().astype(np.int64)
    pk = lambda v: format(sum((int(e) & 0xFF) << (8 * j) for j, e in enumerate(v)), "032x")
    fa, fw, fe = (open(f"tb/L{i}_{t}.mem", "w") for t in ("a", "w", "exp"))
    for f in range(nf):
        for p in range(L):
            for b in range(Kp // 16):
                fa.write(pk(Pp[p, 16*b:16*b+16]) + "\n"); fw.write(pk(Wp[f, 16*b:16*b+16]) + "\n")
            fe.write(format(int(E[f, p]) & 0xFFFFFFFF, "08x") + "\n")
    cfg.write(f"{i} {nf*L} {Kp//16}\n")
    print(f"L{i} {n:13s} outputs={nf*L:5d} beats/output={Kp//16:2d}")
