import re, glob, os

rows = []
for f in sorted(glob.glob("r/m_*.txt")):
    n = os.path.basename(f)[2:-4]
    t = open(f).read()
    m = re.search(r"LOWER worst-edge p99.9 max ([\d.]+) ; mean %edges>2x ([\d.]+) ; area p99.9 max ([\d.]+)", t)
    if not m:
        continue
    web = re.findall(r"WEB (\w+) total area ratio ([\d.]+) p99 tri ratio ([\d.]+)", t)
    wv = {c: (float(a), float(b)) for c, a, b in web}
    mm = re.search(r"METRIC worst-edge p99.99 max ([\d.]+) ; mean %edges>2x ([\d.]+)", t)
    print(
        f"{n:24s} low_worst {float(m.group(1)):7.1f}  low>2x% {float(m.group(2)):5.2f}  low_area {float(m.group(3)):7.1f} | all_worst {float(mm.group(1)):6.1f} all>2x% {float(mm.group(2)):5.2f} | web(crouch) a{wv.get('crouch_idle', (0, 0))[0]:.2f} p{wv.get('crouch_idle', (0, 0))[1]:.1f} web(run_l) a{wv.get('run_l', (0, 0))[0]:.2f} p{wv.get('run_l', (0, 0))[1]:.1f}"
    )
