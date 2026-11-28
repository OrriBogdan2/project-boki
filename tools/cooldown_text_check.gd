extends RefCounted
## --cooldown-text-check: the seconds left on a cooling slot of the bottom bar (HudSlot.cd_text) and the
## charge count, read from what the real match HUD drew: a 7.5 s cooldown shows 8, then 0.4 near the end;
## the dash slot shows its seconds and one pip per charge; the Boki's G slot counts its wait down.
## Every Hunter's RMB, E and dash at ranks 1-3 (R has its own check): the cooldown the JSON gives (rank_cd, else the
## shared 10% / 15% a rank), the one the kit uses after a real cast and a second's wait, and what the HUD and the
## hover tip say, must agree.
## With --shots-dir=<dir> (a GPU run) it also saves the bar as cooldown_text_bar.png. Never touches the save.

const JSON_BLOCK := {"sec": "rmb", "kin": "e", "dash": "dash"}      # a ranked slot's block in the hero's JSON
const HUD_ID := {"sec": "sec", "kin": "k1", "dash": "dash"}      # and its id on the bar

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("COOLDOWNTEXT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## The bar draws on HudPanels, REDRAW_HZ times a second: wait for its next draw.
func _drawn(hud) -> void:
	await hud.panels.draw
	await main.get_tree().process_frame

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Save.d["matches"] = HudGroups.NEW_PLAYER_MATCHES      # the whole HUD: a new save gets it staged (HudReveal)
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 12, "no_drop": true,
		"demo_kin": "cindle", "arch": "thief", "cls": Arch.weight("thief"), "weapon": Arch.signature("thief")})
	m.set_process(false)
	var p: Hunter = m.player
	p.ctrl = "local"
	for o in m.hunters:
		if o != p:
			o.ctrl = "idle"
			o.teleport(p.pos + Vector3(40, 0, 40))
	p.unlock_all()
	var hud = m.hud
	var want := {7.5: "8", 7.01: "8", 1.0: "1", 0.99: "1.0", 0.4: "0.4"}
	for secs in want:
		var got := HudSlot.cd_text(secs)
		ok(got == want[secs], "%.2f s reads '%s' (got '%s')" % [secs, want[secs], got])
	for secs in [7.5, 0.4]:
		p.ak.cd["e"] = secs
		await _drawn(hud)
		var shown := String(hud.slot_text.get("k1", ""))
		ok(shown == want[secs], "E with %.1f s left draws '%s' (drew '%s')" % [secs, want[secs], shown])
	p.ak.cd["e"] = 0.0
	_ranks(m, p, hud)
	p.reclass(Arch.weight("thief"), "thief")
	await _dash(p, hud)
	await _throw(p, hud)
	await _shot(p, hud)
	print("COOLDOWN TEXT CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## One hero at a time on the same player (practice's own swap), every ranked slot at ranks 1..3 together.
func _ranks(m: Match, p: Hunter, hud) -> void:
	for a in Arch.ids():
		var air1 := -1.0
		for rank in range(1, int(Hunter.SLOT_MAX["sec"]) + 1):
			p.reclass(Arch.weight(a), a)      # a fresh kit: no cast left over from the rank before
			p.unlock_all()
			for s in ["sec", "kin", "dash"]:
				p.slot_lv[s] = rank
			for slot in ["sec", "kin", "dash"]:
				_rank_row(m, p, hud, a, slot, rank)
			if p.ak.has_long_dash():
				var air := _air_row(p, a, rank, air1)
				air1 = air if rank == 1 else air1

## What the hero's JSON says the slot's cooldown is at `rank`: the slot's rank_cd row, else the Bulwark's own
## fields (cd_per_rank, cooldown_rank3), else the shared rule (10% shorter a rank, the dash 15%).
func _want(a: String, slot: String, rank: int) -> float:
	var d := Arch.def(a)
	var blk: Dictionary = d[JSON_BLOCK[slot]]
	var base := float(blk.get("cd" if slot == "dash" else "cooldown", 0.0))
	var row: Array = d.get("rank_cd", {}).get(slot, [])
	if not row.is_empty():
		return base * float(row[mini(rank, row.size()) - 1])
	if blk.has("cd_per_rank"):
		return base - float(blk["cd_per_rank"]) * float(rank - 1)
	if blk.has("cooldown_rank3"):
		return float(blk["cooldown_rank3"]) if rank >= 3 else base
	return base * (1.0 - (0.15 if slot == "dash" else 0.1) * float(rank - 1))

## Fires the slot for real, waits a second, and reads the cooldown left; then the HUD's number and the tip.
func _rank_row(m: Match, p: Hunter, hud, a: String, slot: String, rank: int) -> void:
	var ak: ArchKit = p.ak
	var want := _want(a, slot, rank)
	var used := want         # the seconds the kit really uses; a dash is timed by charging it back
	var hud_id: String = HUD_ID[slot]
	var fired := true
	var left := 0.0
	match slot:
		"sec":
			ak.ch_rmb = float(ak.rmb_charges())
			ak.cd["rmb"] = 0.0
			fired = ak.spend_rmb(true)
			used = float(ak.cd["rmb"])
			ak.tick(1.0)
			left = float(ak.cd["rmb"])
		"kin":
			ak.cd["e"] = 0.0
			ak.use_e()
			if ak is JuggernautKit:      # the Warchain starts the wait when it pulls or breaks, not on the press
				(ak as JuggernautKit).start_e_cd()
			used = float(ak.cd["e"])
			fired = used > 0.0
			ak.tick(1.0)
			left = float(ak.cd["e"])
		"dash":
			used = 0.0
			p.dash.charges = 0.0
			while p.dash.charges < 1.0 and used < 99.0:
				p.dash.tick(0.01, p.max_dashes(), p.dash_regen())
				used += 0.01
			left = used - 1.0
	var info: Dictionary = p.slot_info(hud_id)
	var tip := ""
	for row in m.hud.hover.tip_lines(hud_id, p):
		tip += String(row[0]) + "\n"
	var card := AbilityCard.numbers(AbilityCard.facts_for(a, JSON_BLOCK[slot], info))
	var secs: String = m.hud.hover.secs(want)
	var tip_ok := tip.contains("Cooldown %s" % secs)
	var nr := Arch.next_ranks(a, slot, rank)      # the tip's "next rank" words come from the JSON, not a constant
	var rank_ok := rank >= 3 or not tip.contains("next rank")
	if rank < 3 and not nr.is_empty():
		rank_ok = tip.contains("next rank: %s" % nr[0][1])
	var close := absf(used - want) < 0.02 + (0.01 if slot == "dash" else 0.0)
	var waited := absf(left - (used - 1.0)) < 0.02 and (slot == "dash" or absf(float(info["cd"]) - left) < 0.02)
	var says := absf(float(info["cd_max"]) - want) < 0.02 and tip_ok and rank_ok and card.contains(KinText.n(want))
	ok(fired and close and says and waited,
		"%s %s rank %d: JSON %.2f s, kit used %.2f s, bar says %.2f s, left after 1 s %.2f s, tip %s, card '%s'"
		% [a, slot, rank, want, used, float(info["cd_max"]), left, "ok" if tip_ok else "WRONG", card])

## The long (air) dash: its cooldown after a cast, against rank 1's and the hero's rank_cd.air row (a kit with
## no row keeps its own rule; the slot must still say what the kit used).
func _air_row(p: Hunter, a: String, rank: int, air1: float) -> float:
	p.dash.ex_cd = 0.0
	p.ak.spend_dash(true)
	var used := p.dash.ex_cd
	var row: Array = Arch.def(a).get("rank_cd", {}).get("air", [])
	var want := used if row.is_empty() or rank == 1 else air1 * float(row[mini(rank, row.size()) - 1])
	ok(absf(used - want) < 0.02 and absf(DashSlot.air_cd_of(p) - used) < 0.02,
		"%s air dash rank %d: kit used %.2f s, the slot says %.2f s, JSON row says %.2f s"
		% [a, rank, used, DashSlot.air_cd_of(p), want])
	p.dash.ex_cd = 0.0
	return used

## The dash slot: a pip per charge, and its recharge seconds while it is empty.
func _dash(p: Hunter, hud) -> void:
	p.dashes = 0.5
	await _drawn(hud)
	var left := 0.5 * p.dash_regen()
	var sh: Dictionary = DashSlot.shown.get(hud.get_instance_id(), {})
	var pips: Array = sh.get("pips", [])
	var want_pips := int(p.max_dashes()) if p.max_dashes() > 1.0 else 0     # a one-charge dash draws no discs
	ok(String(sh.get("text", "")) == HudSlot.cd_text(left) and pips.size() == want_pips,
		"dash empty, %.2f s to the next charge: '%s' and %d pips" % [left, sh.get("text", ""), pips.size()])
	# the source keeps the countdown on the slot while one charge is ready
	# and the next comes back (DASH_UI.md)
	var dd: Dictionary = p.ak.dash_def()
	var had: Variant = dd.get("charges")
	dd["charges"] = 2                  # a second charge, as the multi-charge dashes in the source
	ok(p.max_dashes() >= 2.0, "the dash has %d charges for the partial case" % int(p.max_dashes()))
	if p.max_dashes() >= 2.0:
		p.dashes = 1.5
		await _drawn(hud)
		left = 0.5 * p.dash_regen()
		sh = DashSlot.shown.get(hud.get_instance_id(), {})
		pips = sh.get("pips", [])
		var lit: bool = pips.size() >= 2 and float(pips[0]) >= 1.0 and absf(float(pips[1]) - 0.5) < 0.01
		ok(String(sh.get("text", "")) == HudSlot.cd_text(left) and lit,
			"dash 1 of %d ready, next back in %.2f s: '%s', pips %s"
			% [int(p.max_dashes()), left, sh.get("text", ""), pips])
	p.dashes = p.max_dashes()
	await _drawn(hud)
	sh = DashSlot.shown.get(hud.get_instance_id(), {})
	pips = sh.get("pips", [])
	ok(String(sh.get("text", "")) == "" and pips.all(func(f): return float(f) >= 1.0),
		"dash full: no seconds, every pip full")
	if had == null:
		dd.erase("charges")
	else:
		dd["charges"] = had
	p.dashes = p.max_dashes()

## The Boki's G slot: it counts its wait down in tenths and clears when it is over.
func _throw(p: Hunter, hud) -> void:
	var k: Kin = p.kin
	ok(k != null, "the player has a Boki")
	if k == null:
		return
	k.state = "shoulder"
	k.throw_cd = 0.4
	await _drawn(hud)
	var shown := String(hud.slot_text.get("throw", ""))
	ok(shown == "0.4", "G with 0.4 s left draws '0.4' (drew '%s')" % shown)
	k.throw_cd = 0.0
	await _drawn(hud)
	ok(not hud.slot_text.has("throw"), "G ready: no countdown")


## The bar with E, X, the dash and G all cooling at once; the bottom 200 px of the 720p frame.
func _shot(p: Hunter, hud) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	if dir == "":
		return
	DirAccess.make_dir_recursive_absolute(dir)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	p.ak.cd["e"] = 7.5
	p.ak.cd["x"] = 12.3
	p.dashes = 0.5
	p.kin.throw_cd = 0.4
	await _drawn(hud)
	for i in 4:
		await main.get_tree().process_frame
	var img := main.get_viewport().get_texture().get_image()
	var sz := img.get_size()
	var bar := Rect2i(0, sz.y - 200, sz.x, 200)
	img.save_png(dir.path_join("cooldown_text_full.png"))
	img.get_region(bar).save_png(dir.path_join("cooldown_text_bar.png"))
	print("COOLDOWNTEXT shots in ", dir, " (", sz, ")")
