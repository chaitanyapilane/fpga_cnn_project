import re, subprocess

cmd = ('yosys -p "read_verilog rtl/pe_array/tile.v rtl/top/multi_top.v; '
       'synth_xilinx -top multi_top -flatten; stat"')
out = subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout

# use only the first statistics block (Yosys prints it twice)
out = out.split("Printing statistics.")[-1]
cnt = {}
for name, n in re.findall(r"^\s+(DSP48E1|FDRE|LUT[1-6]|CARRY4|RAM32M)\s+(\d+)\s*$", out, re.M):
    cnt[name] = cnt.get(name, 0) + int(n)

lut = sum(v for k, v in cnt.items() if k.startswith("LUT"))
# XC7A100T capacities (Nexys 4); verify against the AMD/Digilent datasheet
rows = [
    ("DSP48E1", "Multiplier slices",            cnt.get("DSP48E1", 0), 240),
    ("LUT",     "Logic lookup tables",          lut,                   63400),
    ("FDRE",    "Flip-flops (registers)",       cnt.get("FDRE", 0),    126800),
    ("CARRY4",  "Fast adder carry chains",      cnt.get("CARRY4", 0),  15850),
    ("RAM32M",  "Small distributed memories",   cnt.get("RAM32M", 0),  19000),
]

w = [9, 28, 7, 10, 8]
line = "+" + "+".join("-" * (x + 2) for x in w) + "+"
def row(cells):
    return "| " + " | ".join(str(c).ljust(x) if i < 2 else str(c).rjust(x)
                              for i, (c, x) in enumerate(zip(cells, w))) + " |"

print("\nFPGA resource utilization: 4-tile array + EDF controller")
print("Target: Nexys 4 (Artix-7 XC7A100T)   Source: Yosys synthesis estimate\n")
print(line); print(row(["Resource", "What it is", "Used", "Available", "Used %"])); print(line)
for name, what, used, avail in rows:
    pct = 100.0 * used / avail
    print(row([name, what, used, avail, f"{pct:.2f}%"]))
print(line)
