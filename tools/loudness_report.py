"""Integrated loudness and peak of every cue in audio/, by category (docs/AUDIO.md "Mix pass").

    python3 tools/loudness_report.py [--write] [--check] [--outliers] [--md]

Pure standard library (no numpy): ITU-R BS.1770 K-weighting, 400 ms blocks with the absolute and relative gates
(a cue shorter than one block is measured whole), sample peak. Takes (name_1..4.wav) are one cue, measured as the
median of its takes. The .ogg ambience beds (amb_*) are read through ffmpeg when it is installed.
Categories, per-category targets (LUFS), tolerance and the trim cap are in content/rules/sfx_mix.json.
  (none)      table per category: cues, median, spread, outliers, before and after the cue table
  --outliers  also list every cue outside its category's tolerance
  --write     rewrite content/rules/sfx_cues.json: the dB a cue gets in Sfx.play to land on its target
  --check     exit 1 when the cue table is stale (a new or regenerated sound, or edited rules, without --write)
  --tails N.. length, end level and decay time of the named cues (a tail cut off or hanging on)
  --md        print the before/after table as markdown (for docs/AUDIO.md)
"""
import json, math, os, re, statistics, subprocess, sys, wave
from array import array
from multiprocessing import Pool

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
AUDIO = os.path.join(ROOT, 'audio')
RULES = os.path.join(ROOT, 'content', 'rules', 'sfx_mix.json')
CUES = os.path.join(ROOT, 'content', 'rules', 'sfx_cues.json')
BLOCK_S = 0.4       # BS.1770 gating block
STEP_S = 0.1        # 75% overlap
TAKE = re.compile(r'^(.+)_[1-4]$')


