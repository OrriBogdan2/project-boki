class_name HunterFeats
extends Node
## The feats Hunter challenges and mastery goals count (content/rules/class_unlock.json), recorded into
## each hunter's match stats (Hunter.add_stat) from the combat signals, so no kit has to know about them:
##   stuns / roots / slows / burns   a status put on an enemy (once per enemy per STATUS_GAP_S)
##   multi3          one ability (not a weapon hit) hits 3 enemies within MULTI_WINDOW_S
##   far_hits        a hit from FAR_HIT_M or more
##   air_hits        a hit while you are off the ground
##   kin_hits        a hit by your Boki
##   merged_knocks   a knock while merged with your Boki
##   lowhp_knocks    a knock while under half health
## A Boki's statuses count for its hunter. Added as a child of the match (Match.start).

const STATUS_GAP_S := 1.0         # s; a burn ticking on one enemy counts once, not every tick
const MULTI_WINDOW_S := 0.3       # s; hits from one cast land together
const MULTI_TARGETS := 3
const FAR_HIT_M := 12.0           # m from the attacker to the target
const LOW_HP_K := 0.5             # share of max health under which a knock is a "lowhp" knock
const STATUS_MEMORY := 2048       # entries kept before the gap memory starts over
const STATUS_STATS := {"stun": "stuns", "root": "roots", "slow": "slows", "burn": "burns"}
const WEAPON_TAGS := ["primary", "shot", "flame", "burn", "melee", "mob", "fall", "wall", "hazard"]

var m: Match
var _status_seen := {}            # "hunter id|target id|status" -> match time it last counted
var _casts := {}                  # "hunter id|tags" -> {t: start time, targets: [instance ids], done}
var _hit_cb: Callable
var _status_cb: Callable

func _init(match_node: Match) -> void:
	m = match_node
	name = "HunterFeats"

func _ready() -> void:
	_hit_cb = _on_hit
	_status_cb = _on_status
	CombatBus.hit_landed.connect(_hit_cb)
	CombatBus.status_applied.connect(_status_cb)

func _exit_tree() -> void:
	if CombatBus.hit_landed.is_connected(_hit_cb):
		CombatBus.hit_landed.disconnect(_hit_cb)
	if CombatBus.status_applied.is_connected(_status_cb):
		CombatBus.status_applied.disconnect(_status_cb)

## The hunter credited for something `by` did: itself, or the owner of a Boki.
static func credit_of(by: Node) -> Hunter:
	if by is Hunter:
		return by
	if by is Kin and (by as Kin).owner_h:
		return (by as Kin).owner_h
	return null

static func is_enemy(h: Hunter, target: Node) -> bool:
	return target is Ent and target != h and (target as Ent).team != h.team and not (target as Ent).dead

func _on_status(target: Node, status: String, by: Node, _duration: float) -> void:
	var h := credit_of(by)
	if h == null or not STATUS_STATS.has(status) or not is_enemy(h, target):
		return
	var key := "%d|%d|%s" % [h.get_instance_id(), target.get_instance_id(), status]
	if m.time - float(_status_seen.get(key, -100.0)) < STATUS_GAP_S:
		return
	if _status_seen.size() > STATUS_MEMORY:
		_status_seen.clear()
	_status_seen[key] = m.time
	h.add_stat(String(STATUS_STATS[status]))

func _on_hit(attacker: Node, target: Node, _amount: float, tags: Array) -> void:
	var h := credit_of(attacker)
	if h == null or not is_enemy(h, target):
		return
	if attacker is Kin:
		h.add_stat("kin_hits")
	else:
		if not h.grounded:
			h.add_stat("air_hits")
		if h.flat_dist(target as Ent) >= FAR_HIT_M:
			h.add_stat("far_hits")
		if not tags.is_empty() and not WEAPON_TAGS.has(String(tags[0])):
			_count_cast(h, target, tags)
	if target is Hunter:
		_watch_knock.call_deferred(h, target as Hunter, (target as Hunter).downed)

## Groups one hunter's ability hits with the same tags inside MULTI_WINDOW_S as one cast.
func _count_cast(h: Hunter, target: Node, tags: Array) -> void:
	var key := "%d|%s" % [h.get_instance_id(), ",".join(tags)]
	var cast: Dictionary = _casts.get(key, {})
	if cast.is_empty() or m.time - float(cast["t"]) > MULTI_WINDOW_S:
		cast = {"t": m.time, "targets": [], "done": false}
		_casts[key] = cast
	var tid := target.get_instance_id()
	if not (cast["targets"] as Array).has(tid):
		(cast["targets"] as Array).append(tid)
	if not bool(cast["done"]) and (cast["targets"] as Array).size() >= MULTI_TARGETS:
		cast["done"] = true
		h.add_stat("multi3")

## After the hit has played out: did it knock the rival down, and how was the hunter doing then?
func _watch_knock(h: Hunter, rival: Hunter, was_down: bool) -> void:
	if not is_instance_valid(h) or not is_instance_valid(rival) or was_down or not rival.downed:
		return
	if not h.merge_st.is_empty():
		h.add_stat("merged_knocks")
	if h.hp < h.max_hp * LOW_HP_K:
		h.add_stat("lowhp_knocks")
