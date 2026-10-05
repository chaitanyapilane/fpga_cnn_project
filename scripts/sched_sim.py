TILES, PE, Q, CHUNK = 4, 16, 20, 8192
NETS = {
  "lenet":    dict(layers=[86400,153600,30720,10080,840], period=12000,  deadline=6000,   n=33),
  "smallcnn": dict(layers=[442368,1179648,1179648,10240], period=100000, deadline=150000, n=4),
}
def split(layers):
    u = []
    for m in layers:
        while m > 0: u.append(min(CHUNK, m)); m -= CHUNK
    return u
UNITS = {n: split(c["layers"]) for n, c in NETS.items()}

class Job:
    def __init__(s, net, t):
        s.net, s.arr = net, t
        s.dl = t + NETS[net]["deadline"]
        s.units, s.u = UNITS[net], 0
        s.rem, s.tiles, s.done = s.units[0], 0, None

def simulate(policy):
    jobs = sorted((Job(n, k*c["period"]) for n, c in NETS.items() for k in range(c["n"])),
                  key=lambda j: j.arr)
    t = macs = 0
    while any(j.done is None for j in jobs):
        active = [j for j in jobs if j.arr <= t and j.done is None]
        if policy == "static":
            for n, share in (("lenet", 2), ("smallcnn", 2)):
                q = [j for j in active if j.net == n]
                for k, j in enumerate(q): j.tiles = share if k == 0 else 0
        else:  # dynamic EDF, reassign at unit boundaries
            free = TILES - sum(j.tiles for j in active)
            wait = sorted((j for j in active if j.tiles == 0), key=lambda j: j.dl)
            for k, j in enumerate(wait):
                if free <= 0: break
                g = free if policy == "edf" else max(1, free - (len(wait) - k - 1))
                j.tiles, free = g, free - g
        for j in active:
            if j.tiles:
                d = min(j.tiles * PE * Q, j.rem)
                macs += d; j.rem -= d
                if j.rem <= 0:
                    j.tiles = 0; j.u += 1
                    if j.u == len(j.units): j.done = t + Q
                    else: j.rem = j.units[j.u]
        t += Q
    print(f"\n{policy.upper()}  makespan={t} cycles  PE utilization={100*macs/(t*TILES*PE):.1f}%")
    for n in NETS:
        js = [j for j in jobs if j.net == n]
        lat = [j.done - j.arr for j in js]
        miss = sum(j.done > j.dl for j in js)
        print(f"  {n:9s} avg latency={sum(lat)/len(lat):9.0f}  max={max(lat):9d}  deadline misses={miss}/{len(js)}")

simulate("static"); simulate("dynamic"); simulate("edf")
