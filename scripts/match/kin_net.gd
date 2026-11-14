class_name KinNet
extends RefCounted
## What the Boki command system adds to the network (docs/decisions/0001, 0002, Net.VERSION 0.11.0). Everything
## still goes through scripts/core/net.gd; the Match calls these from its snapshot and event code.
##   - Kin snapshot: indices 19+ = [order (KinFollow.CMD_IDS index), down seconds left, rescue progress, fell in the abyss, rest seconds left (drained after a merge ultimate)]
##   - Hunter snapshot: index 26 = the merge form worn ("" when not merged), 27 = merge seconds left, 28/29 = shell now/max, 30 = the form's or rescue's pose id
##   - Events ["kcmd", kind, nid, x, y, z, extra]: throw (a Sic too), recall (Call back), hop (a leap to your side
##     or onto you), cmd (a new order; extra = its id), merge_leap, down, scoop, round, merge (extra = the form),
##     mcast (a merged form's cast: slot|x|z|radius|seconds), merge_end (extra = why), unbond (a captor no longer carries a Boki: KinTrack; extra = its uid; Net 0.17.0; the bond itself starts from the "caught" event, which now carries the owner's nid, and "gdrop" puts a dropped Boki back in the world), scan_start / scan_stop / scan_done (the capture beam, Capture; nid = the hunter, extra = the Boki's nid). The owner's game runs the rescue and the recovery timer; other
##     games get the state and play the moment.

const KIN_AT := 19
const HUNTER_AT := 26

static func kin_extra(k: Kin) -> Array:
	return [maxi(0, KinFollow.CMD_IDS.find(k.cmd)), snappedf(k.down_t, 0.1), snappedf(KinDowned.scoop_k(k), 0.05), 1 if k.down_void else 0, snappedf(k.rest_t, 0.1)]

static func apply_kin(k: Kin, it: Array) -> void:
	if it.size() <= KIN_AT + 4:
		return
	var ci := int(it[KIN_AT])
	k.cmd = KinFollow.CMD_IDS[ci] if ci >= 0 and ci < KinFollow.CMD_IDS.size() else "follow"
	k.down_t = float(it[KIN_AT + 1])
	k.rescue_t = float(it[KIN_AT + 2]) * float(KinDowned.rules()["rescue_s"])
	k.down_void = int(it[KIN_AT + 3]) == 1
	k.rest_t = float(it[KIN_AT + 4])

static func hunter_extra(h: Hunter) -> Array:
	var f := MergeForm.of(h)
	var shown := not f.is_empty() and (String(h.merge_st.get("phase", "")) == "live" or bool(h.merge_st.get("contact", false)))
	var sh := MergeShell.view(h)
	var pose := ""
	var k := MergeKit.of(h)
	if k != null and k.anim_id != "":
		pose = "%s~%d" % [k.anim_id, k.anim_n % 100]
	if pose == "":
		pose = KinDowned.rescue_pose(h)
	return [encode_form(f) if shown else "", snappedf(float(h.merge_st.get("t", 0.0)), 0.1), snappedf(sh.x, 0.5), snappedf(sh.y, 0.5), pose]

static func apply_hunter(h: Hunter, it: Array) -> void:
	if it.size() <= HUNTER_AT + 4:
		return
	var s := String(it[HUNTER_AT])
	var look := h.get_node_or_null(MergeLook.NODE_NAME)
	if s == "":
		if look:
			MergeLook.peel(h)
		h.set_meta("mf_kit", false)
		h.set_meta("shell", 0.0)
		h.set_meta("shell_max", 0.0)
		h.set_meta("mf_left", 0.0)
	else:
		var f := decode_form(s)
		if look == null and not f.is_empty():
			MergeLook.attach(h, f, true)
			MergeXform.on_remote_look(h, f)
		if not f.is_empty():
			h.set_meta("mf_kit", MergeForm.has_kit(f))
			h.set_meta("mf_id", String(f["id"]))
			h.set_meta("mf_glow", f["glow"])
			h.set_meta("mf_name", f["name"])
			h.set_meta("mf_dur", float(f["dur"]))
		h.set_meta("mf_left", float(it[HUNTER_AT + 1]))
		h.set_meta("shell", float(it[HUNTER_AT + 2]))
		h.set_meta("shell_max", float(it[HUNTER_AT + 3]))
	var raw := String(it[HUNTER_AT + 4])
	if raw != String(h.get_meta("kpose_raw", "")):          # (id~count: the same pose cast again is a new play)
		h.set_meta("kpose_raw", raw)
		h.set_meta("kpose", raw.get_slice("~", 0))
		h.set_meta("kpose_at", h.m.time)

