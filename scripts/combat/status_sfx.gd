class_name StatusSfx
extends RefCounted
## The cue a status makes when it lands (docs/AUDIO.md, tools/gen_sfx_cc.py): stun a ring, root a bind,
## slow (and Disoriented) a drag, Dazed a wobble, Grounded a thud. Called once from the shared apply
## paths (Ent.hurt for stun/root/slow, KitStatus.apply for the kit statuses) only when the status was
## not already running; the victim and the attacker both hear it at the body, louder for the local player.

const CUE := {
	"stun": "cc_stun", "root": "cc_root", "slow": "cc_slow", "dsr": "cc_slow", "rat": "cc_daze", "gnd": "cc_thud",
}
const OWN_DB := 0.0        # dB at the call site: the local player is the one hit
const FOE_DB := -6.0       # dB: someone else is hit, heard at their body
const GAP := 0.6           # s of match time between two cues of one kind on one body (a multi-hit stun plays once)

static func play(e: Ent, kind: String) -> void:
	var m: Node = e.m
	if m == null or not CUE.has(kind):
		return
	var now: float = float(m.time)
	var last: Dictionary = e.get_meta("cc_sfx", {})
	if now - float(last.get(kind, -1e9)) < GAP:
		return
	last[kind] = now
	e.set_meta("cc_sfx", last)
	m.sfx(CUE[kind], e.pos, OWN_DB if e == m.player else FOE_DB)
