class_name KinSummon
extends RefCounted
## The Boki summon (DECISIONS 2026-11-09, briefs/boki-art/WISP_DESIGN_OPEN.md Q1/Q3/Q5/Q7, decision 0039).
## With Boki riding as wisps (KinWisp) the Summon key bursts the wisp into the full Boki for its species'
## window: its normal AI (KinTactics, the orders on the Boki key, its own ability) on a short leash. Damage
## never ends the window; being knocked down does: it turns straight back into a wisp with a longer cooldown.
## The burst out of the wisp and the fold back in are BokiWispPop (soft light only: no explosion, ring or disc).
## At the end it folds back into the wisp, which stays dim until the cooldown is over. Summon again while
## it is out sends it back early (full cooldown). One summon at a time: one Boki per hunter in a match.
## Numbers: content/rules/boki_summon.json (the role x size table). HUD ring: BokiHud.summon_ring.
## Online: the kin snapshot carries the seconds (KinNet); the wisp flag swaps the form.

const SHRINK_S := BokiWispPop.DURATION   # s: the fold back into the wisp
const POP := "SummonPop"  # the BokiWispPop child while it bursts or folds

var k: Kin
var dur := 10.0       # s: this species' window
var cd_base := 60.0   # s: this species' cooldown
var left := 0.0       # s of the window left (0: a wisp, or shrinking)
var shrink := 0.0     # s of the shrink back left
var _folding := false # drawing: a fold pop has started for this shrink
var cd := 0.0         # s until it can be summoned again
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
	KinCommand.say(k.owner_h, "%s was knocked back into a wisp" % k.rec.get("name", "Your Boki"), Color("ffb0a0"))
	_back(cd_base * float(rules()["knocked_cd_mult"]))
	return true

## The fixed step (own Boki only; a remote one reads the snapshot).
func tick(dt: float) -> void:
	cd = maxf(0.0, cd - dt)
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

## The burst (into the Boki) or the fold (back into the wisp), on every game (KinWisp.set_wisp). A fold already
## playing through the shrink carries on; one that never shrank (knocked down, or a late snapshot) folds from here.
func popped(to_wisp: bool) -> void:
	if not to_wisp:
		_pop(true, false)
		k.m.sfx("kin_happy", k.pos, -6.0, Unique.voice(k.rec))
	elif _folding:
		_drop_pop()
	else:
		_pop(false, true)
	_folding = false

## A BokiWispPop over the kin: its wisp home at the hunter's shoulder, the Boki's feet where the kin stands
## now. stowing: the kin is about to move to the shoulder itself (KinSummon._back), so the pop sits on it.
func _pop(burst: bool, stowing: bool) -> void:
	_drop_pop()
	var o := k.owner_h
	if o == null or k.model == null:
		return
	var pop := BokiWispPop.new(k.species, k.rec)
	pop.name = POP
	var shoulder := o.pos + Vector3(0, 1.5, 0) - k.pos
	pop.position = Vector3.ZERO if stowing else shoulder
	pop.stand = -shoulder
	pop.rotation.y = k.model.rotation.y
	pop.finished.connect(_popped)
	k.add_child(pop)
	k.model.visible = false
	pop.play(burst)

## The burst ended: the walking Boki takes over. A fold holds its last pose until the wisp flag flips.
func _popped(burst: bool) -> void:
	if burst or k.wisp:
		_drop_pop()

func _drop_pop() -> void:
	var pop := k.get_node_or_null(POP)
	if pop:
		k.remove_child(pop)
		pop.queue_free()
	if k.model:
		k.model.visible = true

func _back(cool: float) -> void:
	left = 0.0
	shrink = 0.0
	cd = cool
	cd_full = cool
	k.hp = k.max_hp
	KinWisp.set_wisp(k, true)
	k.stow()
	k.scale = Vector3.ONE

## The fold starts with the shrink (here, so other games start it from the snapshot too), and the wisp is dim
## while it rests.
func render() -> void:
	if shrink > 0.0 and not k.wisp and not _folding:
		_folding = true
		_pop(false, false)
	elif _folding and shrink <= 0.0 and not k.wisp:
		_folding = false          # left behind mid-fold: it stays the walking Boki
		_drop_pop()
	if k.wisp and k.model:
		BokiWispLook.dim(k.model, cd > 0.0)
