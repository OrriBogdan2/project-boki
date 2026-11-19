class_name ExpeditionTips
extends RefCounted
## One-time tips for the first moments of an expedition, shown through Match._tip (once per save, keys
## "blight", "camp", "deathbox", "wallkick" and "keg" in Save.d.tutorial): the Blight's ring closing in on
## you, your first monster kill (yours or your Boki's), the first deathbox you can loot, the first time you
## jump into a wall a kick would climb (out of a fight, never once you have kicked on your own), and the first
## powder keg within KEG_M (crates, pots and barrels break in one hit; only kegs explode). Match._tips already
## keeps them out of the tutorial match and the Training Grounds.

const BLIGHT_M := 20.0  # the closing ring's edge this close (m), or you out in it, brings the Blight tip
const KEG_M := 8.0  # a powder keg this close (m) brings the keg tip (only kegs explode)


## The next tip that is due for the local player and not yet seen on this save, as [save key, line], or [].
static func next(m: Match) -> Array:
	var p := m.player
	var seen: Dictionary = Save.d["tutorial"]
	var tr := Heart.tide_r(m)
	var near := tr > 0.0 and m.heart.site != Vector3.INF and p.flat_dist(m.heart.site) > tr - BLIGHT_M
	if not seen.has("blight") and near:
		return ["blight", "The Blight is closing. Move toward the Heart."]
	if not seen.has("camp") and int(p.stats.get("mobs", 0)) > 0:
		return ["camp", "Monsters give XP. Hits on Hunters build armour."]
	if not seen.has("deathbox") and not m.interact.is_empty() and m.interact["kind"] == "loot":
		var cap := Settings.key_cap("interact")
		return ["deathbox", "A fallen Hunter's deathbox: press %s to take their gear" % cap]
	if not seen.has("keg") and m.interact.is_empty() and _keg_near(m, p):   # one prompt at a time
		var fire := Settings.key_cap("fire")
		return ["keg", "Crates, pots and barrels break in one hit. Only kegs explode: hit one from afar (%s)." % fire]
	if not seen.has("wallkick"):
		if int(p.stats.get("wall_kicks", 0)) > 0:
			seen["wallkick"] = true      # it found the kick on its own: nothing to teach
		elif _at_kick_wall(p) and not (m.hud and m.hud.in_fight()):
			return ["wallkick", "Press %s again against the wall to kick off" % Settings.key_cap("jump")]
	return []


## An unbroken, unlit powder keg within KEG_M of the player.
static func _keg_near(m: Match, p: Hunter) -> bool:
	var kegs := Breakables.near(m.breaks, p.pos, KEG_M).filter(func(b: Dictionary): return b["kind"] == "keg")
	return not kegs.is_empty()


## Airborne against a wall the ledge rise won't take you up, within a hop's climb: a jump press here would kick.
static func _at_kick_wall(p: Hunter) -> bool:
	var in_reach: bool = p.pos.y <= p.last_gy + WallMoves.HOP_CLIMB_CAP
	return not p.grounded and p.wall_touch_t > 0.0 and p.lfloat.is_empty() and not p.mantling() and in_reach
