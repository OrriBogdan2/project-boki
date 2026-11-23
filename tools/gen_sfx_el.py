"""ElevenLabs sound-effects pilot (docs/SFX_PILOT.md): generates the sounds in PLAN through the
sound-generation API, trims and levels each take to its category (content/rules/sfx_levels.json) and
writes audio/<name>.wav plus <name>_1..n.wav, the names the game already loads.

    source ~/.config/boki/secrets.env
    python3 tools/gen_sfx_el.py dodge pin_loose      # generate (costs credits)
    python3 tools/gen_sfx_el.py --relevel dodge      # re-trim/level from the cached clips (free)

Cost is counted, not read (the key has no user_read): every request asks for a fixed duration, billed
at RATE credits per second, and is logged to the tally table in docs/SFX_PILOT.md before it is sent.
The run stops before the tally would pass BUDGET, and at the first 401/402/429 or quota error.
Raw clips are cached in RAW (outside the repo) so re-levelling never spends again.
"""
import json, os, re, subprocess, sys, urllib.error, urllib.request
import numpy as np
import sfx_combat as C
from sfx_lib import CATS, PEAK_DB, SR

URL = 'https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_128'
MODEL = 'eleven_text_to_sound_v3'
RATE = 40.0           # credits per second of requested duration (ElevenLabs sound-effects docs)
BUDGET = 3000.0       # credits for the whole pilot (coordinator, 11-10)
RAW = '/home/boki/art-review/sfx-1110/raw'
DOC = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'docs', 'SFX_PILOT.md')
STYLE = ('Stylized cel-shaded fantasy action game sound effect, punchy, clean, close and dry, '
         'single short one-shot, no music, no voice: ')

# name: (category, takes incl. the base file, seconds requested per take, prompt[, trim cap in seconds])
# The cap is for sounds shorter than the API's 0.5 s minimum (pin_patter plays dozens of times per Hail Wall).
# Silence put before a trimmed take, so its onset lands where the move's hit is (seconds). The Gilded
# Riposte's cut lands at strike_t (content/archetypes/juggernaut.json x.strike_t = 0.1 s), the same rule
# tools/gen_sfx_kael.py RIPOSTE_HIT follows; trim keeps 4 ms before the onset, so 0.096 s.
LEAD = {'jug_riposte': 0.096}

