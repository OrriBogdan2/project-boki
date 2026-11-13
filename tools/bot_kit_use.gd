extends RefCounted
## --bot-kit-use=<archetype> [--seeds=3] [--secs=120] [--map=arena]: a headless bot-vs-bot duel of one Hunter's kit
## against itself, counting what the bots do with each slot (docs/BOT_KIT_USE.md). Per seed both bots
## fight in the duel room for --secs; the tool sums presses, holds, recasts and hits per slot and prints
## one BOTKIT line per slot. The duel room is an empty island; --map=arena fights on the Arena's map (its
## pillars and walls, for the Heavy Shot's wall pin) with its dummies taken out. The recasts and holds the
## kit's data describes are read from the kit's own state each step (see _probe).

const DT := 1.0 / 60.0

## The Bot, counting what it presses right after it decides (the tool swaps it in for Match.bot_brain).
class Probe extends Bot:
	var counts: Dictionary = {}
	func bump(key: String, n := 1) -> void:
		counts[key] = int(counts.get(key, 0)) + n
	func tick(m: Match, h: Hunter, dt: float) -> void:
		var was := {}
		for k in ["sig", "sec", "dash", "ult"]:
			was[k] = bool(h.inp.get(k, false))
		var ak: ArchKit = h.ak
		super.tick(m, h, dt)
		if ak == null:
			return
		if h.inp.get("sig", false) and not was["sig"]:
			bump("e_recast_press" if ak.e_t > 0.0 and ak.e_recastable() else "e_press")
		if h.inp.get("sec", false) and not was["sec"]:
			bump("rmb_press_held" if ak.held("rmb") else "rmb_press")
		if h.inp.get("dash", false) and not was["dash"]:
			bump("dash_press_air" if not h.grounded else "dash_press")

var main: Node
var tag_hits: Dictionary = {}       # "hero:slot" -> hits landed by the hunter on a foe
var casts: Dictionary = {}          # "hero:slot" -> casts (CombatBus.ability_used)
var resets: Dictionary = {}         # hero -> dash resets (CombatBus.dash_reset_cue)

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var arch := ""
	var seeds := 3
	var secs := 120.0
	var map := "duel"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bot-kit-use="): arch = a.substr(14)
		if a.begins_with("--seeds="): seeds = int(a.substr(8))
		if a.begins_with("--secs="): secs = float(a.substr(7))
		if a.begins_with("--map="): map = a.substr(6)
	var total := {}
	for s in seeds:
		var one := await _duel(arch, 1000 + s * 77, secs, map)
		for k in one:
			total[k] = float(total.get(k, 0.0)) + float(one[k])
	var keys := total.keys()
	keys.sort()
	for k in keys:
		print("BOTKIT %s %s %s" % [arch, k, str(snappedf(float(total[k]), 0.1))])
	print("BOTKIT %s DONE" % arch)
	main.get_tree().quit()

## Meeko's Hearth Call needs a squadmate: each side gets a Vex beside it.
func _mate(m: Match, team: int, at: Vector3) -> Hunter:
	var kit := {"arch": "gunslinger", "weapon": Arch.signature("gunslinger"), "perk": ""}
	var rec: Dictionary = m.bot_kin_record()
	var w := Arch.weight("gunslinger")
	var mate: Hunter = m.make_hunter(m.next_id("mate"), team, w, "Mate", "bot", rec, at, kit, {})
	mate.lives = 99
	return mate

func _duel(arch: String, seed_n: int, secs: float, map: String) -> Dictionary:
	seed(seed_n)
	var o := Match.arena_opts(arch) if map == "arena" else Match.duel_opts()
	o["seed"] = seed_n
	o["autoplay"] = true
	o["arch"] = arch
	o["cls"] = Arch.weight(arch)
	o["weapon"] = Arch.signature(arch)
	var m := Match.new()
	main.add_child(m)
	await m.start(o)
	m.set_process(false)
	var foe: Hunter
	if map == "arena":
		for d in m.arena.dummies:
			m.hunters.erase(d["h"])
			(d["h"] as Hunter).queue_free()
		m.arena.dummies.clear()
		m.arena.bot_mode = "fighting"
		m.arena.set_bot_arch(arch)
		foe = m.arena.bot
		foe.unlock_all()
	else:
		m.duel.arch = arch
		m.duel.spawn_bot()
		foe = m.duel.bot
	var probe := Probe.new()
	m.bot_brain = probe
	var hs: Array = [m.player, foe]
	if arch == "tender":
		hs.append_array([_mate(m, 0, m.player.pos + Vector3(2, 0, 0)), _mate(m, 1, foe.pos + Vector3(2, 0, 0))])
	for h in hs:
		h.ai = probe.new_mind(m.rng, 0.7)
		h.lvl = 12
	var kit_hs: Array = hs.filter(func(h): return h.ak != null and h.ak.id == arch)
	var kits: Array = kit_hs.map(func(h): return h.ak)
	var cb_hit := func(by, t, d, tags):
		var who = by.owner_h if by is Kin and (by as Kin).owner_h else by
		if who in kit_hs and t in hs and who != t:
			var slot := _slot_of(tags)
			tag_hits["%s:%s" % [arch, slot]] = int(tag_hits.get("%s:%s" % [arch, slot], 0)) + 1
	var cb_use := func(c, id, slot):
		if c in kit_hs:
			casts["%s:%s" % [arch, slot]] = int(casts.get("%s:%s" % [arch, slot], 0)) + 1
	var cb_reset := func(h, src):
		if h in kit_hs:
			resets[arch] = int(resets.get(arch, 0)) + 1
	CombatBus.hit_landed.connect(cb_hit)
	CombatBus.ability_used.connect(cb_use)
	CombatBus.dash_reset_cue.connect(cb_reset)
	var out := {}
	var t := 0.0
	var n := 0
	while t < secs:
		m.step(DT)
		t += DT
		n += 1
		for h in hs:
			if h.downed or h.dead:
				continue
			if h in kit_hs:
				_probe(arch, h as Hunter, out)
		if n % 120 == 0:
			await main.get_tree().process_frame
	CombatBus.hit_landed.disconnect(cb_hit)
	CombatBus.ability_used.disconnect(cb_use)
	CombatBus.dash_reset_cue.disconnect(cb_reset)
	for k in kits:
		_final(arch, k, out)
	for k in probe.counts:
		out[k] = float(probe.counts[k])
	for k in tag_hits:
		out["hits_" + String(k).get_slice(":", 1)] = float(tag_hits[k])
	for k in casts:
		out["casts_" + String(k).get_slice(":", 1)] = float(casts[k])
	out["dash_resets"] = float(resets.get(arch, 0))
	m.queue_free()
	tag_hits.clear()
	casts.clear()
	resets.clear()
	return out

