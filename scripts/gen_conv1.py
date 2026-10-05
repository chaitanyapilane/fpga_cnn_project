import numpy as np, torch, torch.nn.functional as F, torchvision
W = np.load("quant/lenet/features.0.weight.npy").astype(np.int64)      # (6,1,5,5)
img = torchvision.datasets.MNIST("data", train=False, download=False)[0][0]
x = np.round(np.array(img, dtype=np.float64) / 255.0 * 127).astype(np.int64)  # int8 input, 0..127

ref = F.conv2d(torch.tensor(x, dtype=torch.float64)[None, None],
               torch.tensor(W, dtype=torch.float64)).numpy()[0]        # (6,24,24)

def pack(v):                       # 32 int8 values -> 128-bit hex, element 0 in the low byte
    return format(sum((int(e) & 0xFF) << (8 * i) for i, e in enumerate(v)), "032x")

fa, fw, fe = open("tb/conv1_a.mem", "w"), open("tb/conv1_w.mem", "w"), open("tb/conv1_exp.mem", "w")
n = 0
for f in range(6):
    wv = np.zeros(32, dtype=np.int64); wv[:25] = W[f, 0].flatten()
    for oy in range(24):
        for ox in range(24):
            av = np.zeros(32, dtype=np.int64); av[:25] = x[oy:oy+5, ox:ox+5].flatten()
            exp = int(av @ wv); assert exp == int(ref[f, oy, ox])
            for b in range(2):
                fa.write(pack(av[16*b:16*b+16] if False else np.concatenate([av[16*b:16*b+16]])[:16]) [-32:] + "\n") if False else None
            # two beats of 16 elements each, 128-bit words
            for b in range(2):
                fa.write(format(sum((int(e) & 0xFF) << (8*i) for i, e in enumerate(av[16*b:16*b+16])), "032x") + "\n")
                fw.write(format(sum((int(e) & 0xFF) << (8*i) for i, e in enumerate(wv[16*b:16*b+16])), "032x") + "\n")
            fe.write(format(exp & 0xFFFFFFFF, "08x") + "\n"); n += 1
print(f"wrote {n} outputs; integer reference matches torch conv2d")
