"""Draws sounds as a review sheet: one row per sound, waveform (left) and spectrogram (right), with its
level numbers (tools/sfx_stats.py). For judging a sound set by eye and for READY screenshots.

    python3 tools/sfx_look.py out.png audio/gunslinger_*.wav audio/vn_*.wav
"""
import sys
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from sfx_stats import load, stats


def main():
    out, paths = sys.argv[1], sorted(set(sys.argv[2:]))
    fig, axes = plt.subplots(len(paths), 2, figsize=(12, 1.25 * len(paths) + 0.4), squeeze=False,
                             gridspec_kw={'width_ratios': [1, 2]})
    for row, p in zip(axes, paths):
        x, sr = load(p)
        s = stats(x, sr)
        t = np.arange(len(x)) / sr
        row[0].plot(t, x, lw=0.4, color='#2a6')
        row[0].set_ylim(-1, 1)
        row[0].set_xlim(0, max(t[-1], 0.05))
        name = p.split('/')[-1][:-4]
        row[0].set_title('%s  pk %.1f  rms %.1f  %.2fs' % (name, s['peak'], s['rms'], s['dur']), fontsize=7, loc='left')
        row[1].specgram(x + 1e-9, NFFT=512, Fs=sr, noverlap=384, cmap='magma', vmin=-120)
        row[1].set_ylim(0, 12000)
        for a in row:
            a.tick_params(labelsize=5)
    fig.tight_layout()
    fig.savefig(out, dpi=110)
    print('SFXLOOK %d sounds -> %s' % (len(paths), out))


if __name__ == '__main__':
    main()
