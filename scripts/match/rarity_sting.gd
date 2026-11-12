class_name RaritySting
extends RefCounted
## A short sting for a Boki that is not common (docs/AUDIO.md "Rarity stings"): `rarity_rare` for a rare
## species (Data.is_rare), `rarity_very_rare` for a shimmer. Played when one comes into sight in a match,
## when it is claimed (Capture) and when it hatches at home (EggHatch). Quieter than the catch chime.
## In a match each Boki is announced once, and never while the fight music is at its loudest.

const SIGHT_M := 30.0           # m: a rare Boki in sight within this range is announced
const SCAN_S := 0.5             # s between looks at the field
const LOUD_HEAT := 0.5          # MusicDir.heat at or above this is the fight's loud part: the sting waits
const NAMES := ["", "rarity_rare", "rarity_very_rare"]
const DB := [0.0, -6.0, -4.0]   # dB under the full-scale sound, by tier: well under the scan chime

var seen := {}                  # Kin instance id -> true: announced this match
var wait := 0.0

## 0 common, 1 a rare species, 2 a shimmer.
static func tier(species: String, rec: Dictionary) -> int:
	if bool(rec.get("shimmer", false)):
		return 2
	return 1 if Data.is_rare(species) else 0

## A sting for this tier, flat (not placed in the world): nothing for a common Boki.
static func play(t: int) -> void:
	if t > 0:
		Sfx.play(NAMES[t], null, DB[t], 0.0)

## The claim: a rare Boki just caught, unless the fight is at its loudest.
static func claim(m: Match, k: Kin) -> void:
	if m.music_dir == null or m.music_dir.heat < LOUD_HEAT:
		play(tier(k.species, k.rec))

## Every SCAN_S: announce the best new rare Boki in sight. `heat` is the fight music's level (0..1);
## while it is loud nothing is marked seen, so the Boki is announced once the fight eases.
func tick(m: Match, dt: float, heat: float) -> void:
	wait -= dt
	if wait > 0.0 or heat >= LOUD_HEAT:
		return
	wait = SCAN_S
	var p: Hunter = m.player
	var best := 0
	for k in m.kins:
		if k.dead or k.team == p.team or k.unseen or seen.has(k.get_instance_id()):
			continue
		var t := tier(k.species, k.rec)
		if t == 0 or p.flat_dist(k) > SIGHT_M or not m.sees(p.team, k.pos):
			continue
		seen[k.get_instance_id()] = true
		best = maxi(best, t)
	play(best)
