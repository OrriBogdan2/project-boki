extends RefCounted
## --bot-kit-use[=<arch>] [--kit-use-t=<s>] [--kit-use-seeds=a,b,c]: bot-vs-bot duels in the duel room,
## one Hunter at a time (both fighters play that Hunter), counting what the bots really press in each
## slot: presses, holds, recasts and hits, plus dashes and glides (table in docs/BOT_KIT_USE.md).
## Fails when a slot a bot should use is never used, or a hold-only slot is only ever tapped.
## Never touches the save.

## arch -> the counters (keys of the tally) that must be above zero: the slots with a hold or a recast.
const MUST := {
	"juggernaut": ["rmb hold", "lunge perfect", "chain reel"],
	"bulwark": ["rmb hold", "hammer throw", "hammer recall", "shield charge"],
	"rimewright": ["skate", "rink freeze"],
	"dolm": ["hop recast"],
	"ashwick": ["cloak pull"],
}
const ALWAYS := ["lmb hit", "rmb press", "e", "ultimate", "dash", "glide"]       # every Hunter, every duel
const NO_ULT := ["tender"]       # (its ultimate heals a teammate: a duel has none)
const COLS := ["lmb hit", "rmb press", "rmb hold", "rmb hit", "e", "e hit", "ultimate", "dash", "glide"]

var bad := 0

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var only := ""
	var secs := 120.0
	var seeds := [3, 5, 9]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bot-kit-use="): only = a.substr(14)
		if a.begins_with("--kit-use-t="): secs = float(a.substr(12))
		if a.begins_with("--kit-use-seeds="): seeds = Array(a.substr(16).split(",")).map(func(x): return int(x))
	for arch in Arch.ids():
		if only == "" or only == arch:
			_duel(main, String(arch), seeds, secs)
	print("KITUSE done, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _duel(main: Node, arch: String, seeds: Array, secs: float) -> void:
	var n := {}
	for sd in seeds:
		var o := Match.duel_opts()
		o.merge({"autoplay": true, "seed": sd, "arch": arch, "cls": Arch.weight(arch)}, true)
		var m := Match.new()
		main.add_child(m)
		m.start(o)
		m.set_process(false)
		m.duel.arch = arch
		m.duel.spawn_bot()
		var fighters: Array = [m.player, m.duel.bot]
		var instant := float(Arch.def(arch).get("rmb", {}).get("hold", 0.0)) <= 0.0      # no hold: the press casts
		var cb_use := func(who, id, slot): if who in fighters: _use(n, String(id), String(slot), instant)
		var cb_hit := func(by, _t, _d, tags): if by in fighters: _hit(n, tags)
		CombatBus.ability_used.connect(cb_use)
		CombatBus.hit_landed.connect(cb_hit)
		var prev := {}
		while m.time < secs and not m.over:
			m.step(Match.DT)
			for h in fighters:
				_poll(n, h, prev)
		for h in fighters:
			_totals(n, h.ak)
		CombatBus.ability_used.disconnect(cb_use)
		CombatBus.hit_landed.disconnect(cb_hit)
		m.duel.teardown()
		m.queue_free()
	_report(arch, n)

func _add(n: Dictionary, k: String, by := 1) -> void:
	n[k] = int(n.get(k, 0)) + by

func _use(n: Dictionary, id: String, slot: String, instant: bool) -> void:
	if slot == "secondary" and instant and id.ends_with("_rmb"): _add(n, "rmb press")
	elif slot == "kin": _add(n, "e")
	elif slot == "dodge" or slot == "ultimate": _add(n, slot)
	elif id.ends_with("_throw") or id.ends_with("_recall"): _add(n, "hammer " + id.get_slice("_", 1))

func _hit(n: Dictionary, tags: Array) -> void:
	var t := String(tags[0]) if not tags.is_empty() else ""
	_add(n, "hit")
	if "shot" in tags or t == "primary": _add(n, "lmb hit")
	elif t == "utility": _add(n, "rmb hit")
	elif t == "k1": _add(n, "e hit")

## Edges of the kits' input states (per step): RMB press / hold / tap, glides, skates, freezes, hop chains.
func _poll(n: Dictionary, h: Hunter, prev: Dictionary) -> void:
	var k: ArchKit = h.ak
	var p: Dictionary = prev.get(h, {})
	var now := {"rmb": k.rmb_down, "glide": h.gliding, "dash": k.dash_press_at}
	if k is RimewrightKit:
		now["skate"] = not k.rinkrun.is_empty()
		now["freeze"] = not k.wall.is_empty() and bool(k.wall.get("frozen", false))
	if k is DolmKit:
		now["hops"] = k.hop.chaining()
	if k is BulwarkKit:
		now["charge"] = k.front_t > 0.0
	if now["rmb"] and not p.get("rmb", false): _add(n, "rmb press")
	if p.get("rmb", false) and not now["rmb"]:
		var need := float(k.rmb_def().get("hold", 0.0))
		_add(n, "rmb hold" if need > 0.0 and k.rmb_t >= need else "rmb tap")
	if now["glide"] and not p.get("glide", false): _add(n, "glide")
	if now["dash"] != p.get("dash", now["dash"]): _add(n, "dash")
	if now.get("skate", false) and not p.get("skate", false): _add(n, "skate")
	if now.get("freeze", false) and not p.get("freeze", false): _add(n, "rink freeze")
	if now.get("hops", false) and not p.get("hops", false): _add(n, "hop chain")
	if now.get("charge", false) and not p.get("charge", false): _add(n, "shield charge")
	prev[h] = now

## The kits' own counters, once per match.
func _totals(n: Dictionary, k: ArchKit) -> void:
	if k is JuggernautKit:
		_add(n, "lunge perfect", k.perfects)
		_add(n, "chain reel", k.warchain.reels)
	elif k is BulwarkKit:
		_add(n, "shield slam", k.shield_slams)
	elif k is DolmKit:
		_add(n, "hops", k.hop.hops)
	elif k is AshwickKit:
		_add(n, "cloak pull", k.pulled)

func _report(arch: String, n: Dictionary) -> void:
	n["hop recast"] = int(n.get("hops", 0)) - int(n.get("hop chain", 0))
	var cells: Array = COLS.map(func(c): return str(int(n.get(c, 0))))
	var extras: Array = []
	for key in n.keys():
		var shown: bool = key in MUST.get(arch, []) or key == "shield slam"
		if shown and not key in COLS:
			extras.append("%s %d" % [key, n[key]])
	print("KITUSE | %s | %s | %s |" % [arch, " | ".join(cells), ", ".join(extras)])
	var want: Array = ALWAYS + MUST.get(arch, [])
	for key in want:
		if key == "ultimate" and arch in NO_ULT: continue
		if int(n.get(key, 0)) <= 0:
			print("KITUSE FAIL %s never uses '%s'" % [arch, key])
			bad += 1
	if arch == "bulwark" and int(n.get("rmb tap", 0)) * 4 > int(n.get("rmb hold", 0)):
		print("KITUSE FAIL bulwark taps the Aegis (%d taps, %d holds)" % [n.get("rmb tap", 0), n.get("rmb hold", 0)])
		bad += 1
