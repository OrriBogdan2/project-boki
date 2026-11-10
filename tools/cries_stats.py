"""Measures the Boki cries (audio/cries, made by tools/gen_boki_cries.py) and checks the family rule.

    python3 tools/cries_stats.py [--json out.json]

Per file (tools/sfx_stats.py numbers): peak under the ceiling, RMS within tolerance of the "boki" category
(content/rules/sfx_levels.json), the first millisecond well under the peak (no click), no DC, 0.4-1.4 s long.
Then the family test: each cry becomes a log-frequency spectrogram (12 bins per octave, time squeezed to a
fixed grid), and the distance between two cries is the smallest difference over a transposition of up to an
octave either way, plus the difference in how the voice flutters (trill / purr rate). Stage changes (pitch,
length) fall out of it. The motif, vowel and texture stay. Boki of one evolution line must sit closer to each
other than to the rest, and no two unrelated Boki may be near twins. Exit code 1 when a rule fails.
"""
import json, os, sys
import numpy as np
import sfx_stats

HERE = os.path.dirname(os.path.abspath(__file__))
CRIES = os.path.join(HERE, '..', 'audio', 'cries')
LEVELS = json.load(open(os.path.join(HERE, '..', 'content', 'rules', 'sfx_levels.json')))
DUR = (0.4, 1.4)          # s: a cry is one short call
EDGE_MAX = -12.0          # dB: the first ms relative to the peak; above this it starts with a click
BINS_PER_OCT = 12
F_LO, OCTAVES = 100.0, 6  # the log-frequency grid: 100 Hz to 6.4 kHz
TIME_STEPS = 16           # a cry's spectrogram squeezed to this many columns
SHIFT_MAX = 14            # bins (semitones) of transposition the match may absorb either way
MOD_WEIGHT = 0.3          # how much a different trill / purr rate adds to the distance
NEAR_TWIN = 0.5           # share of the mean within-line distance under which two unrelated cries are twins
FAMILY_MAX = 0.85         # within-line / between-line mean distance must stay under this
NEIGHBOUR_MIN = 0.5       # share of multi-stage Boki whose nearest cry is a line-mate


def logf_spectrogram(x, sr):
    """Log power on a 12-per-octave grid, over the loud part of the cry squeezed to TIME_STEPS columns,
    each spectrogram standardised (a shape, not a level)."""
    win, hop = 2048, int(sr * 0.01)
    fr = np.array([x[i:i + win] for i in range(0, max(1, len(x) - win), hop)])
    spec = np.abs(np.fft.rfft(fr * np.hanning(win), axis=1)) ** 2
    f = np.fft.rfftfreq(win, 1.0 / sr)
    loud = spec.sum(1)
    keep = np.where(loud > loud.max() * 0.03)[0]
    spec = spec[keep[0]:keep[-1] + 1]
    centres = F_LO * 2 ** (np.arange(BINS_PER_OCT * OCTAVES) / BINS_PER_OCT)
    bank = np.array([np.exp(-((np.log2(f[1:] / c)) / (1.0 / BINS_PER_OCT)) ** 2) for c in centres])
    lf = np.log(spec[:, 1:] @ bank.T + 1e-9)
    t = np.linspace(0, len(lf) - 1, TIME_STEPS)
    lf = np.array([np.interp(t, np.arange(len(lf)), lf[:, b]) for b in range(lf.shape[1])]).T
    return (lf - lf.mean()) / (lf.std() + 1e-9)


def modulation(x, sr):
    """The strongest envelope rate between 8 and 60 Hz (a trill, purr or buzz), as a log rate."""
    hop = int(sr * 0.002)
    e = np.sqrt(np.convolve(x * x, np.ones(hop) / hop, 'same'))[::hop]
    e = e - e.mean()
    sp = np.abs(np.fft.rfft(e * np.hanning(len(e)))) ** 2
    f = np.fft.rfftfreq(len(e), 0.002)
    band = (f >= 8) & (f <= 60)
    return np.log(f[band][int(np.argmax(sp[band]))])


