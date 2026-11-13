class_name KinSummon
extends RefCounted
## The Boki summon (DECISIONS 2026-11-09, briefs/boki-art/WISP_DESIGN_OPEN.md Q1/Q3/Q5/Q7, decision 0039).
## With Boki riding as wisps (KinWisp) the Summon key bursts the wisp into the full Boki for its species'
## window: its normal AI (KinTactics, the orders on the Boki key, its own ability) on a short leash. Damage
## never ends the window; killing the Boki does (decision 0044): it turns back into a wisp where it fell. Killed
## by a rival hunter it flies home and shows its owner on their minimap for a moment, with a longer cooldown;
## killed while its owner is downed it is a loose wisp there (KinSteal); killed by a monster it just goes home.
## At the end it shrinks back into the wisp, which stays dim until the cooldown is over. Summon again while
## it is out sends it back early (full cooldown). One summon at a time: one Boki per hunter in a match.
## Numbers: content/rules/boki_summon.json (the role x size table). HUD ring: BokiHud.summon_ring.
## Online: the kin snapshot carries the seconds (KinNet); the wisp flag swaps the form.

const BURST_S := 0.3      # s: the bloom from wisp to full size
const SHRINK_S := 0.35    # s: the shrink back into the wisp
const BURST_FROM := 0.3   # its size at the start of the bloom and the end of the shrink (x its own)
const READY_FLASH_S := 1.5  # s: the Boki box says READY after the cooldown ends (once), then just shows the key

var k: Kin
var dur := 10.0       # s: this species' window
var cd_base := 60.0   # s: this species' cooldown
var left := 0.0       # s of the window left (0: a wisp, or shrinking)
var shrink := 0.0     # s of the shrink back left
var grow := 0.0       # s of the bloom left (drawing only)
var cd := 0.0         # s until it can be summoned again
var cd_full := 1.0    # s: the cooldown now running (longer after a rival's kill), for the HUD ring
var ready_flash := 0.0  # s of the READY flash left on the HUD (starts when the cooldown ends)
var fly := 0.0        # s of the flight home left after a kill (drawing only)
var fly_len := 1.0    # s: that flight in all
var fly_from := Vector3.ZERO  # where it was killed
var rival: Hunter = null      # the last rival hunter who damaged it while out
var rival_t := -1e9           # Match.time of that hit

func _init(kin: Kin) -> void:
	k = kin
	var t := times(kin.ks)
	dur = t.x
	cd_base = t.y

static func rules() -> Dictionary:
	return Content.rules("boki_summon")

## [window, cooldown] in seconds for a species, from its role and size (the table in the rules).
static func times(ks: KinSpec) -> Vector2:
	var cell: Array = rules()["fallback"]
	if ks:
		var row: Dictionary = rules()["table"].get(String(ks.ai.get("role", "")), {})
		cell = row.get(ks.size, cell)
	return Vector2(float(cell[0]), float(cell[1]))

## The one-word tag for a window: Burst (short and strong) or Steady (long and supportive).
static func tag(window: float) -> String:
	return "Steady" if window >= float(rules()["steady_from"]) else "Burst"

## Out as the full Boki (the shrink back included)?
func out() -> bool:
	return left > 0.0 or shrink > 0.0

## How far it may wander from its hunter while summoned: short and fixed, a little longer for bold ones.
func leash(aggression: float) -> float:
	return float(rules()["leash"]) + (aggression - 0.5) * 2.0 * float(rules()["leash_swing"])

## The Summon key: out of the wisp when ready, back early when out. False (and says why) when it can't.
static func press(h: Hunter) -> bool:
	var k: Kin = h.kin
	if h.downed or h.out or h.riding or h.dropping:
		return false
	if k == null or k.summon == null or k.owner_h != h:
		return KinSteal.press(h)          # (your own Boki is gone or stolen: a stolen wisp's one summon)
	var s := k.summon
	if s.left > 0.0:
		s.end()
		return true
	if not k.wisp:
		return KinSteal.press(h)
	if s.cd > 0.0:
		if KinSteal.press(h):
			return true
		KinCommand.say(h, "%s gathers itself: %d s" % [k.rec.get("name", "Your Boki"), ceili(s.cd)], Color("a2a8bb"))
		return false
	s.burst(s.dur)
	return true

## The wisp bursts into the full Boki beside its hunter, whole, for a window (s).
func burst(window: float) -> void:
	k.teleport(KinFollow.side_spot(k))
	KinWisp.set_wisp(k, false)
	k.hp = k.max_hp
	k.state = "active"
	k.cmd = "follow"
	k.fly = {}
	k.vel = Vector3.ZERO
	left = window

## The window is over (timer or sent back early): the shrink starts.
func end() -> void:
	left = 0.0
	shrink = SHRINK_S

## Remember a rival hunter's damage, for a kill that a monster finishes (see `killed`).
func note_hit(by: Ent) -> void:
	var h := _rival_of(by)
	if h and out():
		rival = h
		rival_t = k.m.time

