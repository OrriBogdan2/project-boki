"""ElevenLabs trial for Boki cries: 4 base-cry candidates per evolution line, stage variants made locally.

    python3 tools/el_cries.py gen                 # API: 4 candidates per line (skips files that exist)
    python3 tools/el_cries.py stages c1 c2 c3     # best candidate number per line, in LINES order
    python3 tools/el_cries.py proc DIR            # encodes the procedural cries (audio/cries of ext/boki-cries) for the page
    python3 tools/el_cries.py html                # builds cries_preview/el_ab.html

Needs numpy, scipy, ffmpeg. The key is read from ELEVENLABS_API_KEY (source ~/.config/boki/secrets.env), never printed.
Sound-effects endpoint only; every call is counted in cries_preview/el/calls.txt (job cap: 60).
"""
import html, json, os, subprocess, sys, urllib.request
import numpy as np
from scipy.signal import butter, resample_poly, sosfilt
from sfx_stats import stats

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'cries_preview', 'el')
SR = 44100
TARGET_RMS, CEIL = -19.0, -1.0   # content/rules/sfx_levels.json: category 'boki' RMS, peak ceiling
URL = 'https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_128'

# line id: (stage names, base-stage brief from SOUND_BRIEFS.csv, kin_v2 personality, candidate wordings)
LINES = {
    'vespyx': (['Vespyx', 'Vespox', 'Sabryx'], 'low cat growl with a quick tail-stinger click',
               'sly fox-scorpion bruiser, quick little hisses',
               ['a low cat growl with a quick sharp click at the end like a stinger', 'a fierce small predator growl, rough and raspy, ending in a dry clicking rattle',
                'a menacing feline snarl then a short hard tail-stinger click', 'a low throaty fox-cat growl with a brief insect clicking rattle']),
    'coolatee': (['Coolatee', 'Frigatee', 'Glaciatee'], 'rolling bark with a shimmering whoosh',
                 'kind, low and slow seal-manatee, icy',
                 ['a friendly seal bark rolling into a soft shimmering whoosh', 'a gentle round seal bark with an icy glassy tinkle after it',
                  'a happy low rolling bark of a sea mammal with a airy shimmer tail', 'a cute chubby seal call, warm and soft, with a frosty shimmer']),
    'mothlet': (['Mothlet', 'Lunowl', 'Eclipsowl'], 'airy two-note hoot with a faint shimmer',
                'airy, teasing, dramatic owl-moth',
                ['an airy two-note owl hoot, second note higher, with a faint magical shimmer', 'a soft teasing owl hoo-hoo with a breathy whisper and faint sparkle',
                 'a small mysterious night owl double hoot, airy and hollow, with a faint wing flutter shimmer', 'a dreamy ghostly two-tone hoot of a moth-owl, breathy with a quiet shimmer']),
}
CAND = [(0.9, 0.3), (1.1, 0.5), (1.3, 0.7), (1.0, 0.5)]   # (duration_seconds, prompt_influence)
SUFFIX = ' Single creature vocalisation, dry, no music, no speech, no words.'


def decode(path_or_bytes):
    src = ['-i', path_or_bytes] if isinstance(path_or_bytes, str) else ['-i', 'pipe:0']
    inp = None if isinstance(path_or_bytes, str) else path_or_bytes
    r = subprocess.run(['ffmpeg', '-v', 'error', *src, '-f', 'f32le', '-ac', '1', '-ar', str(SR), 'pipe:1'], input=inp, capture_output=True, check=True)
    return np.frombuffer(r.stdout, dtype=np.float32).astype(float)


def level(x):
    """hpf, 20 ms edge fades, RMS to the game's SFX level over the active part, soft-knee ceiling."""
    x = sosfilt(butter(2, 35 / (SR / 2), 'high', output='sos'), x)
    fi, fo = int(SR * 0.002), int(SR * 0.03)
    x[:fi] *= np.linspace(0, 1, fi); x[-fo:] *= np.linspace(1, 0, fo)
    act = np.abs(x) > np.abs(x).max() * 0.01
    x = x * 10 ** (TARGET_RMS / 20) / (np.sqrt(np.mean(x[act] ** 2)) or 1.0)
    c = 10 ** (CEIL / 20); k = c * 0.7; m = np.abs(x)
    return np.where(m > k, np.sign(x) * (k + (c - k) * np.tanh((m - k) / (c - k))), x)


def save(name, x):
    x = level(x)
    wav = os.path.join(OUT, name + '.wav')
    pcm = (np.clip(x, -1, 1) * 32767).astype('<i2').tobytes()
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 's16le', '-ar', str(SR), '-ac', '1', '-i', 'pipe:0',
                    '-c:a', 'libvorbis', '-q:a', '4', os.path.join(OUT, name + '.ogg')], input=pcm, check=True)
    return stats(x, SR)


