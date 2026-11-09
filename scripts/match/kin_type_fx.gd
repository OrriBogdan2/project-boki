class_name KinTypeFx
extends RefCounted
## A Boki's type, readable at a glance: one small accent on every ability cast, in the type's own
## colour and shape (embers for Fire, droplets for Water, zaps for Electric, shards for Ice, ripples
## for Psychic ...). It rides the shared Fx pools (dots, streaks, ring) and adds no node of its own.
## The cast's effect colour still means the effect category (KinRules.CAT_COLORS); this accent is
## the type, kept to the caster's feet so the two never fight. Look table: docs/HERO_VFX.md.

## Per type: col; dots / streaks = {n, speed, life, grav, size, spread} (n = amount at full quality; negative
## grav = rises); streaks go up, or along the cast with "fwd"; rings = [[radius, seconds]].
const LOOKS := {
	"normal": {"col": "ece8dc",
		"dots": {"n": 6, "speed": 2.5, "life": 0.4, "grav": 8.0, "size": 2.6, "spread": 180.0}},
	"fire": {"col": "ff6a1a",
		"dots": {"n": 8, "speed": 2.2, "life": 0.9, "grav": -3.0, "size": 2.1, "spread": 80.0}},
	"water": {"col": "2f9bff",
		"dots": {"n": 8, "speed": 4.5, "life": 0.55, "grav": 16.0, "size": 2.9, "spread": 55.0}},
	"grass": {"col": "55d84a",
		"dots": {"n": 7, "speed": 1.8, "life": 1.0, "grav": 1.5, "size": 3.4, "spread": 180.0}},
	"spore": {"col": "d8c27a",
		"dots": {"n": 5, "speed": 1.0, "life": 1.2, "grav": -0.8, "size": 5.7, "spread": 180.0}},
	"electric": {"col": "ffe53a",
		"streaks": {"n": 7, "speed": 14.0, "life": 0.1, "grav": 0.0, "size": 1.6, "spread": 180.0}},
	"ice": {"col": "7fe4ff",
		"streaks": {"n": 6, "speed": 5.0, "life": 0.5, "grav": 14.0, "size": 4.0, "spread": 70.0}},
	"rock": {"col": "a67c52",
		"dots": {"n": 7, "speed": 3.5, "life": 0.5, "grav": 22.0, "size": 3.9, "spread": 40.0}},
	"psychic": {"col": "c24dff",
		"dots": {"n": 4, "speed": 1.2, "life": 1.0, "grav": -1.5, "size": 1.8, "spread": 40.0},
		"rings": [[1.1, 0.65], [1.9, 0.9]]},
	"flying": {"col": "cfe6ff",
		"streaks": {"n": 5, "speed": 12.0, "life": 0.25, "grav": 0.0, "size": 2.0, "spread": 25.0, "fwd": true}},
	"dragon": {"col": "4a55ff",
		"dots": {"n": 4, "speed": 3.0, "life": 0.7, "grav": -2.0, "size": 3.1, "spread": 35.0},
		"streaks": {"n": 4, "speed": 6.0, "life": 0.45, "grav": -4.0, "size": 2.9, "spread": 35.0}},
	"dark": {"col": "5a3d86",
		"dots": {"n": 6, "speed": 1.2, "life": 1.1, "grav": -0.5, "size": 6.2, "spread": 180.0}},
	"poison": {"col": "a6e22e",
		"dots": {"n": 6, "speed": 1.6, "life": 0.9, "grav": -2.5, "size": 4.7, "spread": 60.0}},
	"bug": {"col": "f0b030",
		"dots": {"n": 10, "speed": 3.0, "life": 0.8, "grav": 0.0, "size": 1.3, "spread": 180.0}},
	"steel": {"col": "b4bfcc",
		"streaks": {"n": 4, "speed": 7.0, "life": 0.18, "grav": 0.0, "size": 3.2, "spread": 60.0, "fwd": true}},
	"fairy": {"col": "ffa8e0",
		"dots": {"n": 8, "speed": 1.4, "life": 1.1, "grav": -1.2, "size": 1.6, "spread": 180.0}},
	"crystal": {"col": "4fe8d0",
		"streaks": {"n": 5, "speed": 6.0, "life": 0.4, "grav": 0.0, "size": 3.6, "spread": 25.0}},
	"sound": {"col": "ffd27a",
		"rings": [[0.8, 0.22], [1.3, 0.3], [1.8, 0.38]]},
}

## The accent for a cast by a Boki of `type`, at `at` (its feet), toward `dir` (flat cast direction).
## An unknown type (a Boki with no type) plays nothing.
static func play(fx: Fx, type: String, at: Vector3, dir: Vector2, rings := true) -> void:
	var look: Dictionary = LOOKS.get(type, {})
	if look.is_empty():
		return
	var col := Color(String(look["col"]))
	var heading := Vector3(dir.x, 0.0, dir.y)
	var chest := at + Vector3(0, 0.8, 0)
	var d: Dictionary = look.get("dots", {})
	if not d.is_empty():
		fx.burst(chest, col, int(d["n"]), float(d["speed"]), float(d["life"]), float(d["grav"]), float(d["size"]),
			Vector3.UP, float(d["spread"]))
	var s: Dictionary = look.get("streaks", {})
	if not s.is_empty():
		var way := heading if s.has("fwd") else Vector3.UP
		fx.spark(chest, way, col, int(s["n"]), float(s["speed"]), float(s["spread"]), float(s["life"]),
			float(s["grav"]), float(s["size"]))
	for r: Array in look.get("rings", []) if rings else []:
		fx.ring(at, float(r[0]), col, float(r[1]))

## A Fusion moment (enter, release, afterglow) in the type's look, for everyone to read: the type's accent at the
## chest plus a light column rising from the body (no ground ring, no burst). A type whose accent is only rings
## (Sound) rises as streaks instead.
static func fusion(fx: Fx, type: String, at: Vector3, glow: Color, height: float) -> void:
	var look: Dictionary = LOOKS.get(type, {})
	var col := Color(String(look.get("col", glow.to_html(false))))
	var chest := at + Vector3(0, 0.8, 0)
	if look.has("dots") or look.has("streaks"):
		play(fx, type, at, Vector2.ZERO, false)
		# (twice: from the match camera one cast's worth is faint)
		play(fx, type, at + Vector3(0, 0.6, 0), Vector2.ZERO, false)
	else:
		fx.spark(chest, Vector3.UP, col, 6, 5.0, 40.0, 0.5, -2.0, 3.0)
	fx.beam(at, at + Vector3(0, height, 0), col, 1.2, 0.6)
