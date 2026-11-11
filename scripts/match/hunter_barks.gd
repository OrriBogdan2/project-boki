class_name HunterBarks
extends RefCounted
## Hunter callouts (docs/AUDIO.md): short wordless barks in your Hunter's own voice (<arch>_call_<kind>,
## content/sfx/barks.json) for your ultimate coming back, your Boki going down, dropping low on health and
## landing a knock. Only you hear your own, except "Boki down": your squad hears a teammate's, at the
## teammate. Each Hunter barks at most once per COOLDOWN_S; a bark inside it is dropped, not queued. They play
## through the Sfx pool like any voice line, so its voice cap applies. Settings > Audio > Sounds turns them
## off (hunter_barks). Match.step ticks the watchers; Match and KinNet report Boki downs and knocks.

const KINDS := ["ult", "boki", "low", "knock"]
const COOLDOWN_S := 6.0     # s: least time between two barks of one Hunter (match time)
const LOW_SHARE := 0.3      # share of max health: dropping under it barks "low"
const REARM_SHARE := 0.5    # share of max health: back over it, the next drop under LOW_SHARE barks again
const VOL_DB := -4.0        # dB: the level of the hurt and downed voice lines (HeroSfx.voice)

var plays := []             # [kind, hunter nid] per bark played this match (--match-audio-check reads it)
var _last := {}             # hunter nid -> match time of its last bark
var _ult_was_ready := true  # true at the start, so a match that opens with the ultimate ready stays quiet
var _low_armed := true

## Watches your ultimate and your health once per step.
func tick(m: Match) -> void:
	var p := m.player
	if p == null or p.ak == null:
		return
	var ult_ready := HeroUlt.ready(p.ak)
	if ult_ready and not _ult_was_ready:
		_bark(m, p, "ult")
	_ult_was_ready = ult_ready
	if p.hp > p.max_hp * REARM_SHARE:
		_low_armed = true
	elif _low_armed and p.hp > 0.0 and p.hp < p.max_hp * LOW_SHARE:
		_low_armed = false
		_bark(m, p, "low")

## You knocked a rival (Match._reward_moment).
func knock_landed(m: Match) -> void:
	_bark(m, m.player, "knock")

## A Boki went down, in this game (Match.on_kin_down) or another (KinNet "down"): its owner calls it, if that is
## you or a teammate of yours.
func boki_down(m: Match, k: Kin) -> void:
	var h := k.owner_h
	if h != null and m.player != null and (h == m.player or h.team == m.player.team):
		_bark(m, h, "boki")

func _bark(m: Match, h: Hunter, kind: String) -> void:
	if h == null or h.downed or h.out or not bool(Settings.get_v("hunter_barks")):
		return
	if m.time - float(_last.get(h.nid, -COOLDOWN_S)) < COOLDOWN_S:
		return
	var sname := HeroSfx.of(h, "call_" + kind, "")
	if sname == "":
		return
	_last[h.nid] = m.time
	plays.append([kind, h.nid])
	m.sfx(sname, h.pos, VOL_DB)
