class_name CcSfx
extends RefCounted
## The cue for crowd control landing on a Hunter (docs/AUDIO.md, content/sfx/cc.json): stun, root, Ground,
## slow and Daze each have a short sound of their own. Only the Hunter it lands on hears cc_<kind>, with no
## position; a squadmate in reach hears the quieter cc_<kind>_mate from the body; a monster or Boki that gets it
## plays that same quiet cue from its body for you in reach; a rival Hunter's stays silent.
## Played from where each status is applied in its owner's game: Ent.hurt (stun, root, slow off a hit) and
## KitStatus.apply (Ground, Daze, a kit's slow). Only a status that lands fresh plays (a refresh is silent),
## one hit with several plays its strongest, and each listener hears at most one cue per CAP_S.

const KINDS := ["stun", "root", "ground", "daze", "slow"]  # strongest first: the one a stacked hit plays
const CAP_S := 0.4  # s of match time: CC stacked inside this plays once (per audience: you, your squad)
const MIN_SLOW_S := 0.4  # s: a shorter slow is a hit's nudge, not crowd control
const FOE_DB := -2.0  # dB on top of the quiet file: a slowed or stunned monster or Boki, heard where it stands
const OWN_DB := 0.0  # dB at the call: the file sits at the cast level, the clearest of the cues
const MATE_DB := -4.0  # dB on top of the mate file's quieter category, so a squadmate's never masks yours


## The strongest status this hit's opts land fresh on `e` ("" if none): call before the timers move.
static func fresh_on_hit(e: Ent, o: Dictionary) -> String:
	if float(o.get("stun", 0.0)) > 0.0 and e.stun_t <= 0.0:
		return "stun"
	if float(o.get("root", 0.0)) > 0.0 and e.root_t <= 0.0:
		return "root"
	if float(o.get("slow", 0.0)) >= MIN_SLOW_S and e.slow_t <= 0.0:
		return "slow"
	return ""


## Plays `kind` (one of KINDS) landing on `e` for whoever should hear it in this game.
static func play(e: Ent, kind: String) -> void:
	if kind == "" or e == null or e.m == null:
		return
	var me = e.m.get("player")
	if not (me is Hunter):
		return
	if not (e is Hunter):
		_play_body(e, me, kind)
		return
	var mate: bool = e != me
	var sname := "cc_%s_mate" % kind if mate else "cc_" + kind
	if mate:
		var reach := float(Sfx.sound_reach.get(sname, 0.0))
		if e.team != me.team or Vector2(e.pos.x - me.pos.x, e.pos.z - me.pos.z).length() > reach:
			return
	var key := "cc_last_mate" if mate else "cc_last_own"
	var now := float(e.m.get("time"))
	if me.has_meta(key) and now - float(me.get_meta(key)) < CAP_S:
		return
	me.set_meta(key, now)
	if mate:
		Sfx.play(sname, e.pos, MATE_DB, 0.03)
	else:
		Sfx.play(sname, null, OWN_DB, 0.03)


## A monster or Boki the status lands on: the quiet cue from where it stands, for you within its reach (a body
## you cannot place, a dead one and stacked CC inside CAP_S play nothing).
static func _play_body(e: Ent, me: Hunter, kind: String) -> void:
	var sname := "cc_%s_mate" % kind
	var reach := float(Sfx.sound_reach.get(sname, 0.0))
	if e.dead or Vector2(e.pos.x - me.pos.x, e.pos.z - me.pos.z).length() > reach:
		return
	var now := float(e.m.get("time"))
	if me.has_meta("cc_last_foe") and now - float(me.get_meta("cc_last_foe")) < CAP_S:
		return
	me.set_meta("cc_last_foe", now)
	Sfx.play(sname, e.pos, FOE_DB, 0.03)
