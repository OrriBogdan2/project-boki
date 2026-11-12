class_name StatusSfx
extends Node
## The sound of statuses (content/rules/status_sfx.json): a short cue on the affected body when a status
## lands (Ignite, Chill, Static, Slow, Stun, Root, Ground, Daze, Anti-Heal), and a quiet loop for the two
## long ones (Ignite's crackle, Static's buzz), stopped when the status runs out or is cleansed. Yours
## (on your body, or put there by you or your Boki) play a little louder.
## Hooks: CombatBus.status_applied (stun, root, slow, burn), KitStatus (Ground, Daze, Disoriented, Blight),
## Ent.hurt's blight, Chill (rimewright_kit), Static (mage_kit), Ignite (ashwick_kit). Voice caps: the rules'
## cue_cap and loop_cap. A refresh of a status that is still running is silent; Static climbs per stack.
## Added as a child of the match (Match.start); the loops stop with it.

const KIT_KINDS := {"gnd": "ground", "rat": "daze", "dsr": "slow", "blt": "antiheal"}   # KitStatus kind -> cue
const BODY_STATUS := {"stun": "stun", "root": "root", "slow": "slow"}                  # CombatBus status -> cue
const PRUNE_AT := 256            # remembered statuses before the stale ones are dropped

static var inst: StatusSfx = null

var m: Match
var rules: Dictionary
var _until := {}                 # "body id|cue" -> match time it runs out
var _cue_ms: Array = []          # when the last cues started (the voice cap)
var _loops := {}                 # Sfx loop key -> {e: Ent, kind, stacks: Callable (0 = over)}
var _status_cb: Callable

func _init(match_node: Match) -> void:
	m = match_node
	name = "StatusSfx"
	rules = Content.rules("status_sfx")

func _ready() -> void:
	inst = self
	_status_cb = _on_status
	CombatBus.status_applied.connect(_status_cb)

func _exit_tree() -> void:
	if CombatBus.status_applied.is_connected(_status_cb):
		CombatBus.status_applied.disconnect(_status_cb)
	for key in _loops.keys():
		Sfx.loop_stop(key)
	_loops.clear()
	if inst == self:
		inst = null

## `kind` (a key of "cues") starts on `e` for `secs`. `stacks` raises the pitch where the rules say so;
## `again`: play even though it is already running (a new Static stack). `by`: who put it there.
static func cue(e: Ent, kind: String, by: Node = null, secs := 1.0, stacks := 1, again := false) -> void:
	if inst != null:
		inst._cue(e, kind, by, secs, stacks, again)

## A KitStatus kind ("gnd", "rat", "dsr", "blt"); the others have no cue.
static func kit(e: Ent, code: String, secs: float) -> void:
	if KIT_KINDS.has(code):
		cue(e, String(KIT_KINDS[code]), null, secs)

## Ignite: the cue and the crackle for as long as the body burns.
static func ignite(e: Ent, by: Node, secs: float) -> void:
	if inst == null or e == null:
		return
	inst._cue(e, "ignite", by, secs, 1, false)
	inst._loop(e, "ignite", by, func() -> int: return 1 if e.burn_t > 0.0 and not e.dead else 0)

## Static's buzz while `stacks` (the kit's count on that body) stays above 0.
static func loop_static(e: Ent, by: Node, stacks: Callable) -> void:
	if inst != null:
		inst._loop(e, "static", by, stacks)

func _on_status(target: Node, status: String, by: Node, secs: float) -> void:
	if not target is Ent:
		return
	if status == "burn":
		ignite(target, by, (target as Ent).burn_t)
	elif BODY_STATUS.has(status):
		_cue(target, String(BODY_STATUS[status]), by, secs, 1, false)

func _mine(e: Ent, by: Node) -> bool:
	return e == m.player or (by != null and HunterFeats.credit_of(by) == m.player)

func _cue(e: Ent, kind: String, by: Node, secs: float, stacks: int, again: bool) -> void:
	if e == null or not is_instance_valid(e) or e.dead or not rules["cues"].has(kind):
		return
	var key := "%d|%s" % [e.get_instance_id(), kind]
	var running: bool = float(_until.get(key, -1.0)) > float(m.time)
	if _until.size() > PRUNE_AT:
		_until.clear()
	_until[key] = float(m.time) + secs
	if running and not again:
		return
	var now := Time.get_ticks_msec()
	while not _cue_ms.is_empty() and now - int(_cue_ms[0]) > int(rules["cue_window_ms"]):
		_cue_ms.pop_front()
	if _cue_ms.size() >= int(rules["cue_cap"]):
		return
	_cue_ms.append(now)
	var c: Dictionary = rules["cues"][kind]
	var db := float(c.get("db", rules["cue_db"])) + (float(rules["mine_db"]) if _mine(e, by) else 0.0)
	var pitch := float(c.get("pitch_base", 1.0)) + float(c.get("pitch_step", 0.0)) * stacks
	Sfx.play(String(c["sound"]), e.pos, db, 0.04, pitch)

func _loop(e: Ent, kind: String, by: Node, stacks: Callable) -> void:
	if e == null or not is_instance_valid(e) or e.dead:
		return
	var key := "st_%s_%d" % [kind, e.get_instance_id()]
	if _loops.has(key) or _loops.size() >= int(rules["loop_cap"]):
		return
	_loops[key] = {"e": e, "kind": kind, "stacks": stacks}
	var db := float(rules["loop_db"]) + (float(rules["mine_db"]) if _mine(e, by) else 0.0)
	Sfx.loop_start(key, String(rules["loops"][kind]["sound"]), e.pos, db, float(rules["loop_reach_m"]))

func _process(_dt: float) -> void:
	for key in _loops.keys():
		var L: Dictionary = _loops[key]
		var ev = L["e"]
		var n: int = (L["stacks"] as Callable).call() if is_instance_valid(ev) else 0
		if n <= 0:
			Sfx.loop_stop(key)
			_loops.erase(key)
		else:
			var step := float(rules["loops"][L["kind"]]["pitch_step"])
			Sfx.loop_set(key, (ev as Ent).pos, 1.0 + step * (n - 1))
