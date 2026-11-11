extends RefCounted
## --air-cast-check: for all 12 Hunters, LMB, RMB, E and R cast at the top of a running jump. Each slot's effect on
## the horizontal and the vertical speed over the next WINDOW_S is measured against the same jump with no cast and
## must match the hero's air_cast row in content/dash_flow/<id>.json ("cast", "h", "v");
## docs/heroes/dash_interactions.md ("Cast at the top of a jump") shows the rows next to the source. Never touches
## the save.
## h: keep (within KEEP_TOL of the plain jump: the air steers as in any jump), slow (bled or braked below it),
##    zero (stopped), push (the ability drives the hunter faster).
## cast: air (default: it goes off in the air), landing (the press waits for the landing), no (dropped).
## v: fall (as the plain jump), hover (height held), rise, slow (falls less), drop (falls harder: a slam).

const FLOW := preload("res://tools/dash_flow_check.gd")
const SLOTS := ["lmb", "rmb", "e", "x"]
const RUN_UP := 30              # steps running forward before the jump (full run speed)
const APEX_MAX := 60            # steps: the jump's top comes within this (JUMP_V / H_GRAV is about 28)
const WINDOW_S := 0.4           # s after the press that is measured (the plain jump lands 0.46 s after its top)
const LAND_WATCH := 60          # steps after the window: a press that waited goes off on the landing
const KEEP_TOL := 0.15          # share of the plain jump's horizontal speed: within it is "keep"
const ZERO_K := 0.15            # below this share of the plain jump's speed is "zero"
const HOVER_M := 0.05           # m: height held within this is "hover"
const RISE_M := 0.1             # m above the top is "rise"
const FALL_M := 0.15            # m: ending within this of the plain jump's height is "fall"
const LOOK := Vector3(0, 0.9, -8)   # aim: ahead, along the run

var bad := 0
var flow = FLOW.new()
var h: Hunter
var only := []                  # --air-cast-check=<id>,<id>: just those heroes

func ok(cond: bool, what: String) -> void:
	print("AIRCAST %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--air-cast-check="):
			only = a.split("=")[1].split(",")
	for hero in Arch.ORDER:
		if not only.is_empty() and not only.has(hero):
			continue
		var m: Match = flow._match(main, hero)
		h = flow.hunter
		var rows: Dictionary = DashFlow.file_of(hero).get("air_cast", {})
		var plain: Array = _trace(m, "")["t"]
		for slot in SLOTS:
			var got := _trace(m, slot)
			var row: Dictionary = rows.get(slot, {})
			var kind := "%s/%s" % [got["cast"], _classify(got["t"], plain)]
			var want := "%s/%s/%s" % [row.get("cast", "air"), row.get("h", "missing"), row.get("v", "missing")]
			ok(kind == want, "%s %s: %s (row %s) %s" % [hero, slot, kind, want, _info(got["t"], plain)])
		m.queue_free()
		await main.get_tree().process_frame
	print("AIRCAST DONE, failures: %d" % bad)
	main.get_tree().quit()

## Runs forward, jumps, and at the top presses `slot` ("" for none), keys held forward throughout. t: per step
## after the press, [horizontal speed, height above the top]; cast: "air" (it went off in the window), "landing" (it
## went off on the landing: the press waited) or "no" (it never did: dropped).
func _trace(m: Match, slot: String) -> Dictionary:
	flow._ready_up(m)
	h.inp["move"] = Vector2(0, -1)
	_steps(m, RUN_UP)
	h.inp["jump"] = true
	m.step(Match.DT)
	h.inp["jump"] = false
	var n := 0
	while h.vel.y > 0.0 and n < APEX_MAX:
		m.step(Match.DT)
		n += 1
	var top := h.pos.y
	var out := []
	var before: Dictionary = flow._snap()
	h.ak.anim_id = ""             # a wind-up with no cooldown yet shows as its clip
	if slot != "":
		flow._press(slot)
	var went := slot == ""
	for i in int(WINDOW_S / Match.DT):
		h.inp["aim"] = h.pos + LOOK
		var was := h.pos
		m.step(Match.DT)
		_let_go()
		went = went or _went(before, slot)
		var moved := Vector2(h.pos.x - was.x, h.pos.z - was.z).length()     # (a kit may move pos, not vel)
		out.append([moved / Match.DT, h.pos.y - top])
		if h.grounded:
			break                     # only the air counts: landed early is a drop
	h.inp["move"] = Vector2.ZERO
	var cast := "air" if went else "no"
	for i in LAND_WATCH:
		if cast == "no" and h.grounded and _went(before, slot):
			cast = "landing"
		m.step(Match.DT)
	return {"t": out, "cast": cast}

func _went(before: Dictionary, slot: String) -> bool:
	return flow._went_off(before, slot) or h.ak.anim_id != ""

func _let_go() -> void:
	for key in ["fire", "sec", "sig"]:
		h.inp[key] = false

func _steps(m: Match, n: int) -> void:
	for i in n:
		h.inp["aim"] = h.pos + LOOK
		m.step(Match.DT)

## The trace against the plain jump's: the horizontal share's range (a share must last two steps: a one-step snap of
## the position is not a push), the height at the end and its peak, and the plain jump's height then.
func _sums(t: Array, plain: Array) -> Dictionary:
	var n := t.size()
	var out := {"lo": INF, "hi": 0.0, "top": -INF, "low": INF, "end": t[-1][1], "plain": plain[n - 1][1]}
	var k := []
	for i in n:
		k.append(t[i][0] / maxf(plain[i][0], 0.1))
		out["top"] = maxf(out["top"], t[i][1])
		out["low"] = minf(out["low"], t[i][1])
	for i in maxi(n - 1, 1):
		var pair: Array = k.slice(i, i + 2)
		out["lo"] = minf(out["lo"], pair.max())
		out["hi"] = maxf(out["hi"], pair.min())
	return out

## "h/v", the row's words (see the top of the file).
func _classify(t: Array, plain: Array) -> String:
	var d := _sums(t, plain)
	var hk := "keep"
	if d["hi"] > 1.0 + KEEP_TOL:
		hk = "push"
	elif d["lo"] < ZERO_K:
		hk = "zero"
	elif d["lo"] < 1.0 - KEEP_TOL:
		hk = "slow"
	var vk := "fall"
	if d["top"] > RISE_M:
		vk = "rise"
	elif d["low"] > -HOVER_M:
		vk = "hover"
	elif d["end"] > d["plain"] + FALL_M:
		vk = "slow"
	elif d["end"] < d["plain"] - FALL_M:
		vk = "drop"
	return "%s/%s" % [hk, vk]

func _info(t: Array, plain: Array) -> String:
	var d := _sums(t, plain)
	return "h %.2f-%.2fx of a plain jump, height %+.2f m (plain %+.2f, peak %+.2f)" % [
		d["lo"], d["hi"], d["end"], d["plain"], d["top"]]