def load(name): return decode(os.path.join(OUT, name + '.ogg'))


def calls_used():
    p = os.path.join(OUT, 'calls.txt')
    return int(open(p).read()) if os.path.exists(p) else 0


def gen():
    key = os.environ['ELEVENLABS_API_KEY']
    for line, (_, brief, pers, words) in LINES.items():
        for i, (w, (dur, infl)) in enumerate(zip(words, CAND), 1):
            if os.path.exists(os.path.join(OUT, f'{line}_c{i}.ogg')): continue
            if calls_used() >= 20: sys.exit('call guard hit')
            body = json.dumps({'text': w + SUFFIX, 'duration_seconds': dur, 'prompt_influence': infl}).encode()
            req = urllib.request.Request(URL, body, {'xi-api-key': key, 'Content-Type': 'application/json'})
            with urllib.request.urlopen(req, timeout=120) as r: audio = r.read()
            n = calls_used() + 1
            open(os.path.join(OUT, 'calls.txt'), 'w').write(str(n))
            print(line, i, save(f'{line}_c{i}', decode(audio)))


def shift(x, ratio):
    """Speed and pitch together (ratio > 1: higher and shorter)."""
    from fractions import Fraction
    f = Fraction(ratio).limit_denominator(100)
    return resample_poly(x, f.denominator, f.numerator)


def delay_mix(a, b, d, g):
    n = max(len(a), len(b) + int(SR * d)); o = np.zeros(n)
    o[:len(a)] += a; o[int(SR * d):int(SR * d) + len(b)] += g * b
    return o


def stages(picks):
    for (line, (names, *_)), c in zip(LINES.items(), picks):
        base = load(f'{line}_{c}')
        baby = shift(base, 1.4)
        final = shift(base, 0.78)
        final = delay_mix(final, shift(base, 0.55), 0.09, 0.45)   # one extra, deeper layer
        final = sosfilt(butter(2, 6500 / (SR / 2), 'low', output='sos'), final)
        for tag, x in (('s1', baby), ('s2', base), ('s3', final)):
            print(line, tag, save(f'{line}_{tag}', x))


def proc(d):
    for names in (n for n, *_ in LINES.values()):
        for nm in names:
            src = os.path.join(d, ('glaivyx' if nm == 'Sabryx' else nm.lower()) + '.wav')
            subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', src, '-c:a', 'libvorbis', '-q:a', '4', os.path.join(OUT, f'proc_{nm.lower()}.ogg')], check=True)


def build_html():
    rows = ['<!doctype html><meta charset="utf-8"><title>Boki cries: ElevenLabs A/B</title>',
            '<style>body{font:15px sans-serif;max-width:900px;margin:1em auto}td{padding:4px 10px}h2{margin-top:1.6em}</style>',
            '<h1>Boki cries: ElevenLabs A/B</h1><p>Candidates are raw ElevenLabs sound-effects output (normalised). Stages are made locally from the picked candidate '
            '(s1 baby: pitch x1.4, shorter; s2 = the candidate; s3 final: pitch x0.78, longer, one extra deeper layer). '
            'Procedural rows: tools/gen_boki_cries.py output (ext/boki-cries), same stages, already levelled to the same category.</p>']
    for line, (names, brief, pers, words) in LINES.items():
        rows.append(f'<h2>{html.escape(" → ".join(names))}</h2><p>Brief (stage 2): <b>{html.escape(brief)}</b><br>Personality: {html.escape(pers)}</p><table>')
        for i, w in enumerate(words, 1):
            a = f'el/{line}_c{i}.ogg'
            if os.path.exists(os.path.join(OUT, f'{line}_c{i}.ogg')):
                rows.append(f'<tr><td>candidate {i}</td><td><audio controls preload="none" src="{a}"></audio></td><td>{html.escape(w)}</td></tr>')
        if os.path.exists(os.path.join(OUT, f'{line}_s1.ogg')):
            for tag, nm in zip(('s1', 's2', 's3'), names):
                rows.append(f'<tr><td>stage {tag[1]}: {html.escape(nm)}</td><td><audio controls preload="none" src="el/{line}_{tag}.ogg"></audio></td><td></td></tr>')
        for nm in names:
            rows.append(f'<tr><td>procedural: {html.escape(nm)}</td><td><audio controls preload="none" src="el/proc_{nm.lower()}.ogg"></audio></td><td></td></tr>')
        rows.append('</table>')
    open(os.path.join(HERE, 'cries_preview', 'el_ab.html'), 'w').write('\n'.join(rows))


if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else ''
    {'gen': gen, 'html': build_html, 'stages': lambda: stages(sys.argv[2:]), 'proc': lambda: proc(sys.argv[2])}.get(cmd, lambda: sys.exit(__doc__))()