## Which slot a hit's tags belong to.
func _slot_of(tags: Array) -> String:
	for t in ["ult", "utility", "signature", "kin"]:
		if tags.has(t): return String(t)
	return String(tags[0]) if not tags.is_empty() else "primary"

## Per-step reads of the kit's own state: the holds and phases that edges on h.inp can't show.
func _probe(arch: String, h: Hunter, out: Dictionary) -> void:
	var ak: ArchKit = h.ak
	if ak == null:
		return
	if ak.held("rmb"):
		out["rmb_hold_s"] = float(out.get("rmb_hold_s", 0.0)) + DT
	if ak.held("dash"):
		out["dash_hold_s"] = float(out.get("dash_hold_s", 0.0)) + DT
	if h.ex_cd > float(_ex_cd.get(h, 0.0)) + 1.0:
		out["air_dash_slot_used"] = float(out.get("air_dash_slot_used", 0.0)) + 1.0
	_ex_cd[h] = h.ex_cd
	if arch == "tender":
		var hearth: Dictionary = (h.ak as TenderKit).hearth
		var tossed: bool = bool(hearth.get("tossed", false))
		if tossed and not _tossed.get(h, false):
			out["e_thrown"] = float(out.get("e_thrown", 0.0)) + 1.0
		_tossed[h] = tossed
	if arch == "mage":
		_mage_x(h.ak as MageKit, out)
		if (h.ak as MageKit).strikes.any(func(st): return String(st["phase"]) == "flick"):
			out["e_hold_s"] = float(out.get("e_hold_s", 0.0)) + DT

var _ex_cd := {}
var _tossed := {}

## Kitefall: how each hang ended (a press or an attack, or the hover timer), read as the hang turns into the fall.
var _x_air_t := {}
func _mage_x(k: MageKit, out: Dictionary) -> void:
	if k.ult.busy() and k.ult.phase() == MageUlt.AIR:
		_x_air_t[k] = float(k.ult.leap["t"])
	elif _x_air_t.has(k):
		var timer: bool = float(_x_air_t[k]) >= float(k.x_def()["hover"]) - 0.05
		var key := "x_down_hover_timer" if timer else "x_down_press_or_fire"
		out[key] = float(out.get(key, 0.0)) + 1.0
		_x_air_t.erase(k)

## The kit's own counters at the end of the duel (the same ones its combo checks read).
func _final(arch: String, ak: ArchKit, out: Dictionary) -> void:
	var c := {}
	match arch:
		"mage":
			var k := ak as MageKit
			c = {"x_casts": k.ult.casts, "x_foes_hit": k.ult.hits, "slams": k.slams, "blowouts": k.blowouts}
		"dredge":
			var k := ak as DredgeKit
			c = {
				"anchors": k.anchors,
				"x_casts": k.broadside.casts,
				"x_waves": k.broadside.waves,
				"x_stopped": k.broadside.stopped,
				"x_slug_hits": k.broadside.slug_hits,
				"grapples": k.grapples,
				"quakes": k.quakes,
			}
		"tender":
			var k := ak as TenderKit
			c = {
				"x_calls": int(k.stats["calls"]),
				"embers": int(k.stats["embers"]),
				"rescues": int(k.stats["rescues"]),
			}
		"thief":
			var k := ak as ThiefKit
			c = {
				"e_blinks": k.blinks,
				"bolts": k.bolts,
				"primed_hits": k.primed_hits,
				"vault_resets": k.chain.resets,
				"bola_pairs": k.bola_pairs,
				"x_casts": k.encore.casts,
				"x_blades": k.encore.blades,
			}
		"archer":
			var k := ak as ArcherKit
			c = {
				"wall_pins": k.pins,
				"heavy_kicks": k.heavy_kicks,
				"cremations": k.cremations,
				"x_arrows": k.ult.fired,
				"x_executes": k.ult.executes,
			}
		"ostra":
			var k := ak as OstraKit
			c = {
				"swaps": k.swaps,
				"swapped_foes": k.swapped_foes,
				"pops": k.pops,
				"early_pops": k.early_pops,
				"seed_denied": k.seed_denied,
				"denied_swaps": k.denied_swaps,
				"x_casts": k.well.casts,
				"x_caught": k.well.caught_hunters,
			}
	for key in c:
		out[key] = float(out.get(key, 0.0)) + float(c[key])
