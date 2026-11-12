extends RefCounted
## --glide-cast-check: a press while the glider is open (docs/heroes/dash_interactions.md, "From the glider").
## Every hero and slot (LMB, RMB, E, X = the hero's ultimate, Q glove, Shift) is pressed with the glider open and
## must do what its `glide` row in content/dash_flow/<hero>.json says: "cast" (acts, the glider stays), "fold"
## (acts, the glider closes) or "refuse" (nothing happens). Owner rule: Tarek's RMB slam is never blocked.

const HEIGHT := 12.0            # m above the ground: low enough for a foe on the ground to be in an ultimate's range
const FOE_DX := 5.0             # m from the hunter to the foe and the cursor
const PRESS_STEPS := 45         # steps a press is watched (a wind-up like Meeko's seed throw ends inside it)
const KEY_OF := {"lmb": "fire", "rmb": "sec", "e": "sig", "dash": "dash", "q": "gear1"}
const SLOTS := ["lmb", "rmb", "e", "x", "q", "dash"]

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("GLIDECAST %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _match(main: Node, arch: String) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({
		"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 162, "no_drop": true,
		"cls": Arch.weight(arch), "arch": arch, "weapon": Arch.signature(arch),
	})
	m.set_process(false)
	for mob in m.mobs:
		mob.queue_free()
	m.mobs.clear()
	var hunter: Hunter = m.player
	hunter.set_arch(arch)
	hunter.unlock_all()
	hunter.lvl = 6
	hunter.slot_lv["ult"] = 1
	hunter.gear[0] = {"id": "gust_fan", "rar": 1}
	for other in m.hunters:
		if other != hunter:
			other.ctrl = "idle"
			other.teleport(hunter.pos + Vector3(FOE_DX, 0, 0))
			break
	for i in 20:
		m.step(Match.DT)
	return m

func _ready_all(h: Hunter) -> void:
	h.dashes = h.max_dashes()
	h.ex_cd = 0.0
	for key in h.ak.cd:
		h.ak.cd[key] = 0.0
	h.ak.ch_rmb = float(h.ak.rmb_charges())
	h.gear_cd[0] = 0.0

## Opens the glider over the ground and returns the hunter, still, with the cursor on the foe.
func _glide(m: Match) -> Hunter:
	var h: Hunter = m.player
	var ground := h.pos
	h.teleport(ground + Vector3(0, HEIGHT, 0))
	h.vel = Vector3(0.0, -2.0, 0.0)
	h.grounded = false
	_ready_all(h)
	h.inp["glide"] = true
	h.inp["glide_btn"] = true
	h.inp["aim"] = ground + Vector3(FOE_DX, 0.9, 0)
	for i in 30:
		m.step(Match.DT)
	return h

## What the press did: "cast", "fold" or "refuse".
func _press(m: Match, slot: String) -> String:
	var h := _glide(m)
	if not h.gliding:
		return "no glider"
	var ammo0 := h.ammo
	var dashes0 := h.dashes
	var used0: Dictionary = h.used.duplicate()
	var cd0: Dictionary = h.ak.cd.duplicate()
	if slot == "x":
		HunterKeys.ult_pressed(h)
	else:
		h.inp[KEY_OF[slot]] = true
	if slot == "rmb":
		h.inp["sec_hold"] = true
	var acted := false
	var folded := false
	for i in PRESS_STEPS:
		m.step(Match.DT)
		acted = acted or h.roll_t > 0.0 or h.dashes < dashes0 or h.used != used0 or h.ammo < ammo0 or h.ak.cd != cd0 \
				or h.ak.rmb_down or h.ak.anim_id != "" or not h.ak.chg.is_empty() or h.fire_cd > 0.0 \
				or h.mel_hold > 0.0 or h.spin > 0.0 or h.warm_t > 0.0 or h.charge_k() > 0.0 \
				or h.ak.ult_running() or h.gear_cd[0] > 0.0
		folded = folded or not h.gliding
	if not acted:
		return "refuse"
	return "fold" if folded else "cast"

func run(main: Node) -> void:
	Save.no_write = true
	for arch in Arch.ORDER:
		var rows: Dictionary = DashFlow.file_of(arch).get("glide", {})
		for slot in SLOTS:
			var m := _match(main, arch)
			var want := String(rows.get(slot, {}).get("mode", "no row"))
			var got := _press(m, slot)
			ok(got == want, "%s %s with the glider open: %s (row: %s)" % [arch, slot, got, want])
			if arch == "dolm" and slot == "rmb":
				ok(got != "refuse", "Tarek's RMB slam is never blocked by the glider")
			m.queue_free()
			await main.get_tree().process_frame
	print("GLIDECAST DONE, failures: %d" % bad)
	main.get_tree().quit()