PLAN = {
    'dodge': ('dash', 4, 0.6,
        'a quick airy whoosh of a body sidestepping as an arrow zips past the ear, bright glassy shimmer at the '
        'end'),
    # Archer (Hem): the bow, Heavy Shot, Hail Wall, Spirit Walk, Starpiercer
    'pin_loose': ('fire', 4, 0.5,
        'a light bow releasing a slim needle-like arrow, tight string thwack and a quick airy zip'),
    'pin_loose_super': ('fire', 1, 0.8,
        'a fully drawn bow firing a supercharged arrow, deep string thump and a bright crackling streak flying '
        'away'),
    'pin_draw': ('cast', 1, 0.6, 'a wooden bow drawn back hard, loud creaking wood and a stretching string'),
    'pin_heavy_draw': ('cast', 1, 0.9,
        'a heavy longbow drawn slowly to full, deep wood creak building tension, low hum rising'),
    'pin_stage': ('cast', 1, 0.5, 'a crisp bright tick and small chime as a bow locks into its next charge stage'),
    'pin_perfect': ('cast', 1, 0.8, 'a perfect-timing reward, sparkling bright chime burst with a feathery flutter'),
    'pin_super': ('cast', 1, 0.8,
        'a bow reaching full supercharge, rising shimmering energy swell ending in a bright ping'),
    'pin_overdraw': ('cast', 1, 0.5,
        'an overdrawn bow string straining then going slack, dull wobbling twang, a letdown'),
    'pin_heavy': ('fire', 1, 0.7, 'a heavy arrow loosed from a big bow, powerful string thump and a thick whoosh'),
    'pin_heavy_hit': ('impact', 4, 0.5,
        'a heavy arrow slamming into a body and knocking it back, meaty thud with a wooden crack'),
    'pin_super_hit': ('impact', 3, 0.7,
        'an energy-charged arrow striking a target, sharp impact with a bright crackling burst'),
    'pin_hail': ('cast', 1, 0.8,
        'a volley of arrows launched skyward at once, many string snaps and rising whistles'),
    'pin_rain': ('impact', 1, 1.1,
        'a dense shower of arrows raining down and thudding into the earth in quick succession'),
    'pin_spirit': ('cast', 1, 0.9,
        'a hunter fading into spirit form, soft breathy wind swirl with a ghostly airy shimmer'),
    'pin_spirit_end': ('cast', 1, 0.7, 'a spirit form ending, a bright airy shimmer collapsing into a firm pop'),
    'pin_ult_cast': ('cast', 1, 1.0,
        'an archer calling down star power, a sustained rising celestial swell building to a resonant chime'),
    'pin_ult_nock': ('cast', 1, 0.5,
        'a glowing arrow nocked on a bow string, quick bright metallic click with a hum'),
    'pin_ult_beam': ('impact', 1, 0.8,
        'a piercing beam arrow ripping through the air, searing laser-like streak with a bright crack'),
    'pin_ult_final': ('impact', 1, 1.3,
        'the final huge star arrow, thunderous piercing blast, then a long shimmering echo that rings out'),
    'archer_thread_twang': ('signature', 4, 0.55,
        'a taut silver thread plucked hard, bright resonant twang that rings out with a buzz'),
    # Kael (juggernaut): the chain, the drop and the guard/riposte ult
    'jug_chain': ('cast', 1, 0.6,
        'a heavy iron chain hurled forward, fast rattling links unspooling with a whip crack'),
    'juggernaut_chain_bite': ('impact', 1, 0.5, 'a heavy iron hook biting into armor, sharp metal clank and crunch'),
    'jug_taut': ('impact', 1, 0.5, 'a heavy chain snapping taut, a sudden metallic yank and strain'),
    'jug_reel': ('cast', 1, 0.6, 'a heavy chain reeled in fast, ratcheting rattling links dragged back'),
    'juggernaut_chain_rattle': ('signature', 3, 0.6, 'heavy iron chain links shaken, chunky metallic jangle'),
    'jug_drop': ('cast', 1, 0.5, 'a heavy armored warrior leaping high, deep whoosh upward with an armor clank'),
    'jug_meteor': ('impact', 1, 1.4,
        'a heavy warrior crashing down from the sky with a greatsword, huge ground slam boom, rocks cracking, '
        'debris'),
    'jug_guard': ('cast', 1, 0.75,
        'a greatsword raised into a guard stance, heavy metal shing followed by a sustained low resonant hum'),
    'jug_riposte': ('impact', 1, 0.75,
        'a greatsword counter-strike after a parry, sharp blade clash ring then a heavy slash'),
    'jug_ting': ('impact', 3, 0.5, 'a greatsword blade parrying an incoming shot, bright crisp metallic ting'),
    # the other kits' main weapon (the sound heard most often)
    'bjorn_throw': ('fire', 4, 0.5, 'a heavy war hammer thrown hard, spinning whoosh with a weighty release'),
    'br_throw': ('fire', 4, 0.5, 'a chunk of rock punched forward, gritty stone crunch and a heavy whoosh'),
    'dr_shot': ('fire', 4, 0.75,
        'a stubby scattergun blast firing a fan of slugs, punchy boom with a metallic rattle'),
    'vn_rifle': ('fire', 4, 0.5, 'a compact rifle shot, sharp snappy crack with a short metallic zap'),
    'vv_bolt': ('fire', 4, 0.5, 'a magic bolt flicked from a fingertip, sparkly zappy pew with a bright fizz'),
    'os_orb': ('fire', 4, 0.5, 'a glowing lantern orb launched, soft magical whoomp and a humming whoosh'),
    'rime_shard': ('fire', 4, 0.5, 'a small ice shard fired, crisp crystalline tick and a frosty whistle'),
    'tend_ember': ('fire', 4, 0.5, 'a small ember flicked from the hand, soft crackling fire puff'),
    'dj_bolt': ('fire', 4, 0.6, 'a spinning arc bolt thrown, whirring electric zip with a crackle'),
    'lw_roar': ('fire', 4, 0.66, 'a burst of flame roaring from an open hand, whooshing fire jet'),
    'pin_patter': ('impact', 4, 0.5,
        'one small arrow striking packed dirt, a single tiny dry thock, very short', 0.2),
    # frequent impacts
    'rimewright_dart_hit': ('impact', 4, 0.5,
        'an ice dart shattering on a target, crisp icy crack with tinkling shards'),
    'dj_encore_hit': ('impact', 4, 0.5, 'a quick blade slash landing on a target, sharp slicing hit with a snap'),
    'br_boulder_hit': ('impact', 4, 0.8, 'a boulder smashing into a target, heavy rock crunch and crumbling debris'),
    'bjorn_block': ('impact', 4, 0.5, 'a shot blocked by a heavy shield, solid metallic clang with a dull thud'),
}