def read_pcm(path):
    """Mono float samples and the sample rate; wav directly, ogg through ffmpeg."""
    if path.endswith('.ogg'):
        sr = 44100
        raw = subprocess.run(['ffmpeg', '-v', 'quiet', '-i', path, '-f', 's16le', '-ac', '1', '-ar', str(sr), '-'],
                             capture_output=True).stdout
        a = array('h'); a.frombytes(raw[:len(raw) // 2 * 2])
        return [s / 32768.0 for s in a], sr
    with wave.open(path, 'rb') as w:
        sr, ch, sw = w.getframerate(), w.getnchannels(), w.getsampwidth()
        raw = w.readframes(w.getnframes())
    if sw == 2:
        a = array('h'); a.frombytes(raw)
        x = [s / 32768.0 for s in a]
    else:
        x = [(s - 128) / 128.0 for s in raw]
    if ch > 1:
        x = [sum(x[i:i + ch]) / ch for i in range(0, len(x) - ch + 1, ch)]
    return x, sr


def k_filters(sr):
    """The two BS.1770 stages (shelf, then high-pass) as biquads (b0, b1, b2, a1, a2) for any rate."""
    g, q, f0 = 3.999843853973347, 0.7071752369554196, 1681.974450955533
    k = math.tan(math.pi * f0 / sr); vh = 10 ** (g / 20); vb = vh ** 0.4996667741545416
    a0 = 1 + k / q + k * k
    shelf = ((vh + vb * k / q + k * k) / a0, 2 * (k * k - vh) / a0, (vh - vb * k / q + k * k) / a0,
             2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0)
    q, f0 = 0.5003270373238773, 38.13547087602444
    k = math.tan(math.pi * f0 / sr); a0 = 1 + k / q + k * k
    return shelf, (1.0, -2.0, 1.0, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0)


def biquad(x, c):
    b0, b1, b2, a1, a2 = c
    z1 = z2 = 0.0
    out = [0.0] * len(x)
    for i, v in enumerate(x):
        y = b0 * v + z1
        z1 = b1 * v - a1 * y + z2
        z2 = b2 * v - a2 * y
        out[i] = y
    return out


def measure(path):
    """(integrated LUFS, sample peak dBFS) of one file."""
    x, sr = read_pcm(path)
    if not x:
        return -70.0, -120.0
    peak = 20 * math.log10(max(max(x), -min(x), 1e-6))
    s1, s2 = k_filters(sr)
    sq = [v * v for v in biquad(biquad(x, s1), s2)]
    blk = int(BLOCK_S * sr)
    if len(sq) <= blk:
        ms = [sum(sq) / len(sq)]
    else:
        acc = [0.0]
        for v in sq:
            acc.append(acc[-1] + v)
        ms = [(acc[i + blk] - acc[i]) / blk for i in range(0, len(sq) - blk + 1, int(STEP_S * sr))]
    lu = lambda m: -0.691 + 10 * math.log10(max(m, 1e-12))
    loud = [m for m in ms if lu(m) > -70.0]
    if not loud:
        return -70.0, peak
    rel = lu(sum(loud) / len(loud)) - 10.0
    gated = [m for m in loud if lu(m) > rel]
    return lu(sum(gated) / len(gated)), peak


def tail(path):
    """(length s, last 20 ms vs the loudest 50 ms in dB, seconds the sound stays within 40 dB of it): a tail cut off
    short (an end level near 0) or one that hangs on for seconds shows here."""
    x, sr = read_pcm(path)
    w = int(0.05 * sr)
    rms = lambda seg: 20 * math.log10(max(math.sqrt(sum(v * v for v in seg) / max(len(seg), 1)), 1e-6))
    env = [rms(x[i:i + w]) for i in range(0, max(len(x) - w, 1), w)]
    top = max(env)
    last = max(i for i, e in enumerate(env) if e > top - 40.0) + 1
    return len(x) / sr, rms(x[-int(0.02 * sr):]) - top, last * 0.05


def collect():
    """{cue name: [files]} for every wav (takes folded under the plain name) and every amb_ ogg."""
    files = sorted(f for f in os.listdir(AUDIO) if f.endswith('.wav') or (f.startswith('amb_') and f.endswith('.ogg')))
    names = {f[:-4] for f in files}
    cues = {}
    for f in files:
        n = f[:-4]
        m = TAKE.match(n)
        base = m.group(1) if m and m.group(1) in names else n
        cues.setdefault(base, []).append(os.path.join(AUDIO, f))
    return cues


def measure_all():
    cues = collect()
    flat = [p for ps in cues.values() for p in ps]
    with Pool() as pool:
        got = dict(zip(flat, pool.map(measure, flat, chunksize=8)))
    return {n: (statistics.median(got[p][0] for p in ps), max(got[p][1] for p in ps)) for n, ps in cues.items()}


def classify(name, rules):
    if any(re.search(p, name) for p in rules['skip']):
        return None
    for cat, pat in rules['match']:
        if re.search(pat, name):
            return cat
    return rules['default']


def cue_gain(lufs, peak, cat, rules):
    """dB the cue table gives a cue: nothing inside tolerance, else toward the target, capped, boosts by headroom."""
    d = rules['targets'][cat] - lufs
    if cat in rules['report_only'] or abs(d) <= rules['tolerance_lu']:
        return 0.0
    d = max(-rules['max_trim_db'], min(rules['max_boost_db'], d))
    if d > 0:
        d = min(d, max(0.0, rules['peak_db'] - peak))
    return round(d * 2) / 2


def build(rules):
    rows = {}
    for n, (lufs, peak) in measure_all().items():
        cat = classify(n, rules)
        if cat:
            rows[n] = {'cat': cat, 'lufs': lufs, 'peak': peak, 'gain': cue_gain(lufs, peak, cat, rules)}
    return rows


def summary(rows, rules):
    tol = rules['tolerance_lu']
    out = []
    for cat in rules['targets']:
        r = [v for v in rows.values() if v['cat'] == cat]
        if not r:
            continue
        b = [v['lufs'] for v in r]
        a = [v['lufs'] + v['gain'] for v in r]
        t = rules['targets'][cat]
        out.append({'cat': cat, 'n': len(r), 'target': t, 'peak_max': max(v['peak'] for v in r),
                    'med_b': statistics.median(b), 'sd_b': statistics.pstdev(b), 'out_b': sum(abs(x - t) > tol for x in b),
                    'med_a': statistics.median(a), 'sd_a': statistics.pstdev(a), 'out_a': sum(abs(x - t) > tol for x in a),
                    'trimmed': sum(v['gain'] != 0 for v in r)})
    return out


def main():
    args = sys.argv[1:]
    if args and args[0] == '--tails':
        print('%-22s %6s %9s %9s' % ('cue (takes)', 'len s', 'end dB', 'to -40 s'))
        for n, ps in sorted(collect().items()):
            if n in args[1:]:
                for p in ps:
                    t = tail(p)
                    print('%-22s %6.2f %9.1f %9.2f' % (os.path.basename(p)[:-4], t[0], t[1], t[2]))
        return
    rules = json.load(open(RULES))
    rows = build(rules)
    s = summary(rows, rules)
    if '--md' in args:
        print('| category | cues | target LUFS | median before | spread before (sd) | outliers before | median after | spread after (sd) | outliers after | trimmed | loudest peak dBFS |')
        print('|---|---|---|---|---|---|---|---|---|---|---|')
        for c in s:
            print('| %s | %d | %.1f | %.1f | %.1f | %d | %.1f | %.1f | %d | %d | %.1f |' % (
                c['cat'], c['n'], c['target'], c['med_b'], c['sd_b'], c['out_b'], c['med_a'], c['sd_a'], c['out_a'], c['trimmed'], c['peak_max']))
    else:
        print('%-8s %5s %7s | %8s %6s %4s | %8s %6s %4s | %5s %6s' % (
            'category', 'cues', 'target', 'med bef', 'sd', 'out', 'med aft', 'sd', 'out', 'trim', 'peak'))
        for c in s:
            print('%-8s %5d %7.1f | %8.1f %6.1f %4d | %8.1f %6.1f %4d | %5d %6.1f' % (
                c['cat'], c['n'], c['target'], c['med_b'], c['sd_b'], c['out_b'], c['med_a'], c['sd_a'], c['out_a'], c['trimmed'], c['peak_max']))
    if '--outliers' in args:
        for n, v in sorted(rows.items(), key=lambda kv: (kv[1]['cat'], kv[1]['lufs'])):
            if abs(v['lufs'] - rules['targets'][v['cat']]) > rules['tolerance_lu']:
                print('  %-8s %-28s %6.1f LUFS  peak %6.1f  cue %+.1f dB' % (v['cat'], n, v['lufs'], v['peak'], v['gain']))
    table = {n: v['gain'] for n, v in sorted(rows.items()) if v['gain'] != 0}
    if '--write' in args:
        json.dump({'_doc': 'dB added per cue in Sfx.play (and loops, beds): written by tools/loudness_report.py --write from content/rules/sfx_mix.json; edit the rules, not this file.',
                   'cues': table}, open(CUES, 'w'), indent=1)
        print('wrote %d cue gains to %s' % (len(table), os.path.relpath(CUES, ROOT)))
    if '--check' in args:
        cur = json.load(open(CUES)).get('cues', {}) if os.path.exists(CUES) else {}
        left = sum(abs(v['lufs'] + cur.get(n, 0.0) - rules['targets'][v['cat']]) > rules['tolerance_lu'] + 0.01 for n, v in rows.items())
        print('LOUDNESS %s: cue table %s; %d of %d cues still outside tolerance (peak headroom or the trim/boost cap)' % (
            'ok' if cur == table else 'FAIL', 'current' if cur == table else 'stale, run --write', left, len(rows)))
        sys.exit(0 if cur == table else 1)


if __name__ == '__main__':
    main()
