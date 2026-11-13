class_name BokiFly
extends RefCounted
## Fliers in the garden (content/rules/boki_fly.json): a species whose look has wings takes to the air while it
## roams a sky zone (Kitewind Ridge) and while it crosses a gap (a bridge over the void, the leap to another isle,
## The Dash's jump). Up there it hovers when it stands and glides when it moves; coming down it flares just before
## touchdown, then walks. It tells the body through two metas on its node: "aloft" (BokiRig plays hover or glide,
## and the flare when it turns false) and "lift" (m over the ground, where BokiRig keeps its shadow).
## k["fly"] = {h: m up now, to: m this flight holds}, only while it is off the ground. home.gd calls step() after
## each move, leap() on a leap and land() when another system takes the Boki.

var h                      # the home (home.gd): world
var R: Dictionary

func _init(home) -> void:
	h = home
	R = rules()

static func rules() -> Dictionary:
	return Content.rules("boki_fly")

## The roster's flier mark: the species' look has wings (its species JSON colors.wing).
static func flier(species: String) -> bool:
	return Data.KIN.get(species, {}).has("wing")

## Still in the air with `left` s to touchdown: the flare takes the last half of flare_s before it.
static func glides(left: float) -> bool:
	return left > float(rules()["flare_s"]) * 0.5

## m over the ground where a landing flier starts its flare: halfway through it, its feet touch down.
static func flare_from() -> float:
	var r := rules()
	return float(r["sink"]) * float(r["flare_s"]) * 0.5

## One Boki after its move this frame: it rises, holds or comes down. True while it is off the ground.
func step(k: Dictionary, pos: Vector3, n: Node3D, d: float) -> bool:
	if not flier(String(k["rec"]["species"])):
		return false
	var up := _wants_air(k, pos)
	if not k.has("fly"):
		if not up:
			return false
		k["fly"] = {"h": 0.0, "to": 0.0}
	var f: Dictionary = k["fly"]
	if not up:
		f["to"] = 0.0
	elif float(f["to"]) <= 0.0:
		f["to"] = randf_range(float(R["height"][0]), float(R["height"][1]))
	f["h"] = move_toward(float(f["h"]), float(f["to"]), float(R["climb"] if up else R["sink"]) * d)
	var lift := float(f["h"])
	n.position.y += lift
	n.set_meta("aloft", lift > (0.0 if up else flare_from()))
	n.set_meta("lift", lift)
	if lift <= 0.0:
		k.erase("fly")
	return lift > 0.0

## A flier glides the leap to another isle (home.gd _leap_step) and flares as it comes down.
func leap(k: Dictionary) -> void:
	if not flier(String(k["rec"]["species"])):
		return
	k.erase("fly")
	var left := 0.0
	if k.has("leap"):
		left = float(k["leap"]["dur"]) - float(k["leap"]["t"])
	var n: Node3D = k["node"]
	n.set_meta("aloft", glides(left))
	n.set_meta("lift", 0.0)

## Something else has the Boki now (a game, a carry, a job): it is on the ground at once.
func land(k: Dictionary) -> void:
	if not k.has("fly"):
		return
	k.erase("fly")
	var n: Node3D = k["node"]
	n.set_meta("aloft", false)
	n.set_meta("lift", 0.0)

func _wants_air(k: Dictionary, pos: Vector3) -> bool:
	var ahead: Vector3 = pos + (k["vel"] as Vector3) * float(R["gap_lead"])
	if _bridge(pos) or _bridge(ahead):
		return true
	return (R["zones"] as Array).has(GardenZones.here) and BaseLife.roams(k)

## A plank tile over the void between isles (World.bridge).
func _bridge(p: Vector3) -> bool:
	var w: World = h.world
	var ix := floori(p.x)
	var iz := floori(p.z)
	return w.inb(ix, iz) and w.bridge.has(w.idx(ix, iz))
