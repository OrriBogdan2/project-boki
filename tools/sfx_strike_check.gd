extends RefCounted
## --sfx-strike-check: does each Hero ability's own sound land on what it belongs to? Every move of the 12 kits
## (LMB tap and hold, RMB tap and hold, E, R) is pressed once in a real match at a dummy 3 m away, and per frame
## it logs the Hero's own fire/cast/impact/signature sounds (content/sfx/<arch>.json), the dummy's damage (the
## gameplay hit), the release (a shot of the Hero's own appearing: a throw, a bolt, a swing's reach; a rock of
## Tenzo's rising), and the clip's strike: the frame the faster hand moves fastest in the skeleton, as played (blends
## and all). A sound counts from when it is heard: its play plus its own lead-in (the first 10 ms of its file at
## LOUD of its peak). Each sound is measured against the nearest of those events; over SYNC_MAX it is listed (ROW
## lines, docs/art/SFX_TIMING.md). Wind-up sounds (a draw, a tell, a charge) belong before the beat and are not timed.
## Asserts the moves fixed to play their sound from the event itself (FIXED) on that event, and per kit that every
## other timed sound is within SYNC_MAX of an event of its move or listed as right where it plays (KNOWN).
## Never touches the save.

const DT := 1.0 / 60.0
const ARCHES := ["archer", "ashwick", "bulwark", "dolm", "dredge", "gunslinger", "juggernaut", "mage", "ostra",
	"rimewright", "tender", "thief"]
const MOVES := ["lmb", "lhold", "rmb", "hold", "e", "r"]
const WATCH := 2.0             # s watched after each press
const HELD := 0.5              # s a held button stays down
const SYNC_MAX := 0.05         # s a sound may sit off its strike or hit before it is listed
const STRIKE_MIN := 8.0        # m/s: a hand slower than this at its fastest has no strike to see (a rifle's aim)
## Wind-up sounds, by a whole part of the name ("spin" is bjorn_spin, not br_spine); br_crack is Stone Row's tell
const WIND := ["wind", "aim", "draw", "overdraw", "charge", "tell", "summon", "place", "count", "whirl", "hum",
	"creak", "shield_up", "pilot", "spin", "leap", "prime", "br_crack"]
const LOUD := 0.3              # of a file's peak: where its lead-in ends (a swell is heard from about here)
## arch -> move -> [the sound fixed to play from its own event, that event: "strike", "hit", "shot" (the release)
## or "rise" (the first rock of a Stone Row or a Basalt Spine up)]
const FIXED := {"bulwark": {"lmb": ["bjorn_throw", "strike"]}, "dolm": {"e": ["br_raise", "rise"]},
	"dredge": {"rmb": ["dr_throw", "shot"], "hold": ["dr_throw", "shot"]}}
## Sounds past SYNC_MAX that are right where they play (on their own event; the reason is in SFX_TIMING.md):
## arch -> move -> [sound]. Any other own sound past SYNC_MAX fails its kit's row.
const KNOWN := {
	"archer": {"e": ["pin_rain"]},
	"ashwick": {"lhold": ["ashwick_tank_hiss"], "e": ["lw_shield"], "r": ["lw_jet", "lw_jet_land"]},
	"dolm": {"lhold": ["br_punch"], "r": ["br_spine"]},
	"dredge": {"rmb": ["dredge_coin_jingle"], "hold": ["dredge_coin_jingle"]},
	"gunslinger": {"rmb": ["gunslinger_grenade_thunk"], "hold": ["gunslinger_grenade_thunk"], "r": ["vn_nuke_fire"]},
	"juggernaut": {"r": ["juggernaut_heal"]},
	"ostra": {"e": ["os_seed"]},
	"tender": {"e": ["tender_lantern_chime"]},
}

