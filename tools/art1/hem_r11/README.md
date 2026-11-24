# Lace (Hem) r11 tools
- `yawlock.py IN OUT clip=Idle head_keep=0.3` : S1 idle yaw lock (Hips world yaw locked to its first key, head swing x0.3).
- `rig11.py IN OUT mode=A|B [tex=PNG] [k=v]` (run from the repo root, `blender -b -P ... --`): S3 weights + per-frame SkirtSw clearance solve.
  mode=B live bell (thigh 0.3 / back shin 0.25, live crouch keys kept via keep=Crouch);
  mode=A r10 slit skirt (thigh share by height, 25 deg blend, back shin share, slit-edge pin, hip fit, margin 0.15).
  `tex=` also runs `liner11.py` in the same session: Meshy retexture on skirt-meshy, inner twin faces + hidden liner shell solid wine,
  liner faces not covered by the outer cloth or touching the body in any sampled frame deleted.
- `partlock.py LIVE CAND` : non-skirt primitives equal to live (nearest-vertex distance, material names).
- `clipcheck11.py GLB 8 [slit=1]` (blender): leg verts outside the skirt per frame; `hipyaw.py`, `stretch3.py`, `skirtpix.py`: other numbers.
- `rtx11.py`, `texstat.py`, `outuv.py`: Meshy retexture of task 01a20a5f and its measurement under the outward faces.
Numbers and sheets: /home/boki/gens/lace-r11 (hetzner).