## The form as a string for the snapshot and the "merge" event. A form with a kit is rebuilt from its content file on the other side.
static func encode_form(f: Dictionary) -> String:
	return "|".join([String(f["id"]), "1" if f.get("kit", false) else "0", String(f["name"]), f["type"], (f["color"] as Color).to_html(false), (f["glow"] as Color).to_html(false),
		(f.get("accent", f["glow"]) as Color).to_html(false), ",".join(f["parts"]), str(f["size"]), f["style"], f["word"], "1" if f.get("surge", false) else "0", str(f.get("ring", 3.0)), str(f.get("dur", 0.0))])

static func decode_form(s: String) -> Dictionary:
	var p := s.split("|")
	if p.size() < 14:
		return {}
	if p[1] == "1" and p[0] != "" and not Content.merge_form(p[0]).is_empty():
		return MergeForm.kit_form(p[0], float(p[13]))
	return {"id": p[0], "kit": false, "name": p[2], "type": p[3], "color": Color.html(p[4]), "glow": Color.html(p[5]), "accent": Color.html(p[6]), "parts": Array(p[7].split(",", false)),
		"size": float(p[8]), "part_k": 1.3, "style": p[9], "word": p[10], "surge": p[11] == "1", "ring": float(p[12]), "dur": float(p[13]), "aug": {}, "haste": 0.0, "def": {}}

## Tell the other games something happened to this Boki or hunter (only for bodies this game owns).
static func event(m: Match, kind: String, e: Ent, at := Vector3.INF, extra := "") -> void:
	if not m.net_on or e.remote:
		return
	var p: Vector3 = e.pos if at == Vector3.INF else at
	if kind == "merge" and e is Hunter:
		extra = encode_form(MergeForm.of(e as Hunter))
	m.net_event(["kcmd", kind, e.nid, snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01), extra])

## An event from another game: play the same moment here.
static func on_event(m: Match, x: Array) -> void:
	if x.size() < 7:
		return
	var ev = m.ents_by_id.get(String(x[2]), null)       # (untyped first: it may have been freed)
	if not is_instance_valid(ev):
		return
	var e: Ent = ev
	var at := Vector3(float(x[3]), float(x[4]), float(x[5]))
	match String(x[1]):
		"throw":
			m.fx.ring(at, 1.2, Color((e as Kin).sp["color"], 0.8) if e is Kin else Color.WHITE, 0.3)
			m.sfx("throw", at, -4.0)
		"recall", "merge_leap", "hop":
			m.sfx("recall", at, -6.0)
		"cmd":
			m.fx.ring(at, 1.2, Color((e as Kin).sp["color"], 0.8) if e is Kin else Color.WHITE, 0.3)
		"scan_start", "scan_stop", "scan_done":
			if e is Hunter:
				Capture.on_net(m, e, String(x[1]), String(x[6]))
		"unbond":
			if e is Hunter:
				KinTrack.on_net(e as Hunter, String(x[1]), String(x[6]))
		"down":
			m.fx.burst(at + Vector3(0, 0.4, 0), (e as Kin).sp["color"] if e is Kin else Color.WHITE, 16, 3.0)
		"scoop", "round":
			m.fx.ring(at, 1.2, Color.WHITE, 0.3)
			m.sfx("recall", at, -4.0)
		"merge":
			MergeXform.on_event(m, at, decode_form(String(x[6])), e as Hunter if e is Hunter else null)
		"merge_end":
			if String(x[6]) == "shell" and e is Hunter:
				(e as Hunter).set_meta("shell_break_at", m.time)
				(e as Hunter).set_meta("shell_break_col", (e as Hunter).get_meta("mf_glow", Color.WHITE))
			m.sfx("armor_break" if String(x[6]) == "shell" else "recall", at, -2.0, 0.9 if String(x[6]) == "shell" else 1.3)
		"mcast":
			if e is Hunter:
				MergeXform.on_cast(m, e as Hunter, at, String(x[6]))
