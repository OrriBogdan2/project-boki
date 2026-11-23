#!/bin/bash
# frames/<clip>/f%04d.png -> <clip>.mp4 + <clip>.gif, then INDEX.html
R=/home/boki/art-review/uthana-1110; cd $R
for d in frames/*/; do c=$(basename $d)
  ffmpeg -loglevel error -y -framerate 30 -i $d/f%04d.png -c:v libx264 -pix_fmt yuv420p -crf 23 $c.mp4
  ffmpeg -loglevel error -y -framerate 30 -i $d/f%04d.png -vf "fps=15,scale=640:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=96[p];[b][p]paletteuse" $c.gif
done
python3 - <<'PY'
import os,html
R='/home/boki/art-review/uthana-1110'
notes={}
if os.path.exists(R+'/notes.tsv'):
  for l in open(R+'/notes.tsv'):
    k,v=l.rstrip('\n').split('\t',1); notes[k]=v
cs=sorted(f[:-4] for f in os.listdir(R) if f.endswith('.mp4'))
cells=''.join(f'<figure><video src="{c}.mp4" autoplay loop muted playsinline></video><figcaption><b>{c}</b><br>{html.escape(notes.get(c,""))}</figcaption></figure>' for c in cs)
open(R+'/INDEX.html','w').write(f'''<!doctype html><meta charset=utf-8><title>Uthana pilot 2026-11-10</title>
<style>body{{background:#1b1c20;color:#ddd;font:14px sans-serif}}main{{display:grid;grid-template-columns:repeat(auto-fill,minmax(480px,1fr));gap:12px}}video{{width:100%}}figure{{margin:0}}</style>
<h1>Uthana pilot: left = our current clip, right = Uthana motion remapped onto our Skeleton3D</h1><p>Albert = breaker.glb, Lace = hem.glb. Report: docs/UTHANA_PILOT.md on ext/anim-uthana-pilot.</p><main>{cells}</main>''')
print(len(cs),'clips')
PY
