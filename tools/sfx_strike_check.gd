extends RefCounted
## --sfx-strike-check: does each Hero ability's own sound land on what it belongs to? Every move of the 12 kits
## (LMB tap and hold, RMB tap and hold, E, R) is pressed once in a real match at a dummy 3 m away, and per frame
## it logs the Hero's own fire/cast/impact sounds (content/sfx/<arch>.json), the dummy's damage (the gameplay hit)
## and the clip's strike: the frame the faster hand moves fastest in the skeleton, as played (blends and all).
## Each sound is measured against the nearer of the strike and the hit; over SYNC_MAX it is listed (ROW lines,
## docs/art/SFX_TIMING.md). Wind-up sounds (a draw, a tell, a charge) belong before the strike and are not timed.
## Asserts the moves fixed to play their sound from the event itself (FIXED): on that event, within SYNC_MAX.
## Never touches the save.

const DT := 1.0 / 60.0
const ARCHES := ["archer", "ashwick", "bulwark", "dolm", "dredge", "gunslinger", "juggernaut", "mage", "ostra",
	"rimewright", "tender", "thief"]
const MOVES := ["lmb", "lhold", "rmb", "hold", "e", "r"]
const WATCH := 2.0             # s watched after each press
const HELD := 0.5              # s a held button stays down
const SYNC_MAX := 0.05         # s a sound may sit off its strike or hit before it is listed
const STRIKE_MIN := 8.0        # m/s: a hand slower than this at its fastest has no strike to see (a rifle's aim)
const WIND := ["wind", "aim", "draw", "charge", "tell", "summon", "place", "count", "whirl", "hum", "creak",
	"shield_up", "pilot", "spin", "leap", "prime"]
## arch -> move -> [the sound fixed to play from its own event, that event: "strike", "hit" or "rise" (a Stone Row's
## first rock up)]
const FIXED := {"bulwark": {"lmb": ["bjorn_throw", "strike"]}, "dolm": {"e": ["br_raise", "rise"]}}

var A
var bad := 0

