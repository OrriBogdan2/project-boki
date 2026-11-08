# VFX quality strips: Lace (archer), before/after (not for merge)

Before: jobq `vfxq-before-archer` (20261108-180332-30891, main d255acbee). After: jobq `vfxq-after-archer-2`
(20261108-213129-03140, ext/vfx-archer c941941f0). `godot --hero-vfx-reel --reel-hero=archer`, one sheet per part.
The after reel ran on a different GPU worker (rp1), whose grade renders the grass yellow; compare the effects, not
the ground. Changed parts: lmb, super, miss, heavy, r, e, string, dash (all recoloured to orchid).