## Killed while summoned (Kin.go_down, `by` is the killer): back into a wisp where it fell. True if it was out.
## A rival hunter's kill, or a monster's after a rival hurt it in the last rival_window_s, costs the longer
## cooldown and shows its owner (reveal_s); a monster's alone or a fall's does not (WISP_DESIGN_OPEN.md Q9).
func killed(by: Ent) -> bool:
	if not out():
		return false
	var at := k.pos
	var o := k.owner_h
	var foe := _rival_of(by)
	if foe == null and k.m.time - rival_t <= float(rules()["rival_window_s"]):
		foe = rival
	rival = null
	rival_t = -1e9
	k.m.fx.burst(at + Vector3(0, 0.4, 0), k.sp["color"], 16, 3.0)
	KinCommand.say(o, "%s was killed and went back to a wisp" % k.rec.get("name", "Your Boki"), Color("ffb0a0"))
	_back(cd_base * (float(rules()["killed_cd_mult"]) if foe else 1.0))
	if KinSteal.stolen(k):
		KinSteal.break_loose(k, at)          # a thief's stolen summon: loose again where it fell
	elif foe and (o.downed or o.out):
		KinSteal.break_loose(k, at)          # its owner is down: anyone may grab it
	else:
		k.back_home = true
		fly_len = maxf(0.1, Vector2(at.x - o.pos.x, at.z - o.pos.z).length() / float(rules()["home_speed"]))
		fly = fly_len
		fly_from = at + Vector3(0, 0.6, 0)
		if foe:
			_reveal(o, foe.team)
	return true

## The rival hunter behind a kill (the hunter, or the hunter whose Boki it was), else null.
func _rival_of(by: Ent) -> Hunter:
	var h: Hunter = by as Hunter
	if by is Kin:
		h = (by as Kin).owner_h
	if h and h.team != k.owner_h.team:
		return h
	return null

## The owner shows for reveal_s: outlined for the killer's squad (Hunter.reveal_t rides the snapshot) and pinged
## on their minimap, here and in the other games (kcmd "wkill").
func _reveal(o: Hunter, team: int) -> void:
	o.reveal_t = maxf(o.reveal_t, float(rules()["reveal_s"]))
	show_reveal(k.m, o.pos, team)
	KinNet.event(k.m, "wkill", o, Vector3.INF, str(team))

## A minimap ping at `at` for the squad `team` (only their own game draws it).
static func show_reveal(m: Match, at: Vector3, team: int) -> void:
	if m.player == null or m.player.team != team:
		return
	m.sound_pings.append({"pos": at, "t": m.time, "kind": "wisp", "life": float(rules()["reveal_s"]), "key": "wk"})
	if m.sound_pings.size() > 40:
		m.sound_pings.pop_front()

## The fixed step (own Boki only; a remote one reads the snapshot).
func tick(dt: float) -> void:
	if cd > 0.0 and cd <= dt:
		ready_flash = READY_FLASH_S
	cd = maxf(0.0, cd - dt)
	ready_flash = maxf(0.0, ready_flash - dt)
	grow = maxf(0.0, grow - dt)
	fly = maxf(0.0, fly - dt)
	var o := k.owner_h
	if left > 0.0:
		left -= dt
		if left <= 0.0:
			end()
		elif o and k.flat_dist(o) > float(rules()["rebloom_dist"]):
			k.teleport(KinFollow.side_spot(k))       # you dashed or glided off: it re-blooms beside you
			popped(false)
	elif shrink > 0.0 and k.state != "fused":
		shrink -= dt
		if shrink > 0.0:
			return
		if o == null or o.out or KinLoss.guarding(k):
			shrink = 0.0          # left behind: the walking Boki's rules from here (KinWisp.ride)
		else:
			_back(cd_base)

## The bloom (into the Boki) or the puff (back into the wisp), on every game (KinWisp.set_wisp).
func popped(to_wisp: bool) -> void:
	var glow: Color = k.sp.get("glow", k.sp["color"])
	if to_wisp:
		k.m.fx.burst(k.pos + Vector3(0, 0.6, 0), glow, 8, 2.0)
	else:
		k.m.fx.burst(k.pos + Vector3(0, 0.6, 0), glow, 18, 3.5)
		grow = BURST_S
		k.m.fx.ring(k.pos, 1.4, Color(glow, 0.8), 0.3)
		k.m.sfx("kin_happy", k.pos, -6.0, Unique.voice(k.rec))

func _back(cool: float) -> void:
	left = 0.0
	shrink = 0.0
	cd = cool
	cd_full = cool
	k.hp = k.max_hp
	KinWisp.set_wisp(k, true)
	k.stow()
	k.scale = Vector3.ONE

## Where the wisp is drawn while it streaks home after a kill: from where it fell towards `target`.
func streak(target: Vector3) -> Vector3:
	return fly_from.lerp(target, 1.0 - fly / fly_len)

## Its size through the bloom and the shrink, and the wisp dim while it rests.
func render() -> void:
	var f := 1.0
	if grow > 0.0:
		f = lerpf(1.0, BURST_FROM, grow / BURST_S)
	elif shrink > 0.0:
		f = lerpf(BURST_FROM, 1.0, shrink / SHRINK_S)
	k.scale = Vector3.ONE * f
	if k.wisp and k.model:
		BokiWispLook.dim(k.model, cd > 0.0)
