class_name MapDetail
extends RefCounted
## What the minimap shows (the rule: only what's needed now). On the ground it
## carries the DEFAULT icon kinds; every DETAIL kind appears while you hold Tab or the map key, while you
## ride in (the whole map is the plan), or once it matters (an awake lair, a scouted cache, a lit
## beacon, the nearest exit). The full map (FullMap) always shows everything. Team colours are kept.
## tools/minimap_check.gd counts these lists, so a new minimap icon has to pick a kind here.

const ICON_R := 5.5           # px: the one size rule, the outer radius of every minimap icon
const DEFAULT := ["you", "squad", "boki", "exit", "blight", "ping"]
const DETAIL := ["place", "train", "far_exit", "lair", "cache", "beacon", "rival_box", "ship", "bounty", "ally"]

## Holding Tab (the scoreboard key) or the map key.
static func holding() -> bool:
	return Input.is_action_pressed("scores") or Input.is_action_pressed("map")

## Is an icon of this kind drawn? `hold` is holding() or riding in; `matters` is the kind's own reason to show.
static func shows(kind: String, hold: bool, matters := false) -> bool:
	return hold or matters or kind in DEFAULT

## The exit nearest the player, or {} (the default minimap names that one, plus the squad's own).
static func nearest_exit(m: Match) -> Dictionary:
	var best := {}
	if m.exits == null or m.player == null:
		return best
	var bd := INF
	for x in m.exits.list:
		var d: float = m.player.flat_dist(x["pos"])
		if d < bd:
			bd = d
			best = x
	return best

## An exit's own reason to show: it is the nearest one, or the one your squad called.
static func exit_matters(m: Match, x: Dictionary) -> bool:
	return is_same(x, nearest_exit(m)) or is_same(x, m.exits.active_for(m.player.team))

## A lair is Blight business once its boss is awake or a fight there was heard; before that it is detail.
static func lair_matters(m: Match, lair: Dictionary) -> bool:
	return lair["state"] == "awake" or m.lairs.alerted(lair, m.player)
