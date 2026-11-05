"""Measures sound files with ffmpeg's EBU R128 meter, for a mix judged by numbers (no ears on the build box).

    python3 tools/sfx_loudness.py <file or glob-prefix>...       e.g. audio/jug_  or  reel.wav

Each row: M max (LUFS, the loudest 400 ms; short sounds are padded so the window can fill), true peak (dBTP), length (s).
"""
import glob, re, subprocess, sys


def measure(path):
    cmd = ['ffmpeg', '-hide_banner', '-nostats', '-loglevel', 'verbose', '-i', path, '-af', 'apad=pad_dur=0.5,ebur128=peak=true:framelog=verbose', '-f', 'null', '-']
    log = subprocess.run(cmd, capture_output=True, text=True).stderr
    moments = [float(v) for v in re.findall(r'\bM:\s*(-?[\d.]+)', log)]
    peak = re.findall(r'Peak:\s*(-?[\d.]+|-inf)\s*dBFS', log)
    times = re.findall(r't:\s*([\d.]+)\s+TARGET', log)
    return max(moments or [-120.0]), float(peak[-1]) if peak and peak[-1] != '-inf' else -120.0, float(times[-1]) - 0.5 if times else 0.0


def main():
    rows = []
    for arg in sys.argv[1:]:
        for path in sorted(glob.glob(arg + '*.wav') + glob.glob(arg)):
            if not path.endswith('.import'):
                rows.append((path, *measure(path)))
    seen = set()
    print('%-34s %7s %7s %6s' % ('file', 'M max', 'TP', 'secs'))
    for path, m, tp, secs in rows:
        if path not in seen:
            seen.add(path)
            print('%-34s %7.1f %7.1f %6.2f' % (path.rsplit('/', 1)[-1], m, tp, secs))


if __name__ == '__main__':
    main()
