extends RefCounted
## --glove-band-check (PARITY FIRST, docs/KIT_PARITY.md): gloves are ours, so none may outshine the
## twelve kits' E abilities at source numbers. Per glove, at every rarity (Common to Legendary, with
## its shorter cooldown), three figures are held to the kits' maximum:
##   damage per cooldown second (dmg / cd), CC seconds per cast (stun + slow + pull window),
##   travel metres per cast (the move the glove itself gives: blink, hook, launch range, haste run).
## The median is printed with the maximum. Kits are read from content/archetypes (rank 1, one target
## hit by everything, full duration); a kit that only heals, shields or builds a wall counts 0.
## Prints GLOVEBAND lines and "GLOVEBAND DONE, n checks, failures: n".

const RUN_MPS := 5.4      # base run speed (m/s): what a Decoy glove's 35% haste adds to
const HASTE_K := 0.35     # extra run speed under haste (Hunter.haste_t uses 1.35x)

var bad := 0
var n := 0

func ok(cond: bool, what: String) -> void:
	n += 1
	print("GLOVEBAND %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## One kit's E at source numbers: {dmg, cd, cc, travel} (dmg and cc and travel per cast, cd in s).
func _kit(id: String) -> Dictionary:
	var e: Dictionary = Arch.def(id)["e"]
	var dmg := float(e.get("dmg", 0.0))
	var cc := 0.0
	var travel := 0.0
	match id:
		"archer":      # Hail Wall: every tick lands, slowed all through
			dmg *= float(e["time"]) / float(e["every"])
			cc = float(e["time"])
		"ashwick": cc = (float(e["radius"]) - float(e["gap"])) / float(e["pull_speed"])      # the drag in
		"dredge": cc = float(e["stun"])
		"mage": cc = float(e["grounded"])
		"ostra": dmg *= float(e["dmg_max_k"])      # a fully grown seed
		"juggernaut": travel = float(e["range"])      # hauled to the hook (the tether's 24 m is ours, not the source's)
		"thief":      # blink to the knife
			cc = float(e["slow_t"])
			travel = float(e["range"])
	return {"dmg": dmg, "cd": float(e["cooldown"]), "cc": cc, "travel": travel}

## A glove's {dmg, cd, cc, travel} at a rarity. Effect blocks are walked with every nested hit counted once;
## the launch gloves' travel is the ballistic range or peak height of their launch (content "launch").
func _glove(id: String, rar: int) -> Dictionary:
	var out := {"dmg": 0.0, "cd": Gear.cd_of(id, rar), "cc": 0.0, "travel": 0.0}
	var pull := false
	var tele := 0.0
	for e in Gear.effects_of(id, rar):
		_walk(e, out)
		pull = pull or _has(e, "pull")
		tele = maxf(tele, _first(e, "telegraph", "time"))
	if pull:
		out["cc"] += tele      # the pull holds foes for the telegraph's length
	var lau: Dictionary = Gear.ALL[id].get("launch", {})
	if lau.has("up_mps"):
		var air := 2.0 * float(lau["up_mps"]) / Hunter.H_GRAV
		var peak := pow(float(lau["up_mps"]), 2.0) / (2.0 * Hunter.H_GRAV)
		out["travel"] = maxf(peak, float(lau.get("fwd_mps", 0.0)) * air)
	if lau.has("reach_m"):
		out["travel"] = maxf(float(lau["reach_m"]), float(lau["rise_m"]))
	return out

func _walk(e: Variant, out: Dictionary) -> void:
	if not (e is Dictionary):
		return
	var d: Dictionary = e
	out["dmg"] += float(d.get("dmg", 0.0))
	out["cc"] += float(d.get("stun", 0.0)) + float(d.get("slow", 0.0))
	match String(d.get("type", "")):
		"blink": out["travel"] += float(d["distance"])
		"projectile": if d.has("on_wall"): out["travel"] += float(d["range"])      # the rope pulls you along it
		"haste": out["travel"] += HASTE_K * RUN_MPS * float(d["time"])
	for k in d:
		if d[k] is Array:
			for sub in d[k]:
				_walk(sub, out)

func _has(e: Variant, type: String) -> bool:
	if not (e is Dictionary):
		return false
	if String(e.get("type", "")) == type:
		return true
	for k in e:
		if e[k] is Array and (e[k] as Array).any(func(s): return _has(s, type)):
			return true
	return false

## The first `key` of the first nested effect of `type` (0 when none).
func _first(e: Variant, type: String, key: String) -> float:
	if not (e is Dictionary):
		return 0.0
	if String(e.get("type", "")) == type:
		return float(e.get(key, 0.0))
	for k in e:
		if e[k] is Array:
			for s in e[k]:
				var v := _first(s, type, key)
				if v > 0.0:
					return v
	return 0.0

func _med(a: Array) -> float:
	var s := a.duplicate()
	s.sort()
	return (float(s[5]) + float(s[6])) * 0.5

func run(main: Node) -> void:
	var kits: Array = []
	for id in Arch.ids():
		var k := _kit(String(id))
		kits.append({"dmg_s": k["dmg"] / k["cd"], "cc": k["cc"], "travel": k["travel"]})
	ok(kits.size() == 12, "twelve kits' E abilities read")
	var cap := {}
	for key in ["dmg_s", "cc", "travel"]:
		var vals: Array = kits.map(func(k): return k[key])
		cap[key] = vals.max()
		print("GLOVEBAND kits %-7s median %.2f  max %.2f" % [key, _med(vals), cap[key]])
	for id in Gear.ALL:
		if not Gear.active(String(id)):
			continue
		for rar in range(1, 5):
			var g := _glove(String(id), rar)
			var f := {"dmg_s": g["dmg"] / g["cd"], "cc": g["cc"], "travel": g["travel"]}
			var inside := true
			for key in f:
				inside = inside and float(f[key]) <= float(cap[key]) + 0.001
			var rname: String = Data.RARITY[rar]["name"]
			var row := "%-8s %-9s dmg/s %.2f  cc %.2fs" % [id, rname, f["dmg_s"], f["cc"]]
			ok(inside, row + "  travel %.1fm  (cd %.1fs)" % [f["travel"], g["cd"]])
	print("GLOVEBAND DONE, %d checks, failures: %d" % [n, bad])
	main.get_tree().quit(1 if bad > 0 else 0)