var A
var bad := 0
var lead_in := {}              # sound name -> s from its start to where it is heard

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
		var off_beat: Array = []
		for mv: String in MOVES:
			var r := measure(arch, mv)
			print("ROW | %s | %s | %s |" % [arch, mv, _row(r)])
			if FIXED.get(arch, {}).has(mv):
				var fx: Array = FIXED[arch][mv]
				var off := _offset(r, fx[0], [fx[1]])
				ok(not _late(off), "%s %s: %s on its %s (%+.0f ms)" % [arch, mv, fx[0], fx[1], off * 1000.0])
			for sname: String in _off_beat(r):
				if not sname in KNOWN.get(arch, {}).get(mv, []):
					off_beat.append("%s %s" % [mv, sname])
		ok(off_beat.is_empty(), "%s: every own sound on its strike, release, hit or rise " % arch + ", ".join(off_beat))
	print("SFXSTRIKE_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

static func _own(arch: String) -> Dictionary:
	var f := FileAccess.open("res://content/sfx/%s.json" % arch, FileAccess.READ)
	return (JSON.parse_string(f.get_as_text()) as Dictionary).get("sounds", {}) if f else {}

static func _wind(sname: String) -> bool:
	for w: String in WIND:
		if ("_%s_" % sname).contains("_%s_" % w):
			return true
	return false

## s from the start of sound `sname`'s file (its first take) to its first 10 ms at LOUD of its peak: a whoosh
## into a cut is heard that much after it plays. Read from the 16-bit .wav itself (the import is compressed).
func _lead_in(sname: String) -> float:
	if lead_in.has(sname):
		return lead_in[sname]
	var path := "res://audio/%s.wav" % sname
	if not FileAccess.file_exists(path):
		path = "res://audio/%s_1.wav" % sname
	var b := FileAccess.get_file_as_bytes(path)
	var at := 0.0
	var ch := 1
	var rate := 44100
	var i := 12
	while i + 8 <= b.size():
		var n := b.decode_u32(i + 4)
		var id := b.slice(i, i + 4).get_string_from_ascii()
		if id == "fmt ":
			if b.decode_u16(i + 22) != 16:
				break                   # (not 16-bit: read as no lead-in)
			ch = b.decode_u16(i + 10)
			rate = b.decode_u32(i + 12)
		elif id == "data":
			at = _loud_at(b.slice(i + 8, i + 8 + n), ch * 2, rate / 100)
			break
		i += 8 + n + (n & 1)
	lead_in[sname] = at
	return at

## s to the first window of `win` frames (`frame` bytes each) whose loudest sample reaches LOUD of the peak.
static func _loud_at(pcm: PackedByteArray, frame: int, win: int) -> float:
	var peaks := PackedInt32Array()
	var top := 1
	for w in range(0, pcm.size() - 1, win * frame):
		var p := 0
		for j in range(w, mini(w + win * frame, pcm.size() - 1), 2):
			p = maxi(p, absi(pcm.decode_s16(j)))
		peaks.append(p)
		top = maxi(top, p)
	for w in peaks.size():
		if peaks[w] >= top * LOUD:
			return w * 0.01
	return 0.0

## s from when sound `sname` is first heard to the nearest of the `events` (INF: it never played or none happened).
static func _offset(r: Dictionary, sname: String, events := ["strike", "hit", "shot", "rise"]) -> float:
	for s: Array in r["snd"]:
		if s[0] == sname:
			var best := INF
			for ev: String in events:
				for at: float in (r[ev] if r[ev] is Array else [r[ev]]):
					if at >= 0.0 and absf(float(s[2]) - at) < absf(best):
						best = float(s[2]) - at
			return best
	return INF

## The timed sounds of a move heard past SYNC_MAX from every event of it (wind-ups are not timed).
static func _off_beat(r: Dictionary) -> Array:
	var out: Array = []
	for s: Array in r["snd"]:
		var off := _offset(r, String(s[0]))
		if not _wind(String(s[0])) and not out.has(s[0]) and is_finite(off) and _late(off):
			out.append(s[0])
	return out

## Past SYNC_MAX, counted in whole ms (a frame is 16.7 ms; 3 frames round to exactly 50).
static func _late(off: float) -> bool:
	return absi(roundi(off * 1000.0)) > roundi(SYNC_MAX * 1000.0)

## strike | release | hit | each sound @ its play (+ its lead-in when over a frame; ms off its nearest event,
## "!" past SYNC_MAX)
static func _row(r: Dictionary) -> String:
	var parts: Array = []
	var seen := {}
	for s: Array in r["snd"]:
		if seen.has(s[0]) or seen.size() >= 4:
			continue
		seen[s[0]] = true
		var tag := "%s@%d" % [s[0], roundi(float(s[1]) * 1000.0)]
		if float(s[2]) - float(s[1]) > DT:
			tag += "+%d" % roundi((float(s[2]) - float(s[1])) * 1000.0)
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
	var rel: Array = r["shot"].duplicate()
	if float(r["rise"]) >= 0.0:
		rel.append(r["rise"])
	var sh := str(roundi(float(rel.min()) * 1000.0)) if not rel.is_empty() else "-"
	return "%s | %s | %s | %s" % [st, sh, ht, ", ".join(parts)]

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
	var out := {"snd": [], "hit": [], "shot": [], "strike": -1.0, "clip": "", "rise": -1.0}
	var rocks := _rocks(P)
	var sid := m.shot_n
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
			if String(own.get(s, "")) in ["fire", "impact", "cast", "signature"]:
				out["snd"].append([s, t, t + _lead_in(s)])
		if T.hp < hp - 0.01:
			out["hit"].append(t)
		hp = T.hp
		for sd: Dictionary in m.shots:
			if sd["by"] == P and int(sd["sid"]) > sid:
				sid = int(sd["sid"])
				if out["shot"].is_empty() or out["shot"][-1] != t:
					out["shot"].append(t)
		if _rocks(P) > rocks and float(out["rise"]) < 0.0:
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

## Rocks Tenzo has raised: Stone Row's and Basalt Spine's.
static func _rocks(h: Hunter) -> int:
	var k := h.ak as DolmKit
	return k.rocks_made + k.spine.rocks_raised if k else 0

func _clips(h: Hunter) -> WardenClips:
	if not (h.model and h.model.has_node("Warden/Sync")):
		return null
	return h.model.get_node("Warden/Sync").get("clips") as WardenClips

func _skel(h: Hunter) -> Skeleton3D:
	if not (h.model and h.model.has_node("Warden")):
		return null
	var all := h.model.get_node("Warden").find_children("*", "Skeleton3D", true, false)
	return all[0] as Skeleton3D if not all.is_empty() else null
