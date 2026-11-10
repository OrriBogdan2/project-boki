class_name LootOpenSfx
extends RefCounted
## The sound of opening a chest or a deathbox, on the open channel Match._update_interact already runs
## (no timer of its own): a short loop while the hold goes on, stopped the step it is cancelled, and one
## sting when it completes, chosen by the rarest thing inside. Positional at the box, so a squad nearby
## hears looting (the loop and the sting both fall off with Sfx's hear range).

const LOOPS := {"chest": "loot_creak", "box": "loot_latch"}
const STINGS := {2: "loot_rare", 3: "loot_epic", 4: "loot_legend"}   # Data.RARITY step -> sting; Common, Fine: none
const LOOP_DB := -6.0
const STING_DB := -3.0
const MAX_LOOPS := 3          # opening loops sounding at once (voice limit); a further looter is silent

var active := {}              # loop key -> the tick it was last held
var tick := 0
var _seq := 0

## Every step of an open channel on target `t` (a chest or a deathbox dict): starts the loop, keeps it alive.
func hold(kind: String, t: Dictionary) -> void:
	var key := String(t.get("lo_key", ""))
	if key == "":
		_seq += 1
		key = "lootopen%d" % _seq
		t["lo_key"] = key
	if not active.has(key):
		var near := Vector2(t["pos"].x - Sfx.listener.x, t["pos"].z - Sfx.listener.z).length() < Sfx.hear_range
		if active.size() >= MAX_LOOPS or not near:
			return
		Sfx.loop_start(key, LOOPS[kind], t["pos"], LOOP_DB)
	active[key] = tick
	Sfx.loop_set(key, t["pos"])

## Once per step after the channels ran: a loop nobody held this step is stopped (the open was cancelled).
func sweep() -> void:
	if not active.is_empty():
		for key in active.keys():
			if int(active[key]) != tick:
				active.erase(key)
				Sfx.loop_stop(key)
	tick += 1

## The open completed: the loop ends and the one sting for `rar` (the rarest thing inside) plays, once.
func done(t: Dictionary, rar: int) -> void:
	var key := String(t.get("lo_key", ""))
	if active.erase(key):
		Sfx.loop_stop(key)
	if t.has("lo_done"):
		return
	t["lo_done"] = true
	var sting := String(STINGS.get(mini(rar, 4), ""))
	if sting != "":
		Sfx.play(sting, t["pos"], STING_DB, 0.03)

## The rarest of the ground pickups from index `from` on (what a chest just dropped).
static func picks_rar(wpicks: Array, from: int) -> int:
	var best := 0
	for i in range(from, wpicks.size()):
		best = maxi(best, int(wpicks[i]["rar"]))
	return best

## The rarest thing in a deathbox: its worn gear and its pack.
static func box_rar(b: Dictionary) -> int:
	var best := 0
	for it in (b.get("gear", []) as Array) + (b.get("pack", []) as Array):
		best = maxi(best, Loot.rar_of(it))
	return best
