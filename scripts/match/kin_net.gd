class_name KinNet
extends RefCounted
## What the Boki command system adds to the network (docs/decisions/0001, 0002, Net.VERSION 0.10.0). Everything
## still goes through scripts/core/net.gd; the Match calls these from its snapshot and event code.
##   - Kin snapshot: indices 19+ = [order (KinFollow.CMD_IDS index), down seconds left, rescue progress, fell in the abyss]
##   - Hunter snapshot: index 26 = the merge form worn ("" when not merged), 27 = merge seconds left
##   - Events ["kcmd", kind, nid, x, y, z, extra]: throw (a Sic too), recall (Call back), hop (a leap to your side
##     or onto you), cmd (a new order; extra = its id), merge_leap, down, scoop, round, merge (extra = the form),
##     scan_start / scan_stop / scan_done (the capture beam, Capture; nid = the hunter, extra = the Boki's nid). The owner's game runs the rescue and the recovery timer; other
##     games get the state and play the moment.

const KIN_AT := 19
const HUNTER_AT := 26

static func kin_extra(k: Kin) -> Array:
	return [maxi(0, KinFollow.CMD_IDS.find(k.cmd)), snappedf(k.down_t, 0.1), snappedf(KinDowned.scoop_k(k), 0.05), 1 if k.down_void else 0]

static func apply_kin(k: Kin, it: Array) -> void:
	if it.size() <= KIN_AT + 3:
		return
	var ci := int(it[KIN_AT])
	k.cmd = KinFollow.CMD_IDS[ci] if ci >= 0 and ci < KinFollow.CMD_IDS.size() else "follow"
	k.down_t = float(it[KIN_AT + 1])
	k.rescue_t = float(it[KIN_AT + 2]) * float(KinDowned.rules()["rescue_s"])
	k.down_void = int(it[KIN_AT + 3]) == 1

static func hunter_extra(h: Hunter) -> Array:
	var f := MergeForm.of(h)
	return [encode_form(f) if not f.is_empty() else "", snappedf(float(h.merge_st.get("t", 0.0)), 0.1)]

static func apply_hunter(h: Hunter, it: Array) -> void:
	if it.size() <= HUNTER_AT + 1:
		return
	var s := String(it[HUNTER_AT])
	var look := h.get_node_or_null(MergeLook.NODE_NAME)
	if s == "":
		if look: MergeLook.detach(h)
	elif look == null:
		MergeLook.attach(h, decode_form(s))

static func encode_form(f: Dictionary) -> String:
	return "|".join([f["type"], str(f["tier"]), f["tier_name"], (f["color"] as Color).to_html(false), (f["glow"] as Color).to_html(false), ",".join(f["parts"]), str(f["size"]), f["style"], f["word"], "1" if f.get("surge", false) else "0"])

static func decode_form(s: String) -> Dictionary:
	var p := s.split("|")
	if p.size() < 10:
		return {}
	return {"type": p[0], "tier": int(p[1]), "tier_name": p[2], "color": Color.html(p[3]), "glow": Color.html(p[4]), "parts": Array(p[5].split(",", false)), "size": float(p[6]),
		"style": p[7], "word": p[8], "surge": p[9] == "1", "rider": {}, "dash": {}, "haste": 0.0, "stun": 0.0, "k": 1.0, "dur": 0.0}

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
		"down":
			m.fx.burst(at + Vector3(0, 0.4, 0), (e as Kin).sp["color"] if e is Kin else Color.WHITE, 16, 3.0)
		"scoop", "round":
			m.fx.ring(at, 1.2, Color.WHITE, 0.3)
			m.sfx("recall", at, -4.0)
		"merge":
			var f := decode_form(String(x[6]))
			if not f.is_empty():
				MergeForm.activate(m, at, f)
				m.sfx("ult", at, -2.0)
