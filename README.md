# VFX quality strips (not for merge)

Tenzo (dolm), rows lmb hold rmb / dash e r, 3x3 frames each, half scale.

- before_dolm.png: main d255acbee (jobq vfxq-before-dolm)
- after_dolm.png: ext/vfx-quality-base (jobq vfxq-after-dolm 20261108-181952-16365)

Motley (ostra), one strip per changed part (rmb = Shard Snap, e = Brimseed, r = Nightwell on X), 3x3 frames each,
from tools/vfx_reel/ostra.gd:

- before_ostra_{rmb,e,r}.png: ext/vfx-quality-base + the reel script (jobq vfxq-ostra-abil-before 20261108-202203-01297)
- after_ostra_{rmb,e,r}.png: ext/vfx-ostra-abilities 7c25200dc (jobq vfxq-ostra-abil-after 20261108-204434-01952)

Albert (bulwark), one strip per changed part (rmb = the aegis, e = Mending Ground, r = Faultline on X), 3x3 frames each:

- before_bulwark_{rmb,e,r}.png: main d255acbee (jobq vfxq-before-bulwark 20261108-180332-10750)
- after_bulwark_{rmb,e,r}.png: ext/vfx-bulwark 751593c7e (jobq vfxq-after-bulwark 20261108-225956-21016)

Kael (juggernaut), X (Gilded Riposte), 3x3 frames at 0.2 0.42 0.77 0.86 0.89 0.93 0.98 1.1 2.0s (the cleave lands
at ~0.85s; the 0.89s frame shows the crescent), both rendered on worker rp1-1 with the same reel times:

- before_juggernaut_r.png: ext/vfx-quality-base 9a9bb3b79 + the reel times (jobq kael-polish-before-r2 20261108-230148-18573)
- after_juggernaut_r.png: ext/vfx-kael-polish 2500aca86 (jobq kael-polish-after-r2 20261108-225704-00644)
