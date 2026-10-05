CHUNK, PE = 8192, 16
NETS = {"lenet": [86400,153600,30720,10080,840],
        "smallcnn": [442368,1179648,1179648,10240]}
for name, layers in NETS.items():
    beats = []
    for m in layers:
        while m > 0:
            c = min(CHUNK, m); beats.append(-(-c // PE)); m -= c
    with open(f"rtl/scheduler/chunks_{name}.mem", "w") as f:
        for b in beats: f.write(f"{b:04x}\n")
    print(f"{name}: {len(beats)} chunks, {sum(beats)} beats, ideal 4-tile cycles = {sum(beats)/4:.0f}")
