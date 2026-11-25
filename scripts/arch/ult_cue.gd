class_name UltCue
extends RefCounted
## The sound that tells everyone in earshot an ultimate went off, before they see it. Every Hunter's X goes
## through HeroUlt.press, which calls cast(): the Hunter's own body sound (<arch>_ult_cue) at its position, with a
## team tag on top (ult_tag_ally for your team, ult_tag_foe for a rival). A rival's pair is the same sounds a little
## louder (DB_FOE) on their own bus (Sfx.play_foe, SFXFoe), so your squad's ult and an enemy's differ by ear
## before you see either. Positional with the reach of content/sfx/ult_cues.json; a rival's also gets
## HostileCue's threat layer. Other players' games
## don't run this kit, so cast() also sends it (["fx", "ucast", nid]) and net_in() plays it there.

const DB := -2.0  # dB: your team's cue and its tag
const DB_FOE := 1.0  # dB: a rival's, the same sounds 3 dB over your team's, on the SFXFoe bus


static func cast(k: ArchKit) -> void:
	SfxCast.hold_back(func(): _play(k.m, k.h))
	if k.m.net_on and not k.h.remote:
		k.m.net_fx(["ucast", k.h.nid])


static func net_in(m: Node, x: Array) -> void:
	var who: Variant = m.ents_by_id.get(String(x[2]), null)
	if who is Hunter and not (who as Hunter).is_local():
		_play(m, who as Hunter)


static func _play(m: Node, h: Hunter) -> void:
	var rival: bool = m.player != null and h.team != m.player.team
	if rival:
		Sfx.play_foe(h.arch + "_ult_cue", h.pos, DB_FOE)
		Sfx.play_foe("ult_tag_foe", h.pos, DB_FOE)
		Sfx.priority_cue("ult_tag_foe")
	else:
		m.sfx(h.arch + "_ult_cue", h.pos, DB)
		m.sfx("ult_tag_ally", h.pos, DB)
	HostileCue.play(m.player, h)
