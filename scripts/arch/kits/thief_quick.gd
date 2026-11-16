class_name ThiefQuick
extends RefCounted
## Sable's quick hands after a Vault (the source's Cartwheel into faster Arcslingers, docs/heroes/thief.md). An
## empowering Vault opens `quick_window` s: a bolt thrown in it (the empowered one) starts a run in which it and
## the next bolts leave `quick_k` x the usual interval apart, `quick_n` quick intervals in all. A bolt that
## doesn't follow in time ends the run. A bolt still cooling as she flips is cut to the quick interval. The tell
## is hers, no floating UI: the bolts that came quick carry the cartwheel's cyan (ThiefKit._bolt).
## Owned by ThiefKit (_vaulted, _tick, _bolt); numbers in the dash def (content/archetypes/thief.json).

const GRACE := 0.2  # s past a quick interval that the next bolt may still come before the run ends

var open_t := 0.0  # s left for a bolt to start or keep the run
var left := 0  # quick intervals left in the run
var cut := false  # the last bolt's interval was cut: the next one comes quick
var quick_bolts := 0  # (tests, demo)


## An empowering Vault: the window opens.
func vaulted(h: Hunter, dd: Dictionary) -> void:
	open_t = float(dd["quick_window"])
	left = int(dd["quick_n"])
	cut = false
	h.fire_cd = minf(h.fire_cd, float(h.wpn.get("rate", 0.45)) * float(dd["quick_k"]))


func tick(dt: float) -> void:
	open_t = maxf(0.0, open_t - dt)


## A bolt just left (h.fire_cd is its interval): cuts that interval while the run lasts. True when this bolt came
## quick itself (the tell).
func bolt(h: Hunter, dd: Dictionary) -> bool:
	var came_quick := cut and open_t > 0.0
	cut = open_t > 0.0 and left > 0
	if cut:
		left -= 1
		h.fire_cd *= float(dd["quick_k"])
		open_t = h.fire_cd + GRACE
	if came_quick:
		quick_bolts += 1
	return came_quick
