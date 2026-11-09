class_name HudBudget
extends RefCounted
## The HUD budget (DECISIONS 2026-11-08 "UI is too much"). On an expedition a new player sees four
## groups, the CORE: health, abilities with keys, the objective (the minimap) and the timer. Every
## other group shows when it first matters (its trigger below) and goes after HOLD_S, and never more
## than MAX_GROUPS are up at once: the free slots go in CONTEXT order. Holding Tab shows
## everything (and the kit card). The tutorial, training and the duel room keep their own screens.
## Every HUD group asks `Hud.budget.on(id)` before it draws; an id that is not listed is hidden.
## What is not a group: world-space marks (plates, crosshair, pings, waypoints) and the message
## lane (toasts, alerts, prompts), which are events rather than panels. --hud-budget-check logs the groups.

const MAX_GROUPS := 5             # groups on screen at once
const HOLD_S := 10.0              # s a contextual group stays after its trigger last held
const CORE := ["vitals", "abilities", "objective", "timer"]
const CONTEXT := ["squad", "belt", "kin", "weapon", "grip", "gear", "stats", "feed", "perks"]      # most urgent first
const FIGHT_HP := 0.7             # fraction of max health under which the belt and gloves matter

var shown: Array = CORE.duplicate()      # the groups up now
var capped := false                      # the budget applies (an expedition)
var _last := {}                          # id -> m.time its trigger last held
var _marks := {}                         # id -> the last seen state of the thing whose change triggers it

func on(id: String) -> bool:
	return not capped or id in shown or Input.is_action_pressed("scores")

## Run a few times a second: the core, then the first contextual groups that want to show.
func update(m: Match) -> void:
	capped = not (m.tut or m.duel or m.opts.get("training", false) or m.opts.get("arena", false)) and m.player != null
	if not capped:
		return
	shown = CORE + wanted(m).slice(0, MAX_GROUPS - CORE.size())

## The contextual groups that want to show now, whatever the cap.
func wanted(m: Match) -> Array:
	var out: Array = []
	for id in CONTEXT:
		var now := _trigger(id, m, m.player)
		if now:
			_last[id] = m.time
		if now or m.time - float(_last.get(id, -1e9)) < HOLD_S:
			out.append(id)
	return out

func _changed(id: String, state) -> bool:
	var first := not _marks.has(id)
	var diff: bool = _marks.get(id) != state
	_marks[id] = state
	return diff and not first

func _trigger(id: String, m: Match, p: Hunter) -> bool:
	match id:
		"weapon": return _shooting(m, p)
		"squad": return m.hunters.any(func(h): return _mate_in_trouble(h, p))
		"belt": return p.hp < p.max_hp * FIGHT_HP
		"kin": return p.kin != null and (p.kin.state != "shoulder" or p.kin.hp < p.kin.max_hp)
		"grip": return p.hp < p.max_hp * FIGHT_HP and _gloved(p)
		"gear": return _changed(id, p.gear.map(func(g): return String(g.get("id", ""))))
		"stats": return _changed(id, [p.kills, p.knocks, p.gems])
		"feed": return not m.feed.is_empty()
		"perks": return _changed(id, p.perks.size())
	return false

func _shooting(m: Match, p: Hunter) -> bool:
	var swung: bool = p.swing_at > 0.0 and m.time - p.swing_at < HOLD_S
	var fired: bool = p.wpn.get("ammo", true) and p.ammo < int(p.wpn["mag"])
	return p.reload_t > 0.0 or fired or swung

func _mate_in_trouble(h: Hunter, p: Hunter) -> bool:
	return h != p and h.team == p.team and (h.downed or h.out or h.hp < h.max_hp * 0.5)

func _gloved(p: Hunter) -> bool:
	return not (Gloves.worn(p, 0).is_empty() and Gloves.worn(p, 1).is_empty())
