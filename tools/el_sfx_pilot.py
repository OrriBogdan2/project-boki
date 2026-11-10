"""ElevenLabs sound-effect pilot: two takes per gap event, levelled like our own sounds, plus an A/B page.

    set -a; . ~/.config/boki/secrets.env; set +a     # ELEVENLABS_API_KEY (never printed)
    python3 tools/el_sfx_pilot.py [--page /home/boki/art-review/sfx-1110] [--budget 0.15] [--dry]

Reads the account's remaining credits first (GET /v1/user/subscription) and stops before spending more
than `--budget` of them. Each event gets audio/el_<name>.wav and audio/el_<name>_1.wav (take convention,
so Sfx rotates them once a call site plays "el_<name>"), levelled to its category by sfx_lib.save_cat.
The raw mp3s, the levelled wavs and the current sound are copied next to index.html for listening.
--dry skips the API and runs the decode/level/page path on a synthetic click (pipeline test).
"""
import argparse, html, json, os, shutil, subprocess, sys, time, urllib.request
import numpy as np
import sfx_lib as S
import sfx_combat as C

API = 'https://api.elevenlabs.io/v1'
STYLE = ('stylized cel-shaded action game sound effect, punchy, clean, short, dry, no music, no voice, '
         'no ambience: ')
# name the call sites play now, category (content/rules/sfx_levels.json), seconds, what it should sound like
EVENTS = [
    ('hit', 'impact', 0.5, 'light melee hit landing on a creature, crisp thwack with a soft body thud'),
    ('hit_heavy', 'heavy_impact', 0.8, 'heavy weapon blow landing, deep crunchy thump with a short bass boom'),
    ('crit', 'impact', 0.7, 'critical hit, sharp bright metallic crack with a sparkly ring-out'),
    ('kill', 'impact', 0.9, 'enemy defeated, satisfying punchy pop then a short magical shimmer'),
    ('die_small', 'impact', 0.8, 'small creature vanishing in a puff, soft pop and airy poof'),
    ('die_big', 'heavy_impact', 1.4, 'large monster collapsing, heavy thud and a short rumbling dissolve'),
    ('dash', 'dash', 0.5, 'quick dodge dash, fast cloth whoosh with a light air burst'),
    ('whoosh', 'fire', 0.5, 'weapon swing through air, short clean swoosh'),
    ('pickup', 'ui', 0.5, 'item pickup, cheerful bright two-note pluck with a tiny sparkle'),
    ('level_up', 'ui', 1.5, 'level up, rising magical chime arpeggio with a warm bloom'),
    ('ab_ready', 'ui', 0.5, 'ability ready again, soft bright glassy ping'),
    ('skill', 'cast', 0.7, 'casting an ability, quick magical swell and release'),
    ('ult', 'cast', 1.5, 'ultimate ability activated, big rising energy surge ending in a punchy burst'),
    ('heal', 'cast', 1.0, 'healing spell, warm gentle rising chime with soft shimmer'),
    ('shield', 'cast', 0.8, 'magic shield raised, resonant energy hum snapping into place'),
    ('revive_done', 'cast', 1.2, 'teammate revived, hopeful bright rising chord swell'),
    ('extract_ok', 'ui', 1.2, 'successful escape, triumphant short magical whoosh upward'),
    ('ui_confirm', 'ui', 0.5, 'menu confirm, soft round wooden click with a bright tick'),
    ('ui_back', 'ui', 0.5, 'menu back, soft lower wooden click, descending'),
    ('ui_deny', 'ui', 0.5, 'menu error, short muted double buzz, gentle not harsh'),
    ('thief_swipe', 'fire', 0.5, 'quick dagger slash, thin sharp blade swish'),
    ('mage_wall', 'cast', 1.0, 'magic wall rising from the ground, crackling arcane barrier forming'),
    ('tender_knock', 'impact', 0.6, 'staff knocking a target back, hollow wooden bonk with a soft push of air'),
    ('ashwick_shield', 'cast', 0.8, 'fire shield igniting, quick roaring flame whoomp'),
    ('bulwark_click', 'ui', 0.5, 'heavy mechanical latch locking, solid metal clack'),
]


