class_name KinSummon
extends RefCounted
## The Boki summon (DECISIONS 2026-11-09, briefs/boki-art/WISP_DESIGN_OPEN.md Q1/Q3/Q5/Q7, decision 0039).
## With Boki riding as wisps (KinWisp) the Summon key bursts the wisp into the full Boki for its species'
## window: its normal AI (KinTactics, the orders on the Boki key, its own ability) on a short leash. Damage
## never ends the window; being knocked down does: it turns straight back into a wisp with a longer cooldown.
## At the end it shrinks back into the wisp, which stays dim until the cooldown is over. Summon again while
## it is out sends it back early (full cooldown). One summon at a time: one Boki per hunter in a match.
## Numbers: content/rules/boki_summon.json (the role x size table). HUD ring: BokiHud.summon_ring.
## Online: the kin snapshot carries the seconds (KinNet); the wisp flag swaps the form.

const BURST_S := 0.3      # s: the bloom from wisp to full size
const SHRINK_S := 0.35    # s: the shrink back into the wisp
const CHIRP_EVERY := Vector2(14.0, 26.0)   # s: how often a riding wisp chirps (min, max): a critter by ear
const BURST_FROM := 0.3   # its size at the start of the bloom and the end of the shrink (x its own)

var k: Kin
var dur := 10.0       # s: this species' window
var cd_base := 60.0   # s: this species' cooldown
var left := 0.0       # s of the window left (0: a wisp, or shrinking)
var shrink := 0.0     # s of the shrink back left
var grow := 0.0       # s of the bloom left (drawing only)
var cd := 0.0         # s until it can be summoned again
var chirp_in := 8.0   # s until the riding wisp chirps again
var cd_full := 1.0    # s: the cooldown now running (longer after a knock-down), for the HUD ring

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

## Its chirp in the wisp's voice and as it blooms: higher for a small body (tools/gen_sfx_wisps.py).
static func chirp_name(ks: KinSpec) -> String:
	return "wisp_chirp_" + (ks.size if ks else "small")

## Out as the full Boki (the shrink back included)?
func out() -> bool:
	return left > 0.0 or shrink > 0.0

## How far it may wander from its hunter while summoned: short and fixed, a little longer for bold ones.
func leash(aggression: float) -> float:
	return float(rules()["leash"]) + (aggression - 0.5) * 2.0 * float(rules()["leash_swing"])

## The Summon key: out of the wisp when ready, back early when out. False (and says why) when it can't.
static func press(h: Hunter) -> bool:
	var k: Kin = h.kin
	if k == null or k.summon == null or h.downed or h.out or h.riding or h.dropping:
		return false
	var s := k.summon
	if s.left > 0.0:
		s.end()
		return true
	if not k.wisp:
		return false
	if s.cd > 0.0:
		KinCommand.say(h, "%s gathers itself: %d s" % [k.rec.get("name", "Your Boki"), ceili(s.cd)], Color("a2a8bb"))
		return false
	s.burst()
	return true

## The wisp bursts into the full Boki beside its hunter, whole, for its window.
func burst() -> void:
	k.teleport(KinFollow.side_spot(k))
	KinWisp.set_wisp(k, false)
	k.hp = k.max_hp
	k.state = "active"
	k.cmd = "follow"
	k.fly = {}
	k.vel = Vector3.ZERO
	left = dur

## The window is over (timer or sent back early): the shrink starts.
func end() -> void:
	left = 0.0
	shrink = SHRINK_S

## Knocked down while summoned (Kin.go_down): back into a wisp at once, the longer cooldown. True if it was out.
func knocked() -> bool:
	if not out():
		return false
	k.m.fx.burst(k.pos + Vector3(0, 0.4, 0), k.sp["color"], 16, 3.0)
	KinCommand.say(k.owner_h, "%s was knocked back into a wisp" % k.rec.get("name", "Your Boki"), Color("ffb0a0"))
	_back(cd_base * float(rules()["knocked_cd_mult"]))
	return true

## The fixed step (own Boki only; a remote one reads the snapshot).
func tick(dt: float) -> void:
	if cd > 0.0 and cd <= dt:
		k.m.sfx("wisp_ready", k.pos, -6.0)      # the cooldown is over: the wisp brightens (BokiWispLook.dim)
	cd = maxf(0.0, cd - dt)
	grow = maxf(0.0, grow - dt)
	if k.wisp and not out():
		chirp_in -= dt
		if chirp_in <= 0.0:
			chirp_in = randf_range(CHIRP_EVERY.x, CHIRP_EVERY.y)
			k.m.sfx(chirp_name(k.ks), k.pos, -10.0, Unique.voice(k.rec))
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
		k.m.sfx("wisp_shrink", k.pos, -4.0)
	else:
		k.m.fx.burst(k.pos + Vector3(0, 0.6, 0), glow, 18, 3.5)
		grow = BURST_S
		k.m.fx.ring(k.pos, 1.4, Color(glow, 0.8), 0.3)
		k.m.sfx("wisp_bloom", k.pos, -4.0)
		k.m.sfx(chirp_name(k.ks), k.pos, -4.0, Unique.voice(k.rec))

func _back(cool: float) -> void:
	left = 0.0
	shrink = 0.0
	cd = cool
	cd_full = cool
	k.hp = k.max_hp
	KinWisp.set_wisp(k, true)
	k.stow()
	k.scale = Vector3.ONE

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
