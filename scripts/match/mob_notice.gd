class_name MobNotice
extends RefCounted
## A monster's notice cue: when one goes from idle to chasing (it saw you, or you hit it) its kind's own
## voice plays once from where it stands, pitched as a short alert (small kinds high, heavy kinds low).
## A camp waking is one cue: a monster stays quiet while a camp-mate is already awake or cued in the last CAMP_GAP s.
## Sfx.play does the distance falloff; on clients the cue comes from the synced state (Match's mob snapshot).

## kind -> [dB, pitch]
const CUE := {"skitter": [-8.0, 1.35], "spitter": [-8.0, 1.2], "brute": [-6.0, 0.7], "warden": [-4.0, 0.6],
	"bomber": [-8.0, 0.8], "sentinel": [-6.0, 0.65], "glimmer": [-8.0, 1.3]}
const CAMP_GAP := 3.0       # s of match time: a camp that settles and wakes again within this stays quiet
const CAMP_R := 5.0         # m between camp spots: monsters this close share a camp (a camp spreads 3.6 m)

## Called on the idle -> chase change. Returns whether the cue played.
static func woke(mob: Mob) -> bool:
	if not CUE.has(mob.mkind):
		return false
	var now: float = mob.m.time
	for o: Mob in mob.m.mobs:
		if o.dead or o.camp.distance_to(mob.camp) >= CAMP_R:
			continue
		if now - o.noticed_at < CAMP_GAP or (o != mob and o.st != "idle"):
			return false
	mob.noticed_at = now
	var c: Array = CUE[mob.mkind]
	mob.m.sfx("v_" + mob.mkind, mob.pos, c[0], c[1])
	return true