def key():
    k = os.environ.get('ELEVENLABS_API_KEY', '')
    if not k:
        sys.exit('ELEVENLABS_API_KEY not set (source ~/.config/boki/secrets.env)')
    return k


def call(path, body=None):
    req = urllib.request.Request(API + path, data=None if body is None else json.dumps(body).encode(),
                                 headers={'xi-api-key': key(), 'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def credits_left():
    s = json.loads(call('/user/subscription'))
    return s['character_limit'] - s['character_count']


def generate(prompt, seconds):
    return call('/sound-generation?output_format=mp3_44100_128',
                {'text': STYLE + prompt, 'duration_seconds': seconds, 'prompt_influence': 0.6})


def decode(path):
    """mp3 -> mono float at 44.1 kHz, leading and trailing silence trimmed."""
    trim = 'silenceremove=start_periods=1:start_threshold=-50dB,areverse,' \
           'silenceremove=start_periods=1:start_threshold=-50dB,areverse'
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-af', trim, '-ac', '1', '-ar', str(S.SR),
                          '-f', 'f32le', '-'], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(float)


def page(out, rows, before, after):
    head = ('<!doctype html><meta charset=utf-8><title>SFX pilot 11-10</title><style>body{font:14px sans-serif;'
            'margin:20px}td,th{padding:4px 10px;border-bottom:1px solid #ddd}audio{height:28px}</style>'
            f'<h1>ElevenLabs SFX pilot</h1><p>Credits left before {before}, after {after}. Variant 1/2 are '
            'levelled to the same category loudness as the current sound.</p><table><tr><th>event<th>cat'
            '<th>variant 1<th>variant 2<th>current<th>raw 1<th>raw 2')
    a = lambda f: f'<td><audio controls preload=none src="{html.escape(f)}"></audio>' if f else '<td>-'
    body = ''.join(f'<tr><td>{html.escape(r["name"])}<td>{r["cat"]}' + ''.join(a(r[k]) for k in
                   ('v1', 'v2', 'cur', 'raw1', 'raw2')) for r in rows)
    open(os.path.join(out, 'index.html'), 'w').write(head + body + '</table>')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--page', default='/home/boki/art-review/sfx-1110')
    ap.add_argument('--budget', type=float, default=0.15)
    ap.add_argument('--dry', action='store_true')
    a = ap.parse_args()
    os.makedirs(a.page, exist_ok=True)
    before = 0 if a.dry else credits_left()
    stop_at = before - int(before * a.budget)
    left, rows, made = before, [], 0
    if a.dry:
        C.OUT = a.page
    for name, cat, sec, prompt in EVENTS:
        row = {'name': name, 'cat': cat, 'v1': '', 'v2': '', 'cur': '', 'raw1': '', 'raw2': ''}
        for i, out in enumerate(('el_' + name, 'el_%s_1' % name)):
            raw = os.path.join(a.page, out + '.mp3')
            if a.dry:
                subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'lavfi', '-i', 'sine=880:d=%s' % sec,
                                '-af', 'afade=out:d=%s' % sec, raw], check=True)
            else:
                if left - (before - left) / max(1, made) < stop_at:
                    print('budget reached at', out); break
                open(raw, 'wb').write(generate(prompt, sec))
                left = credits_left()
            S.save_cat(out, decode(raw), cat)
            made += 1
            if not a.dry:
                shutil.copy(os.path.join(C.OUT, out + '.wav'), a.page)
            row['v%d' % (i + 1)], row['raw%d' % (i + 1)] = out + '.wav', out + '.mp3'
            time.sleep(0 if a.dry else 0.5)
        cur = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'audio', name + '.wav')
        if os.path.exists(cur):
            shutil.copy(cur, os.path.join(a.page, 'cur_' + name + '.wav'))
            row['cur'] = 'cur_' + name + '.wav'
        rows.append(row)
        if not row['v2']:
            break
    after = left if not a.dry else 0
    page(a.page, rows, before, after)
    json.dump({'before': before, 'after': after, 'made': [r['name'] for r in rows if r['v1']]},
              open(os.path.join(a.page, 'credits.json'), 'w'), indent=1)
    print('credits before %d after %d used %d; %d events' % (before, after, before - after, len(rows)))


if __name__ == '__main__':
    main()