def tally():
    """Credits spent so far: the sum of the tally table's credit column."""
    if not os.path.exists(DOC):
        return 0.0
    return sum(float(m) for m in re.findall(r'^\| \d+ \| [^|]+ \| [\d.]+ s \| ([\d.]+) \|', open(DOC).read(), re.M))


def log(clip, secs, note):
    """Appends a row to the tally table, the last thing in docs/SFX_PILOT.md."""
    n = len(re.findall(r'^\| \d+ \|', open(DOC).read(), re.M)) + 1
    spent = tally() + secs * RATE
    with open(DOC, 'a') as f:
        f.write('| %d | %s | %.2f s | %.0f | %.0f | %s |\n' % (n, clip, secs, secs * RATE, spent, note))


def generate(clip, secs, prompt):
    if tally() + secs * RATE > BUDGET:
        sys.exit('budget: %.0f spent, %s would pass %.0f' % (tally(), clip, BUDGET))
    log(clip, secs, 'sent')
    body = json.dumps({'text': STYLE + prompt, 'duration_seconds': secs, 'prompt_influence': 0.6,
                       'model_id': MODEL}).encode()
    req = urllib.request.Request(URL, body, {'xi-api-key': os.environ['ELEVENLABS_API_KEY'],
                                             'Content-Type': 'application/json'})
    try:
        data = urllib.request.urlopen(req, timeout=120).read()
    except urllib.error.HTTPError as e:
        msg = e.read().decode(errors='replace')[:200]
        if e.code in (401, 402, 429) or 'quota' in msg.lower():
            sys.exit('stop: HTTP %d %s' % (e.code, msg))
        raise
    open(os.path.join(RAW, clip + '.mp3'), 'wb').write(data)


def decode(path):
    pcm = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-ac', '1', '-ar', str(SR), '-f', 's16le', '-'],
                         capture_output=True, check=True).stdout
    return np.frombuffer(pcm, dtype=np.int16).astype(float) / 32768.0


def trim(x, max_s):
    """Cuts the lead-in silence (keeping 4 ms before the onset) and the tail once its 20 ms RMS stays
    40 dB under its loudest, capped at max_s seconds, then fades the last 60 ms out."""
    pk = np.max(np.abs(x))
    a = max(0, np.nonzero(np.abs(x) > pk * 0.03)[0][0] - C.N(0.004))
    w = C.N(0.02)
    env = np.sqrt(np.convolve(x * x, np.ones(w) / w, 'same'))
    b = min(np.nonzero(env > env.max() * 0.01)[0][-1] + C.N(0.04), a + C.N(max_s), len(x))
    y = x[a:b].copy()
    f = min(len(y) // 3, C.N(0.06))
    y[-f:] *= 0.5 + 0.5 * np.cos(np.pi * np.arange(f) / f)
    return y


def build(name, fresh):
    cat, n, secs, prompt = PLAN[name][:4]
    cap = PLAN[name][4] if len(PLAN[name]) > 4 else secs
    for i in range(n):
        clip = name if i == 0 else '%s_%d' % (name, i)
        raw = os.path.join(RAW, clip + '.mp3')
        if fresh and not os.path.exists(raw):
            generate(clip, secs, prompt)
        if not os.path.exists(raw):
            continue
        x = decode(raw)
        if np.max(np.abs(x)) < 0.01:          # the API sometimes returns silence: set it aside
            os.rename(raw, raw + '.silent')
            print('silent:', clip)
            continue
        y = np.concatenate([np.zeros(C.N(LEAD.get(name, 0.0))), trim(x, cap)])  # level() skips silence
        C.save(clip, y, rms_db=CATS[cat], peak_db=PEAK_DB)


if __name__ == '__main__':
    os.makedirs(RAW, exist_ok=True)
    args = sys.argv[1:]
    relevel = '--relevel' in args
    for a in [a for a in args if not a.startswith('--')]:
        build(a, not relevel)
    print('tally: %.0f / %.0f credits' % (tally(), BUDGET))
