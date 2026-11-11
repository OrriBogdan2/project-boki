"""Builds the owner's listening page for the Boki cries: tools/cries_preview/index.html, one self-contained
file (every cry embedded as base64 ogg via ffmpeg), grouped by evolution line in stage order, with a play
button per Boki and a "play line" button per row. Showcase lines sit at the top.

    python3 tools/gen_boki_cries.py && python3 tools/cries_preview.py
"""
import base64, json, os, subprocess, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
CRIES = os.path.join(HERE, '..', 'audio', 'cries')
OUT = os.path.join(HERE, 'cries_preview', 'index.html')
# lines that show the family idea best: a vocal starter, a glassy one, a buzzy bug, an echoing Sound line,
# the dark dragon pseudo-legendary, and the ten-form branching egg line
SHOWCASE = ['Vespyx', 'Prismander', 'Mumblet', 'Tootle', 'Zipling', 'Ermink']

HEAD = """<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Boki cries</title><style>
body{font-family:system-ui,sans-serif;margin:0;padding:12px;background:#f6f3ec;color:#222}
h1{font-size:20px;margin:6px 0 2px}h2{font-size:15px;margin:18px 0 6px;color:#555}p{margin:4px 0 10px;font-size:13px;color:#555}
.line{background:#fff;border-radius:10px;padding:8px 10px;margin:8px 0;box-shadow:0 1px 2px #0002}
.head{display:flex;align-items:center;gap:10px;margin-bottom:6px}.head b{font-size:15px}.head small{color:#777}
.row{display:flex;flex-wrap:wrap;gap:6px}
.boki{display:flex;align-items:center;gap:6px;background:#f1ede4;border-radius:8px;padding:5px 8px;font-size:13px}
.boki.on{background:#ffe9a8}.boki small{color:#777}
button{font-size:14px;border:0;border-radius:6px;padding:5px 9px;background:#3a6ea5;color:#fff;cursor:pointer}
button.all{background:#5a8f3c}.b1{border-left:4px solid #9bd}.b2{border-left:4px solid #68a}.b3{border-left:4px solid #246}
</style></head><body><h1>Boki cries</h1>
<p>One voice per evolution line: first stage high, short and squeaky; middle fuller; final low, long and rich. Branch forms bend the last note and carry their own type's tint.</p>
"""
SCRIPT = """<script>
const S=%s;let cur=null,chain=null;
function play(id,el){if(cur){cur.pause();}if(chain){clearTimeout(chain);chain=null;}
 document.querySelectorAll('.on').forEach(e=>e.classList.remove('on'));
 cur=new Audio('data:audio/ogg;base64,'+S[id]);if(el)el.classList.add('on');cur.onended=()=>{if(el)el.classList.remove('on')};cur.play();return cur;}
function playLine(ids){let i=0;const step=()=>{if(i>=ids.length)return;const el=document.getElementById('b_'+ids[i]);const a=play(ids[i],el);i++;a.onended=()=>{el.classList.remove('on');chain=setTimeout(step,180)};};
 if(cur){cur.pause();}if(chain){clearTimeout(chain);}step();}
</script></body></html>"""


def ogg_b64(wav, tmp):
    ogg = os.path.join(tmp, 'c.ogg')
    args = ['ffmpeg', '-v', 'error', '-y', '-i', wav, '-c:a', 'libvorbis', '-q:a', '1', '-ar', '22050', '-ac', '1', ogg]
    subprocess.run(args, check=True)
    return base64.b64encode(open(ogg, 'rb').read()).decode()


def order(members, cries):
    """Stage order; a branch form sits right after its parent stage, branches grouped by letter."""
    return sorted(members, key=lambda i: (cries[i]['stage'], cries[i]['branch']))


def card(fid, e):
    label = '%d/%d' % (e['stage'], e['stages']) + (e['branch'] if e['branch'] else '')
    tag = '<span class="boki b%d" id="b_%s"><button onclick="play(\'%s\',this.parentNode)">&#9654;</button>'
    text = '%s <small>%s · %s</small></span>' % (e['display_name'], label, e['types'])
    return tag % (min(3, e['stage']), fid, fid) + text


def row(line, members, cries):
    ids = order(members, cries)
    cards = ''.join(card(i, cries[i]) for i in ids)
    voice = cries[ids[0]]['voice']
    motif = ' '.join('%+d' % n for n in cries[ids[0]]['motif'])
    head = '<div class="head"><button class="all" onclick="playLine(%s)">&#9654; play line</button>' % json.dumps(ids)
    head += '<b>%s</b><small>%s · motif %s</small></div>' % (line, voice, motif)
    return '<div class="line">%s<div class="row">%s</div></div>\n' % (head, cards)


def main():
    man = json.load(open(os.path.join(CRIES, 'cries.json')))
    cries = man['cries']
    sounds = {}
    with tempfile.TemporaryDirectory() as tmp:
        for fid, e in cries.items():
            sounds[fid] = ogg_b64(os.path.join(HERE, '..', e['file']), tmp)
    html = [HEAD, '<h2>Showcase</h2>']
    html += [row(l, man['lines'][l], cries) for l in SHOWCASE]
    html.append('<h2>All lines (%d)</h2>' % len(man['lines']))
    html += [row(l, m, cries) for l, m in man['lines'].items() if l not in SHOWCASE]
    html.append(SCRIPT % json.dumps(sounds, separators=(',', ':')))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, 'w').write(''.join(html))
    print('wrote %s (%.1f MB, %d cries)' % (OUT, os.path.getsize(OUT) / 1e6, len(sounds)))


if __name__ == '__main__':
    main()
