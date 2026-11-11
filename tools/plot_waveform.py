#!/usr/bin/env python3
"""Draw a waveform PNG/PDF from a GHDL VCD file .

  cd sim
  ghdl -r --std=08 cpu_tb --vcd=cpu.vcd          (after run_ghdl.bat has analysed the files)
  python ../tools/plot_waveform.py cpu.vcd --prog 6 --start 0 --end 150 --out ../docs/waveform.png

Needs:  pip install matplotlib
Note: GHDL does not write enum signals to VCD, so 'state' is not drawn (FETCH/EXEC alternate every clock).
"""
import argparse, sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ap = argparse.ArgumentParser()
ap.add_argument("vcd")
ap.add_argument("--prog", type=int, default=6, help="CPU number gen(N) to draw (default 6 = 5-instruction demo)")
ap.add_argument("--start", type=float, default=0, help="start time in ns")
ap.add_argument("--end", type=float, default=150, help="end time in ns")
ap.add_argument("--out", default="waveform.png", help="output file (.png or .pdf)")
a = ap.parse_args()

# (name, kind, radix)   kind: 'bit' or 'bus'
WANT = [("pc", "bus", "dec"), ("ir", "bus", "hex"), ("acc", "bus", "dec"), ("cnt", "bus", "dec"),
        ("sp", "bus", "dec"), ("flag_z", "bit", ""), ("flag_c", "bit", ""),
        ("out_port", "bus", "dec"), ("out_strobe", "bit", ""), ("halted", "bit", "")]
names = {w[0] for w in WANT}

lines = open(a.vcd).read().split("\n")
scope, ids, clk_id = [], {}, None
timescale = 1e-15  # GHDL writes fs
for l in lines:
    if l.startswith("$scope"):
        scope.append(l.split()[2])
    elif l.startswith("$upscope"):
        scope.pop()
    elif l.startswith("$var"):
        p = l.split(); nm = p[4].split("[")[0]
        if scope[-2:] == [f"gen({a.prog})", "dut"] and nm in names:
            ids[p[3]] = nm
        if scope[-1:] == ["cpu_tb"] and nm == "clk":
            clk_id = p[3]
if not ids:
    sys.exit(f"gen({a.prog}).dut not found in {a.vcd}")

changes = {n: [] for n in names}; clk = []
t = 0
for l in lines:
    if l.startswith("#"):
        t = int(l[1:]) / 1e6          # fs -> ns
    elif l.startswith("b"):
        v, i = l[1:].split()
        if i in ids: changes[ids[i]].append((t, v))
    elif l and l[0] in "01UXZ":
        i = l[1:]
        if i in ids: changes[ids[i]].append((t, l[0]))
        if i == clk_id: clk.append((t, l[0]))

def text(v, radix):
    if set(v) - set("01"): return "?"
    n = int(v, 2)
    return f"{n:04X}" if radix == "hex" else str(n)

fig, axes = plt.subplots(len(WANT) + 1, 1, figsize=(13, 0.62 * (len(WANT) + 1) + 0.8), sharex=True)
x0, x1 = a.start, a.end
def draw_bit(ax, ch, color):
    xs, ys = [], []
    for k, (tt, v) in enumerate(ch):
        y = 1 if v == "1" else 0
        if xs: xs.append(tt); ys.append(ys[-1])
        xs.append(tt); ys.append(y)
    xs.append(x1 + 1e6); ys.append(ys[-1])
    ax.plot(xs, ys, color=color, lw=1.4, drawstyle="default")
    ax.set_ylim(-0.3, 1.3); ax.set_yticks([])

# clock
draw_bit(axes[0], clk, "gray"); axes[0].set_ylabel("clk", rotation=0, ha="right", va="center")
for ax, (nm, kind, radix) in zip(axes[1:], WANT):
    ch = changes[nm]
    if kind == "bit":
        draw_bit(ax, ch, "tab:blue")
    else:
        ax.set_ylim(0, 1); ax.set_yticks([])
        for k, (tt, v) in enumerate(ch):
            te = ch[k + 1][0] if k + 1 < len(ch) else x1 + 1e6
            if te < x0 or tt > x1: continue
            ax.fill([tt, tt, te, te], [0.1, 0.9, 0.9, 0.1], fc="#e8f0fe", ec="tab:blue", lw=1)
            xm = (max(tt, x0) + min(te, x1)) / 2
            if min(te, x1) - max(tt, x0) > (x1 - x0) / 60:
                ax.text(xm, 0.5, text(v, radix), ha="center", va="center", fontsize=9)
    ax.set_ylabel(nm, rotation=0, ha="right", va="center")
axes[-1].set_xlim(x0, x1)
axes[-1].set_xlabel("time (ns)")
fig.suptitle(f"cpu8  -  CPU gen({a.prog})  ({text('0','dec')})".replace(" (0)", ""), fontsize=11)
fig.tight_layout()
fig.savefig(a.out, dpi=150)
print("wrote", a.out)
