class_name TutorialSteal
extends RefCounted
## The tutorial's steal step, taught only when the Boki rides as a wisp (KinWisp.mode; Tutorial owns one of
## these as `st`). A held dummy Hunter stands a few steps off with its Boki on its shoulder; after SETTLE_S it
## goes down, and the real KinSteal code does the rest: its wisp breaks loose, the interact prompt shows, and
## holding the key grabs it. The step passes GOT_S after the grab (its closing line); a wisp that goes home
## ungrabbed sends the dummy up and down again. The next step takes the dummy (and the wisp) away.

const AHEAD_M := 6.0  # m from the player to the dummy
const SETTLE_S := 1.0  # s the dummy stands before it goes down (its wisp settles on its shoulder first)
const GOT_S := 2.0  # s the closing line stays after the grab

var tu: Tutorial
var foe: Hunter = null
var got := false  # the wisp is the player's
var _t := 0.0
var _got_t := 0.0


func _init(t: Tutorial) -> void:
	tu = t


## Every step starts: the last dummy and its wisp are gone, whatever the step was.
func begin() -> void:
	got = false
	_t = 0.0
	_got_t = 0.0
	if foe == null:
		return
	var m := tu.m
	for h in m.hunters:
		if not h.stomp.is_empty() and h.stomp["o"] == foe:
			Life.end_stomp(m, h, "gone")  # (a stomp on the dummy must not outlive it)
	m.hunters.erase(foe)
	m.ents_by_id.erase(foe.nid)
	if foe.kin:
		m.kins.erase(foe.kin)
		m.ents_by_id.erase(foe.kin.nid)
		m.bubbles = m.bubbles.filter(func(b): return b["ent"] != foe.kin)
		foe.kin.queue_free()
	foe.queue_free()
	foe = null


## The "steal" step starts: the dummy Hunter, its Boki a species other than yours.
func spawn() -> void:
	var m := tu.m
	var p := m.player
	var at := tu.spot(AHEAD_M, 0.0)
	if at == Vector3.INF:
		at = p.pos + Vector3(AHEAD_M, 0.0, 0.0)
	var own := String(p.kin.species) if p.kin else ""
	var species := String(Data.common_kin().filter(func(s): return s != own)[0])
	var rec := Save.new_kin(species, "", m.kin_seed("tut_steal"))
	foe = m.make_hunter(m.next_id("tut"), p.team + 1, "light", "Rival", "idle", rec, at, m.bot_kit())


## Where the marker points: the dummy's loose wisp (the dummy itself until it breaks loose).
func goal() -> Vector3:
	if foe == null:
		return Vector3.INF
	return foe.kin.pos if KinSteal.loose(foe.kin) else foe.pos


## "steal": true once the wisp has been the player's for GOT_S.
func done(dt: float) -> bool:
	if foe == null:
		return false
	var k := foe.kin
	if KinSteal.stolen(k):
		got = true
		_got_t += dt
		return _got_t >= GOT_S and tu.m.player.kin.state != "downed" and not tu.m.player.downed
	if not foe.downed:
		_t += dt
		if _t >= SETTLE_S:
			tu.m.knock(foe, null, {})
	else:
		foe.down_hp = Data.MATCH["down_hp"]  # (held: it never bleeds out or gets finished)
		if k.back_home:
			_t = 0.0
			tu.m.revive_hunter(foe, null)  # (its wisp went home ungrabbed: once more)
	return false
