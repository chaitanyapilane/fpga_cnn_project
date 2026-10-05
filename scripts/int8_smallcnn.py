import sys; sys.path.insert(0, "models")
import numpy as np, torch, torch.nn.functional as F, torchvision
from nets import SmallCNN
torch.set_default_dtype(torch.float64)

names = ["features.0", "features.3", "features.6", "classifier.1"]
kind  = ["conv", "conv", "conv", "fc"]
NMAX = 256
sd = torch.load("quant/smallcnn/model_float.pt")
W  = {n: torch.tensor(np.load(f"quant/smallcnn/{n}.weight.npy").astype(np.float64)) for n in names}
SW = {n: float(open(f"quant/smallcnn/{n}.weight.scale").read()) for n in names}
M = {}

def forward(x, calibrate=False, keep=None):
    s = 1 / 127.0
    for i, n in enumerate(names):
        b = torch.round(sd[n + ".bias"].double() / (s * SW[n]))
        if kind[i] == "conv": dot = F.conv2d(x, W[n], padding=1); acc = dot + b.view(1, -1, 1, 1)
        else:                 dot = x.flatten(1) @ W[n].T;        acc = dot + b
        if keep is not None: keep[i] = (x, dot)
        if i == len(names) - 1: return acc
        a = acc.clamp(min=0)
        if calibrate:
            s_out = a.max().item() * s * SW[n] / 127.0
            M[n] = (round(s * SW[n] / s_out * 65536), s_out)
        mult, s_out = M[n]
        x = torch.floor((a * mult + 32768) / 65536).clamp(0, 127)
        s = s_out
        if kind[i] == "conv": x = F.max_pool2d(x, 2)

def prep(d): return torch.round(torch.tensor(d).permute(0, 3, 1, 2).double() / 255 * 127)
tr = torchvision.datasets.CIFAR10("data", train=True,  download=False)
te = torchvision.datasets.CIFAR10("data", train=False, download=False)
forward(prep(tr.data[:200]), calibrate=True)

N = 2000
Y = torch.tensor(te.targets[:N]); correct = 0
for k in range(0, N, 250):
    correct += (forward(prep(te.data[k:k+250])).argmax(1) == Y[k:k+250]).sum().item()
fm = SmallCNN(); fm.load_state_dict(sd); fm.eval()
with torch.no_grad():
    fl = (fm(torch.tensor(te.data[:N]).permute(0, 3, 1, 2).double() / 255).argmax(1) == Y).double().mean().item() * 100
print(f"first {N} test images:  float {fl:.2f}%   full-integer {100*correct/N:.2f}%")

keep = {}; forward(prep(te.data[:1]), keep=keep)
cfg = open("tb/layers_smallcnn.cfg", "w")
pk = lambda v: format(sum((int(e) & 0xFF) << (8 * j) for j, e in enumerate(v)), "032x")
for i, n in enumerate(names):
    xin, dot = keep[i]
    P = F.unfold(xin, 3, padding=1)[0].T if kind[i] == "conv" else xin.flatten(1)
    L, K = P.shape; nf = W[n].shape[0]; Kp = -(-K // 16) * 16
    Pp = torch.zeros(L, Kp); Pp[:, :K] = P
    Wp = torch.zeros(nf, Kp); Wp[:, :K] = W[n].reshape(nf, -1)
    Pp, Wp = Pp.numpy().astype(np.int64), Wp.numpy().astype(np.int64)
    E = dot.reshape(nf, L).numpy().astype(np.int64)
    fa, fw, fe = (open(f"tb/S{i}_{t}.mem", "w") for t in ("a", "w", "exp"))
    cnt = 0
    for f in range(nf):
        for p in range(L):
            if cnt == NMAX: break
            for b in range(Kp // 16):
                fa.write(pk(Pp[p, 16*b:16*b+16]) + "\n"); fw.write(pk(Wp[f, 16*b:16*b+16]) + "\n")
            fe.write(format(int(E[f, p]) & 0xFFFFFFFF, "08x") + "\n"); cnt += 1
    fa.close(); fw.close(); fe.close()
    cfg.write(f"{i} {cnt} {Kp//16}\n")
    print(f"S{i} {n:13s} dumped {cnt:3d} of {nf*L:5d} outputs, beats/output={Kp//16:2d}")
cfg.close()