func ok(cond: bool, what: String) -> void:
	print("SFXSTRIKE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	A = load("res://tools/archetype_check.gd").new()
	A.main = main
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--strike-only="):
			only = a.get_slice("=", 1)
	for arch: String in ARCHES:
		if only != "" and arch != only:
			continue
		for mv: String in MOVES:
			var r := measure(arch, mv)
			print("ROW | %s | %s | %s |" % [arch, mv, _row(r)])
			if FIXED.get(arch, {}).has(mv):
				var fx: Array = FIXED[arch][mv]
				var off := _offset(r, fx[0], [fx[1]])
				ok(not _late(off), "%s %s: %s on its %s (%+.0f ms)" % [arch, mv, fx[0], fx[1], off * 1000.0])
	print("SFXSTRIKE_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

static func _own(arch: String) -> Dictionary:
	var f := FileAccess.open("res://content/sfx/%s.json" % arch, FileAccess.READ)
	return (JSON.parse_string(f.get_as_text()) as Dictionary).get("sounds", {}) if f else {}

static func _wind(sname: String) -> bool:
	for w: String in WIND:
		if sname.contains(w):
			return true
	return false

## s from sound `sname`'s first play to the nearest of the `events` (INF: it never played or none happened).
static func _offset(r: Dictionary, sname: String, events := ["strike", "hit", "rise"]) -> float:
	for s: Array in r["snd"]:
		if s[0] == sname:
			var best := INF
			for ev: String in events:
				for at: float in (r[ev] if r[ev] is Array else [r[ev]]):
					if at >= 0.0 and absf(float(s[1]) - at) < absf(best):
						best = float(s[1]) - at
			return best
	return INF

## Past SYNC_MAX, counted in whole ms (a frame is 16.7 ms; 3 frames round to exactly 50).
static func _late(off: float) -> bool:
	return absi(roundi(off * 1000.0)) > roundi(SYNC_MAX * 1000.0)

## strike | hit | each sound @ its time (ms off its nearer event, "!" past SYNC_MAX)
static func _row(r: Dictionary) -> String:
	var parts: Array = []
	var seen := {}
	for s: Array in r["snd"]:
		if seen.has(s[0]) or seen.size() >= 4:
			continue
		seen[s[0]] = true
		var tag := "%s@%d" % [s[0], roundi(float(s[1]) * 1000.0)]
		if _wind(String(s[0])):
			parts.append(tag + " (wind-up)")
			continue
		var off := _offset(r, String(s[0]))
		if is_finite(off):
			parts.append("%s (%+d%s)" % [tag, roundi(off * 1000.0), " !" if _late(off) else ""])
		else:
			parts.append(tag)
	var st := "%d %s" % [roundi(float(r["strike"]) * 1000.0), r["clip"]] if float(r["strike"]) >= 0.0 else "-"
	var ht := str(roundi(float(r["hit"][0]) * 1000.0)) if not r["hit"].is_empty() else "-"
	return "%s | %s | %s" % [st, ht, ", ".join(parts)]

## One press of `mv` on a fresh match. Times in s from the press.
func measure(arch: String, mv: String) -> Dictionary:
	var r: Array = A.setup(arch, 3.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var own := _own(arch)
	for f in 20:
		_frame(m, P)
	var sk := _skel(P)
	var hands: Array = []
	for nm in ["hand.R", "hand.L"]:
		if sk and sk.find_bone(nm) >= 0:
			hands.append(sk.find_bone(nm))
	var prev := {}
	var out := {"snd": [], "hit": [], "strike": -1.0, "clip": "", "rise": -1.0}
	var rocks := (P.ak as DolmKit).rocks_made if P.ak is DolmKit else 0
	var fastest := STRIKE_MIN
	var hp := T.hp
	for f in int(WATCH / DT):
		var t := f * DT
		var held := f < int(HELD / DT)
		P.inp["fire"] = (mv == "lmb" and f == 0) or (mv == "lhold" and held)
		P.inp["sec"] = mv in ["rmb", "hold"] and f == 0
		P.inp["sec_hold"] = mv == "hold" and held
		P.inp["sig"] = mv == "e" and f == 0
		if mv == "r" and f == 0:
			P.ak.cd["x"] = 0.0
			P.ult = 1.0
			P.ak.cast_ult()
		A.aim_at(P, T.pos)
		Sfx.listener = P.pos
		Sfx.last_played.clear()          # every play this frame lands in last_played (no spacing across frames)
		Sfx.recent.clear()
		_frame(m, P)
		for s: String in Sfx.last_played:
			if String(own.get(s, "")) in ["fire", "impact", "cast"]:
				out["snd"].append([s, t])
		if T.hp < hp - 0.01:
			out["hit"].append(t)
		hp = T.hp
		if P.ak is DolmKit and (P.ak as DolmKit).rocks_made > rocks and float(out["rise"]) < 0.0:
			out["rise"] = t
		var c := _clips(P)
		var v := 0.0
		for bi: int in hands:
			var o := sk.get_bone_global_pose(bi).origin
			v = maxf(v, o.distance_to(prev.get(bi, o)) / DT)
			prev[bi] = o
		if f >= 2 and c and c.cur != "" and v > fastest:
			fastest = v
			out["strike"] = t
			out["clip"] = c.cur
	m.queue_free()
	return out

func _frame(m: Match, P: Hunter) -> void:
	m.step(DT)
	P.render(DT, 1.0)
	if P.model and P.model.has_node("Warden/Sync"):
		var sync: Node = P.model.get_node("Warden/Sync")
		sync.set_process(false)
		sync.call("_process", DT)

func _clips(h: Hunter) -> WardenClips:
	if not (h.model and h.model.has_node("Warden/Sync")):
		return null
	return h.model.get_node("Warden/Sync").get("clips") as WardenClips

func _skel(h: Hunter) -> Skeleton3D:
	if not (h.model and h.model.has_node("Warden")):
		return null
	var all := h.model.get_node("Warden").find_children("*", "Skeleton3D", true, false)
	return all[0] as Skeleton3D if not all.is_empty() else null