def shift_distance(specs):
    """All-pairs distance: the smallest RMS difference over frequency shifts of up to SHIFT_MAX bins."""
    n, T, B = specs.shape
    best = np.full((n, n), np.inf)
    for s in range(-SHIFT_MAX, SHIFT_MAX + 1):
        a = specs[:, :, max(0, s):B + min(0, s)].reshape(n, -1)
        b = specs[:, :, max(0, -s):B - max(0, s)].reshape(n, -1)
        sq = (a * a).sum(1)[:, None] + (b * b).sum(1)[None, :] - 2 * a @ b.T
        best = np.minimum(best, np.sqrt(np.maximum(sq, 0) / a.shape[1]))
    return best


def main():
    out = sys.argv[sys.argv.index('--json') + 1] if '--json' in sys.argv else None
    man = json.load(open(os.path.join(CRIES, 'cries.json')))
    tol = LEVELS['tolerance_db']
    target = LEVELS['cats']['boki']
    bad = []
    res, specs, mods, ids = {}, [], [], []
    for fid, e in man['cries'].items():
        x, sr = sfx_stats.load(os.path.join(HERE, '..', e['file']))
        st = sfx_stats.stats(x, sr)
        res[fid] = st
        if st['peak'] > LEVELS['peak_db']: bad.append('%s peak %.1f over the ceiling' % (fid, st['peak']))
        if abs(st['rms'] - target) > tol: bad.append('%s rms %.1f off the boki level' % (fid, st['rms']))
        if st['edge'] > EDGE_MAX: bad.append('%s starts with a click (edge %.1f dB)' % (fid, st['edge']))
        if not DUR[0] <= st['dur'] <= DUR[1]: bad.append('%s is %.2f s long' % (fid, st['dur']))
        if abs(x.mean()) > 0.002: bad.append('%s has a DC offset' % fid)
        specs.append(logf_spectrogram(x, sr))
        mods.append(modulation(x, sr))
        ids.append(fid)
    mods = np.array(mods)
    dist = shift_distance(np.array(specs)) + MOD_WEIGHT * np.abs(mods[:, None] - mods[None, :])
    line = np.array([man['cries'][i]['line'] for i in ids])
    same = line[:, None] == line[None, :]
    off = ~np.eye(len(ids), dtype=bool)
    within = dist[same & off]
    between = dist[~same]
    ratio = within.mean() / between.mean()
    np.fill_diagonal(dist, np.inf)
    multi = [i for i in range(len(ids)) if (same[i] & off[i]).any()]
    nn_share = np.mean([same[i, int(np.argmin(dist[i]))] for i in multi])
    twin = NEAR_TWIN * within.mean()
    pairs = sorted((dist[i, j], ids[i], ids[j])
                   for i in range(len(ids)) for j in range(i + 1, len(ids)) if not same[i, j])
    twins = [p for p in pairs if p[0] < twin]
    print('cries %d  lines %d  dur %.2f-%.2f s  rms %.1f..%.1f dBFS  peak max %.1f  edge max %.1f dB' % (
        len(ids), len(set(line)), min(s['dur'] for s in res.values()), max(s['dur'] for s in res.values()),
        min(s['rms'] for s in res.values()), max(s['rms'] for s in res.values()),
        max(s['peak'] for s in res.values()), max(s['edge'] for s in res.values())))
    print('family: within-line mean %.3f  between-line mean %.3f  ratio %.2f (max %.2f)' % (
        within.mean(), between.mean(), ratio, FAMILY_MAX))
    print('nearest cry is a line-mate for %.0f%% of multi-stage Boki (min %.0f%%)' % (
        nn_share * 100, NEIGHBOUR_MIN * 100))
    print('unrelated near-twins (under %.3f): %d' % (twin, len(twins)))
    for d, a, b in pairs[:5]:
        print('  closest unrelated pair %s / %s  %.3f' % (a, b, d))
    if ratio > FAMILY_MAX: bad.append('line-mates are not close enough (ratio %.2f)' % ratio)
    if nn_share < NEIGHBOUR_MIN: bad.append('too few nearest neighbours are line-mates (%.0f%%)' % (nn_share * 100))
    bad += ['%s and %s are near twins (%.3f)' % (a, b, d) for d, a, b in twins]
    for b in bad:
        print('FAIL', b)
    if out:
        summary = {'within': float(within.mean()), 'between': float(between.mean()), 'nn_share': float(nn_share),
                   'twins': len(twins)}
        json.dump({'files': res, 'summary': summary}, open(out, 'w'), indent=1)
    print('CRIES %s, failures: %d' % ('ok' if not bad else 'FAIL', len(bad)))
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
