class_name StatusSfx
extends RefCounted
## The cue a status makes when it lands (docs/AUDIO.md, tools/gen_sfx_cc.py): stun a ring, root a bind,
## slow (and Disoriented) a drag, Dazed a wobble, Grounded a thud. Called once from the shared apply
## paths (Ent.hurt for stun/root/slow, KitStatus._show for the kit statuses), so the victim's game and
## the attacker's game both play it at the body, louder for the local player.
## A local body's caller only calls on a fresh status (its own timer was out). A remote body's timers
## live in its owner's game, so here the cue keeps its own guess of when the status ends: a refresh
## inside that guess stays silent.

const CUE := {
	"stun": "cc_stun", "root": "cc_root", "slow": "cc_slow", "dsr": "cc_slow", "rat": "cc_daze", "gnd": "cc_thud",
}
const HIT_KINDS := ["stun", "root", "slow"]     # the statuses a plain hit carries (Ent.hurt opts)
const OWN_DB := 0.0        # dB at the call site: the local player is the one hit
const FOE_DB := -6.0       # dB: someone else is hit, heard at their body
const GAP := 0.6           # s of match time between two cues of one kind on one body (a multi-hit stun plays once)

## `secs`: how long the status runs (a remote body's guess of when it ends).
static func play(e: Ent, kind: String, secs: float) -> void:
	var m: Node = e.m
	if m == null or not CUE.has(kind):
		return
	var now: float = float(m.time)
	var last: Dictionary = e.get_meta("cc_sfx", {})
	var until: Dictionary = e.get_meta("cc_sfx_until", {})
	var running: bool = e.remote and now < float(until.get(kind, -1.0))
	until[kind] = maxf(float(until.get(kind, -1.0)), now + secs)
	e.set_meta("cc_sfx_until", until)
	if running or now - float(last.get(kind, -1e9)) < GAP:
		return
	last[kind] = now
	e.set_meta("cc_sfx", last)
	m.sfx(CUE[kind], e.pos, OWN_DB if e == m.player else FOE_DB)

## The attacker's game hitting a body another game owns: the owner applies the status, this game plays it.
static func hit_remote(e: Ent, opts: Dictionary) -> void:
	for kind in HIT_KINDS:
		if float(opts.get(kind, 0.0)) > 0.0:
			play(e, kind, float(opts[kind]))
