class_name Blockers
extends RefCounted
## The one rule for what stops what: blockers (Albert's raised shield and every carried wall, Tenzo's rocks,
## Neve's ice, placed walls, Kael's Riposte guard) against crossers (shots, terrain-piercing reaches, bodies,
## phases, lobs). The table is data, content/rules/blockers.json; docs/ABILITIES.md "Blockers and crossers"
## shows it and --blocker-check fires each crosser at each blocker.

const STOP := "stop"
const PASS := "pass"
const NA := "na"
const KINDS := ["shield", "rock", "ice", "wall", "guard"]

static var CROSSERS: Dictionary = Content.rules("blockers")["crossers"]
static var _classes: Dictionary = Content.rules("blockers")["classes"]

## What the crosser `c` (a crossers key or a class) does at a blocker of kind `b`: STOP, PASS or NA.
static func stops(c: String, b: String) -> String:
	var cls := String(CROSSERS[c]["class"]) if CROSSERS.has(c) else c
	return String(_classes[cls][b])

## The kind of a Verbs wall: a carried one (a raised aegis, Bracewall, Mass Guard) is a shield, a rock of
## Tenzo's is terrain, Neve's ice and every other placed wall stop like walls.
static func kind_of(w: Dictionary) -> String:
	if w.get("follow", false):
		return "shield"
	if w.get("rock", false):
		return "rock"
	return "ice" if w.get("ice", false) else "wall"

## Does Verbs wall `w` stop a crosser of class `cls`?
static func wall_stops(w: Dictionary, cls: String) -> bool:
	return String(_classes[cls][kind_of(w)]) == STOP

## Does a body blocker (Albert's raised shield facing `by`, Kael's Riposte guard) on `f` stop what `by` sends?
## Pulls ask before they tow: the hit itself is already stopped in their kits' incoming().
static func body_stops(f: Ent, by: Ent) -> bool:
	return f is Hunter and (f as Hunter).ak != null and (f as Hunter).ak.blocks_from(by)

## How far along a to b (m) the first Verbs wall that stops a crosser of class `cls` from team `team` is, at
## height y; INF when none does.
static func cut(walls: Array, a: Vector3, b: Vector3, team: int, cls: String) -> float:
	var best := INF
	var a2 := Vector2(a.x, a.z)
	for w in walls:
		if (w["block"] != "all" and int(w["team"]) == team) or not wall_stops(w, cls):
			continue
		if a.y < float(w["y"]) - 0.3 or a.y > float(w["y"]) + float(w.get("top", Verbs.WALL_H)) + 0.3:
			continue
		var p = Geometry2D.segment_intersects_segment(a2, Vector2(b.x, b.z), w["a"], w["b"])
		if p != null:
			best = minf(best, a2.distance_to(p))
	return best
