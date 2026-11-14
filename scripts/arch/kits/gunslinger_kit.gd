class_name GunslingerKit
extends ArchKit
## Vex (archetype id "gunslinger", medium): the green-fire rifle skirmisher. docs/heroes/gunslinger.md
## has the per-slot table, the assumptions and the research notes (briefs/hero-ref/venator.md, owner notes).
##
## Loop: tap RMB and she flicks the Coin Blast, her relic coin, from her cyborg left hand along the aim. A direct
## hit on a foe damages and Dazes it ("rat" Rattled in code) on the spot. Otherwise it flies its 10.5 m, riding up
## ramps and low ledges, and sticks where it meets a steep wall: a cone shows back toward you for its fuse,
## then blasts, shoving everyone in it along the cone (toward you), hurting and Dazing them too. At the
## lane's end on no foe and no wall, on the ground or in the air, it is a dud: a puff and nothing else (a
## miss is a miss; the source's cone is wall-only). The rifle does +76% to a Dazed foe, in big gold numbers,
## and the string doesn't decay on them. Slipstep goes where you move and you keep shooting. Palm Lance: stand
## still, the left palm raised, while the line narrows, the aim turning only so fast, then a long beam out of the
## palm through walls. A knock gives Slipstep back (Hot Streak); abilities that land add a little lifesteal (Fever).

<<<<<<< HEAD
const LIME := Color("b8f03c")
const HOT := Color("eaffa8")
const DAZE_PINK := Color("ff4fb0")   # the Daze's own colour (stars, swirl): its bonus is not a plain crit
const DEEP := Color("4f8a12")
const BRONZE := Color("b9732f")
const GOLD := Color("ffcf3f")        # the Coin Blast's coin (unshaded: the toon light turns gold red-brown)
const GOLD_DARK := Color("d99a1e")   # its struck faces
const SMOKE := Color("d9c2a8")       # the Palm Lance's recoil smoke ring: warm, not white
const SCRAPE := Color("6b4a2e")      # the slide's dust scrape under her
const DAZE_FLASH := 1.8              # m, the pink spark on a Dazed foe per rifle round
||||||| ba6b62f7a1
const EMBER := Color("ff9a5c")
const HOT := Color("fff1c8")
const DAZE_PINK := Color("ff4fb0")   # the Daze's own colour (stars, swirl): its bonus is not a plain crit
const DEEP := Color("c43a2a")
const BRONZE := Color("b9732f")
const SMOKE := Color("d9c2a8")       # the Longneedle's recoil smoke ring: warm, not white
const SCRAPE := Color("6b4a2e")      # the slide's dust scrape under her
const ROUND_EDGE := Color("4f8a12")  # LMB slot: the deep green rim on her lime rounds, so they hold on bright ground
const ROUND_HOT := Color("eaffa8")   # LMB slot: a pale tint of her lime, the hot core of the rounds and muzzle star
const ROUND_LEN := 2.6               # m of tracer per rifle round: about 1.5 bh with its fading tail (footage)
const ROUND_WIDTH := 0.34            # m across a round's head: her 0.3 m hit width (HITBOX_SIZE) plus the rim
const FLASH_ACROSS := 0.8            # m, the muzzle star on each round
const FLASH_SECONDS := 0.08          # s, the muzzle star's life: gone before the next round (0.12 s apart)
const GUN_MUZZLE := ^"Rig/Torso/Aim/Gun/Muzzle"  # on her model this sits on the rifle's mouth
const DAZE_FLASH := 1.8              # m, the pink spark on a Dazed foe per rifle round
=======
# Her green fire: the slots of content/vfx/gunslinger.json's palette that the telegraphs and the charge's mesh
# use; every effect is a recipe in that file (HeroVfx, docs/HERO_VFX.md).
const LIME := Color("b8f03c")        # palette "main", her signature (Arch.color)
const HOT := Color("eaffa8")         # palette "hot"
const DEEP := Color("4f8a12")        # palette "deep"
const BRONZE := Color("b9732f")      # the Burr Charge's metal shell (a material, not an effect)
const DUD_DUST := Color("6b4a2e")    # a dud Burr Charge's dull dust puff where its lane ended
const DAZE_PINK := Color("ff4fb0")   # palette "daze": the Daze's own colour, so its bonus is not a plain crit
const GUN_MUZZLE := ^"Rig/Torso/Aim/Gun/Muzzle"  # on her model this sits on the rifle's mouth
>>>>>>> origin/main
const DAZE_NUM_LIFT := 2.1           # m over a foe's feet: the "+N" floats above its hit number
const BURR_HIT_HEIGHT := 2.6         # m above a foe's feet the coin can still strike
const BURR_SAMPLE := 0.25            # m between the ground reads along the coin's flight (a tile is 1 m)
const BURR_RIDE := 0.25              # m: the least height the coin keeps over the ground, so it rides up slopes
const BURR_WALL_DEG := 50.0          # deg: a rise steeper than this (stairs are 39) and over World.STEP is a wall
const PUSH_EASE := 10.0              # 1/s; the view push-out follows the aim distance, settling in ~0.3 s, no jumps
const HIT_HOLD := 0.3                # s a struck foe's body stays lit (the generic hit flash is 0.12 s)
const PIP_LIFT := 0.9                # m up the screen the Fever pips sit, clear of her cap and face
const PALM_BONE := "hand.L"          # her cyborg left hand
const PALM_OFF := Vector3(-0.04, 0.075, 0.0)   # m in its bone space: the open palm's centre, 7.5 cm along the hand
const COIN_FLIP := 22.0              # rad/s: the coin turns end over end in flight
const BRACKET_R := 1.25              # m: the firing brackets either side of her (footage: about 0.7 bh)
const BRACKET_DEG := 56.0            # each bracket's arc
## The drum's reload cue, once as it runs dry. A stand-in for now: the rifle-cock take from her set; a library
## reload sound (sfx-lib-1113) swaps in here.
const RELOAD_SFX := "vn_cock"
const E_RECOVER := 0.6               # s she is held after the beam: the source's recoil shove in 0.2 s, then a ~0.4 s
                                     # recovery (briefs/hero-ref/venator.md E 4 and 7: 0170, 556.6-556.8 s); the e clip
                                     # (1.07 s) + WardenClips.FADE_LOCO hands the body back on the same frame

var slide := {}                # {t, held, dir} while a Slipstep runs
## Coin Blasts (id "burr") in flight or stuck: {pos, dir, t, node, fuse, fuse0, range, out, y0, spin}
var burrs: Array = []
var burr_pool: Array = []      # their nodes, reused
## The Palm Lance's charge: {t, dir (the turn-capped aim), push (0..1 of the view push-out)}
var needle := {}
var knocked := {}
var direct_hits := 0           # Coin Blasts that struck a foe (tests)
var rattles := 0               # Coin Blasts that blew (tests)
var duds := 0                  # Coin Blasts that reached the lane's end on nothing (tests)
var daze_for := {}             # foe id -> s of the Daze she last put on them (RecastCue's ring)
var dazed_hits := 0            # rifle rounds on a Dazed foe (tests)
var skewers := 0               # Palm Lance payoffs
var needle_hits := 0
var needle_dir := Vector2.ZERO # tests: the line the last Palm Lance fired along
var wall_slams := 0
var last_dash_kind := ""
var last_shot := 0
<<<<<<< HEAD
var flicks := 0                # tests: coins flicked from the hand
var last_flick := Vector3.ZERO # tests: where the last one left
var echo_t := 0.0
||||||| ba6b62f7a1
var puffs := 0                 # tests: launcher puffs
var last_puff := Vector3.ZERO  # tests: where the last one went off
var echo_t := 0.0
=======
var puffs := 0                 # tests: launcher puffs
var last_puff := Vector3.ZERO  # tests: where the last one went off
>>>>>>> origin/main
var refill_part := 0.0         # rounds the resting drum has part-refilled
var dry := false               # the drum ran dry: no round until it is full again
var round_at := -9.0           # match time of her last rifle round (the firing brackets)
var ult: GunslingerUlt         # Cinderfall, her ultimate on X
var commit_end := 0.0          # match time her committed recovery ends (E after the beam, X from the tap)

func _setup() -> void:
	ult = GunslingerUlt.new(self)

## The world direction that reads as up the screen, so a word rides above a head.
func screen_up() -> Vector3:
	var cam := m.get_viewport().get_camera_3d()
	return cam.global_basis.y if cam != null else Vector3.UP

func cast_ult() -> bool:
	return HeroUlt.press(self, ult.cast)

func has_ult() -> bool:
	return true

func full_ready() -> bool:
	return false

func res_text() -> String:
	return "%d" % int(res)

func fever_k() -> float:
	return float(res_def()["vamp"]) * floorf(res)

func ready_label() -> String:
	return ""

# ------------------------------------------------------------------ per step
func _tick(dt: float) -> void:
	if res_wait <= 0.0 and res > 0.0:
		res = 0.0
	if not slide.is_empty():
		_tick_slide(dt)
	if not burrs.is_empty():
		_tick_burrs(dt)
	if not needle.is_empty():
		_tick_needle(dt)
	if ult.running():
		ult.tick(dt)
	_tick_lmb()
	_tick_mag(dt)
	_tick_brackets()
	_tick_walk_off()
	self_pips(int(res_def()["max"]), int(floor(res + 0.01)), false, dt, PIP_LIFT, 0.65)

func own_dash_trail() -> bool:
	return true

func dodge_anim() -> String:
	return "slide" if not slide.is_empty() else ""      # Slipstep: the kit move is the whole pose (no roll)

## Her rifle goes from an open glider, which stays open (docs/heroes/gunslinger.md Cancels: every interaction chains).
func fires_in_glide() -> bool:
	return true

func shows_charge_ball() -> bool:
	return false                   # the Palm Lance charges green fire in her palm instead

const SLIDE_LOOP_FROM := 0.367       # s: the dash clip's slide loop (three keys): a held slide replays it from here,
const SLIDE_LOOP_T := 0.133          # s: one period at a time, so she stands up as the skid ends
const OVER := 2.0                    # s: older than any of her clips (the longest runs 1.07 s): a move aged this far
                                     # is over to the clips (the kit's anim_id is read as long as it is set)

## Walking out of the slide's stand-up once the skid has ended: the legs are hers again and the walk blends in
## (WardenClips.FADE_LOCO) in place of the clip's stand-still pose, the source's Ghost walking off.
## (Clearing anim_id would not do: the published anim state keeps the last kmove until another move plays.)
func _tick_walk_off() -> void:
	if anim_id != "gunslinger_dash" or not slide.is_empty() or not h.grounded:
		return
	if (h.inp.get("move", Vector2.ZERO) as Vector2).length() > 0.5:
		anim_at = float(m.time) - OVER        # the move reads as over: past its clip, the body goes back to the legs

<<<<<<< HEAD
func _tick_trail() -> void:
	var tr: Array = TRAILS.get(anim_id, [])
	var t := float(m.time) - anim_at
	if tr.is_empty() or h.anim == null or t < float(tr[1]) or t > float(tr[2]):
		return
	var hand: Node3D = h.anim.hand_l if String(tr[0]) == "l" else h.anim.hand_r
	if hand != null:
		fx().trail("vn%d" % h.get_instance_id(), hand.global_position, LIME, HOT, 0.24)

## Her after-image colour: a deeper ember, so the trail reads apart from her warm live body.
static func echo_col() -> Color:
	return LIME.lerp(DEEP, 0.5)

## Her own after-images on Slipstep and the air dash: her silhouette in ember, cooling to deep red.
func _tick_echo(dt: float) -> void:
	if h.roll_t <= 0.0 and slide.is_empty():
		echo_t = 0.0
		return
	echo_t -= dt
	if echo_t > 0.0:
		return
	echo_t = ECHO_GAP
	fx().echo(h, echo_col(), 0.4, ECHO_ALPHA, ECHO_BACK)

||||||| ba6b62f7a1
func _tick_trail() -> void:
	var tr: Array = TRAILS.get(anim_id, [])
	var t := float(m.time) - anim_at
	if tr.is_empty() or h.anim == null or t < float(tr[1]) or t > float(tr[2]):
		return
	var hand: Node3D = h.anim.hand_l if String(tr[0]) == "l" else h.anim.hand_r
	if hand != null:
		fx().trail("vn%d" % h.get_instance_id(), hand.global_position, EMBER, HOT, 0.24)

## Her after-image colour: a deeper ember, so the trail reads apart from her warm live body.
static func echo_col() -> Color:
	return EMBER.lerp(DEEP, 0.5)

## Her own after-images on Slipstep and the air dash: her silhouette in ember, cooling to deep red.
func _tick_echo(dt: float) -> void:
	if h.roll_t <= 0.0 and slide.is_empty():
		echo_t = 0.0
		return
	echo_t -= dt
	if echo_t > 0.0:
		return
	echo_t = ECHO_GAP
	fx().echo(h, echo_col(), 0.4, ECHO_ALPHA, ECHO_BACK)

=======
>>>>>>> origin/main
func teardown() -> void:
	super.teardown()
	for b in burrs:
		if b["node"] != null and is_instance_valid(b["node"]): (b["node"] as Node3D).visible = false
	burrs.clear()
	ult.clear()
	_end_needle()

func move_k() -> float:
	if commit_left() > 0.0:
		return 0.0
	return 1.0 - float(e_def()["self_slow"]) if not needle.is_empty() else 1.0

## The rifle can't fire while a dry drum refills (_tick_mag), nor in a committed recovery.
func fire_ok() -> bool:
	return not dry and commit_left() <= 0.0

## The source's recoveries (E_RECOVER, GunslingerUlt.COMMIT): she stands, and no ability, jump or Shift goes.
## A press in the last Loco.press_buffer waits for the end (DashFlow.cc_left); one before it is dropped.
func commit_left() -> float:
	return maxf(0.0, commit_end - float(m.time))

func busy() -> bool:
	return super.busy() or commit_left() > 0.0

func gate_inputs() -> void:
	if commit_left() > Loco.press_buffer:
		h.inp["dash"] = false
		h.inp["jump"] = false

func add_fever(n := 1) -> void:
	res = minf(res_max(), res + float(n))
	touch_res(float(res_def()["wait"]))

func combo_read(t: Ent) -> Dictionary:
	if not KitStatus.rattled(t):
		return {}
	var bd := rmb_def()["burr"] as Dictionary
	return {"icon": "concussion", "n": 0, "max": 0, "left": KitStatus.rattled_left(t),
			"total": float(bd["cone_rattle"]) + float(bd["wall_daze"])}

## Dazed foes take +76% from the rifle (the source's +39 on 51): a crit-style big gold number.
func outgoing(t: Ent, dmg: float, o: Dictionary) -> float:
	if t is Hunter or t is Mob:
		if String(o.get("src", "")) == "shot" and not o.has("ab") and KitStatus.rattled(t):
			o["crit"] = true
			dazed_hits += 1
			ComboMark.payoff(m, h, t)
			var bonus := dmg * float(res_def()["rattle_k"])
			_daze_bonus_fx(t, bonus)
			return dmg + bonus
	return dmg

## The Daze's share of a rifle round, shown on its own: a pink "+N" above the gold hit number (rounds in a
## burst add up on it) and a pink flare on the body. Only the shooter's screen gets the number.
func _daze_bonus_fx(t: Ent, bonus: float) -> void:
	vfx("daze_hit", t.pos, h.dir_to(t))
	if h.is_local() and Settings.get_v("damage_numbers"):
		m.fx.number(t.pos + Vector3(0, DAZE_NUM_LIFT, 0), bonus, DAZE_PINK, true, "+")

func on_deal(t: Ent, dmg: float, o: Dictionary) -> void:
	if t == null or t.team == h.team or String(o.get("src", "")) == "burn":
		return
<<<<<<< HEAD
	if String(o.get("src", "")) == "shot" and not o.has("ab"):
		vfx("shot_hit", t.pos + Vector3(0, 1.0, 0), h.dir_to(t), {"k": _faded_now()})
||||||| ba6b62f7a1
=======
	if String(o.get("src", "")) == "shot" and not o.has("ab"):
		vfx("shot_hit", t.pos + Vector3(0, 1.0, 0), h.dir_to(t))
>>>>>>> origin/main
	if res > 0.0:
		h.heal(dmg * fever_k())
	if o.has("ab") and String(o.get("ab")) != "dodge":
		add_fever(1)
	if t is Hunter and ((t as Hunter).downed or t.hp <= 0.0) and not knocked.has(t.get_instance_id()):
		_on_knock(t)

## Hot Streak: rank 3 resets the Coin Blast on a knock (Slipstep comes back by the game-wide DashReset rule).
func _on_knock(t: Ent) -> void:
	knocked[t.get_instance_id()] = true
	CombatBus.tech.emit(h, "gunslinger")
	if rank("sec") >= 3:
		ch_rmb = float(rmb_charges())
		cd["rmb"] = 0.0
	vfx("knock")                   # the rifle hand's swoosh and a lift of green fire
	play("gunslinger_knock")

# ------------------------------------------------------------------ LMB: the rifle's rounds
<<<<<<< HEAD
## Each round: a lime tracer with a white-hot core, a muzzle flash the size of the gatling's mouth, the shoulder kick.
||||||| ba6b62f7a1
## Each round in her green fire: a tracer with a hot core line in a lime body rimmed deep green, a short star on
## the rifle's mouth, the shoulder kick.
=======
## Each round: a muzzle flash, a thin lime tracer riding the round (its hit is on_deal's), the shoulder kick.
>>>>>>> origin/main
func _tick_lmb() -> void:
	if h.shot_n == last_shot:
		return
	last_shot = h.shot_n
	round_at = m.time
	var shots: Array = m.get("shots")
	for i in range(shots.size() - 1, -1, -1):
		var sd: Dictionary = shots[i]
		if sd["by"] == h and not (sd["x"] as Dictionary).has("src"):
<<<<<<< HEAD
			var faded := {"k": _faded(float((sd["x"] as Dictionary).get("sus_k", 1.0)))}
			vfx("shot", sd["start"], sd["vel"] as Vector2, faded)
			HeroVfx.of(m).trail(h, "shot_trail", sd["node"], faded)
||||||| ba6b62f7a1
			fx().ride(sd, "tracer", hero_col, ROUND_HOT, ROUND_LEN, ROUND_WIDTH, _round_end, ROUND_EDGE)
			var mouth := _gun_muzzle()
			fx().star(mouth.global_position if mouth else sd["start"], hero_col, ROUND_HOT, FLASH_ACROSS, FLASH_SECONDS)
=======
			vfx("shot", sd["start"], sd["vel"] as Vector2)
			HeroVfx.of(m).trail(h, "shot_trail", sd["node"])
>>>>>>> origin/main
			break
	if anim_id == "" or anim_id == "gunslinger_lmb" or m.time - anim_at > 1.2:
		play("gunslinger_lmb")

## While the rifle fires, two thin arcs bracket her left and right (your screen only; the footage's firing
## brackets), gone a beat after the trigger rests.
func _tick_brackets() -> void:
	if not _rifle_in_hand() or m.time - round_at > float(h.wpn["rate"]) + 0.1 or busy():
		return
	var d := h.aim_dir()
	for side in [-1.0, 1.0]:
		AimKit.arc_wall(h, "lmb_bracket%d" % int(side), {"dir": Vector2(-d.y, d.x) * side, "radius": BRACKET_R,
				"deg": BRACKET_DEG, "thick": 0.05, "panels": 1})

func _rifle_in_hand() -> bool:
	return h.wid == String(d.get("signature", ""))

## The drum (the source's rifle: 30 rounds that "rapidly reload when not firing"; there is no reload key): once no
## round has left for `refill_after` it refills at `refill_rate`, so a string after a pause starts full. Run dry,
## the trigger is dead until the drum is full again (held or not), then the string picks up and the drum clicks home
## (the reload look).
func _tick_mag(dt: float) -> void:
	if not _rifle_in_hand():
		dry = false
		return
	var mag := int(h.wpn["mag"])
	if h.ammo <= 0 and not dry:
		dry = true
		m.sfx(RELOAD_SFX, h.pos, -4.0)
	if h.ammo >= mag or h.idle_fire < float(h.wpn["refill_after"]):
		refill_part = 0.0
		if h.ammo >= mag and dry:
			dry = false
			vfx("reload")
		return
	refill_part += float(h.wpn["refill_rate"]) * dt
	var add := int(refill_part)
	refill_part -= float(add)
	h.ammo = mini(mag, h.ammo + add)

<<<<<<< HEAD
## How far a round's damage has decayed toward the rifle's sustained floor: 0 at full damage, 1 once the string
## is past its first ten rounds. The shot, trail and hit looks in content/vfx/gunslinger.json shrink by it
## ("size_k"), so a long string visibly thins and a pause makes it full again.
func _faded(sus_k: float) -> float:
	var loss := float(h.wpn.get("sustain_loss", 0.0))
	return clampf((1.0 - sus_k) / loss, 0.0, 1.0) if loss > 0.0 else 0.0

## The decay of the round landing now: the hit does not carry its round's sus_k, so this reads the string's
## count (a round or two ahead at most).
func _faded_now() -> float:
	var rounds := float(h.wpn.get("sustain_rounds", 10))
	return minf(1.0, float(h.sus_n) / rounds) if rounds > 0.0 else 0.0

||||||| ba6b62f7a1
func _round_end(at: Vector3, vel: Vector2) -> void:
	var d := Vector3(-vel.x, 0.4, -vel.y).normalized() if vel.length() > 0.1 else Vector3.UP
	m.fx.spark(at, d, hero_col, 3, 5.0, 50.0, 0.14, 8.0, 0.7)

=======
>>>>>>> origin/main
# ------------------------------------------------------------------ dash: Slipstep
func on_dash(use_ex: bool) -> bool:
	var dd := dash_def()
	if use_ex and h.dashes >= 1.0 and not h.grounded:
		# an air tap: a slide of 2/3 the full hold's distance (source patch notes), spending a charge
		h.dashes -= 1.0
		var ad := float(dd["slide"]) * float(dd.get("air_k", 0.667))
		var air_t := float(dd["slide_t"]) * 0.6
		travel(ad, air_t, {"invuln": float(dd["invuln"])})
		slide = {"t": 0.0, "held": false, "dir": h.roll_dir, "air": true, "len_t": air_t}
		play("gunslinger_dash")
		vfx("slide_air")
		last_dash_kind = "air_slide"
		return true
	if use_ex:
		if not spend_dash(true):
			return true
		travel(float(h.cdat.get("ex_dist", 4.6)) * 0.9, float(h.cdat.get("ex_time", 0.2)), {"invuln": 0.08})
		play("gunslinger_dash_ex")
		vfx("slide_air", null, null, {"ex": true})
		last_dash_kind = "air"
		return true
	if not spend_dash(false):
		return true
	travel(float(dd["roll"]), float(dd["roll_t"]), {"invuln": float(dd["invuln"]), "curved": true})
	slide = {"t": 0.0, "held": false, "dir": h.roll_dir, "from": h.pos}
	play("gunslinger_dash")
	# green-fire streaks off her chest and heels and a kick of dust. No rings or discs: those mean damage or an
	# area in this game
	vfx("slide")
	return true

func _slide_end() -> void:
	h.roll_t = 0.0
	if rank("dash") >= 3:
		h.add_buff("move_speed", float(dash_def()["rank3_speed"]), float(dash_def()["rank3_speed_t"]))
	var air := bool(slide.get("air", false))
	if air and not h.gliding:
		h.vel.x *= 0.25          # an air slide stops short instead of carrying on (a glide press carries it, item 4)
		h.vel.z *= 0.25
	var kind := "slide" if bool(slide.get("held", false)) else "step"
	st["last_dash"] = "air_slide" if air else kind
	last_dash_kind = String(st["last_dash"])
	slide = {}

## A tap: a skid on her fitted dash curve (content/rules/dash_feel.json, ArchKit.travel's "curved"), covering
## `roll` m over roll_t (you shoot through it).
func _skid(t: float, dd: Dictionary) -> void:
	if t >= float(dd["roll_t"]) * float(dash_feel()["time"]):
		_slide_end()

func _tick_slide(dt: float) -> void:
	if h.gliding:
		_slide_end()      # a glide press cancelled it (Hunter._dash_into_glide): the glide has its speed now
		return
	var dd := dash_def()
	slide["t"] = float(slide["t"]) + dt
	var t := float(slide["t"])
	HeroVfx.of(m).hold(h, "slide_dust")          # a dust trickle off her heels while she slides
	if not bool(slide["held"]):
		if bool(slide.get("air", false)):
			if t >= float(slide["len_t"]):
				_slide_end()
			return
		var can_hold := not h.downed and h.stun_t <= 0.0 and h.root_t <= 0.0 and h.grounded
		if t >= float(dd["tap_t"]) and not bool(slide.get("tap", false)):
			if held("dash") and can_hold:
				slide["held"] = true
				curved = {}                              # the hold slide sets its own speed
				slide["t0"] = t
				# `slide` m is the whole hold from where she pressed: the slide covers what the skid hasn't
				var from: Vector3 = slide["from"]
				var skidded := Vector2(h.pos.x - from.x, h.pos.z - from.z).length()
				slide["left"] = maxf(float(dd["slide"]) - skidded, 0.0)
				h.dashes -= float(dd["hold_cost"])       # the longer slide takes longer to come back
				h.roll_dir = slide["dir"]
				h.move_kind = "dash"
				vfx("slide_hold")
				return
			slide["tap"] = true
		_skid(t, dd)
		return
	var st_t := t - float(slide["t0"])
	var dur := float(dd["slide_t"])
	if not held("dash") or st_t >= dur or h.stun_t > 0.0 or h.root_t > 0.0:
		_slide_end()
		return
	var k := 1.0 - st_t / dur
	h.roll_t = maxf(h.roll_t, dt * 1.5)
	if anim_id == "gunslinger_dash":
		var into := float(m.time) - anim_at           # the clip's clock: past the loop's end it goes round again
		if into > SLIDE_LOOP_FROM + SLIDE_LOOP_T:
			anim_at = float(m.time) - SLIDE_LOOP_FROM - fposmod(into - SLIDE_LOOP_FROM, SLIDE_LOOP_T)
	h.roll_speed = float(slide["left"]) / dur * (0.5 + k)
	h.inv_t = 0.0

# ------------------------------------------------------------------ RMB: Coin Blast
func fire_rmb(c: Dictionary) -> void:
	last_variant = String(c["variant"])
	if not spend_rmb():
		return
	var bd := rmb_def()["burr"] as Dictionary
	var d := h.aim_dir()
	var n: Node3D = null
	for p in burr_pool:
		if is_instance_valid(p) and not (p as Node3D).visible:
			n = p
			break
	if n == null:
		n = _coin_mesh()
		burr_pool.append(n)
	n.visible = true
	n.scale = Vector3.ONE
	var at := palm_at()
	n.global_position = at
	var burr := {"pos": at, "dir": d, "t": 0.0, "node": n, "fuse": -1.0, "fuse0": float(bd["fuse"]), "spin": 0.0}
	burr["range"] = float(bd["range"])
	burr["y0"] = at.y
	burrs.append(burr)
	HeroVfx.of(m).trail(h, "rmb_trail", n)       # its green-fire streak, until it sticks or strikes
	play("gunslinger_rmb")
	flicks += 1
	last_flick = at
	fx().star(at, LIME, HOT, 0.35, 0.08)          # green fire off her fingers as the coin leaves
	m.sfx("vn_throw", h.pos, -3.0)

## Her cyborg left palm where the clip has it now, else the left hand of a model with no skeleton.
func palm_at() -> Vector3:
	var sk := WardenGlb.skeleton(h.model.get_node_or_null("Warden")) if h.model else null
	var at := palm_in(sk) if sk else Vector3.INF
	return at if at != Vector3.INF else h.ak.hand_pos(false)

## The palm point on a skeleton, read off the bone's live pose (a .glb empty on the bone lags the clip); INF
## where the skeleton has no hand.L. --hero-vfx-check holds it near the bone through every clip.
static func palm_in(sk: Skeleton3D) -> Vector3:
	var bi := WardenSkeleton.find(sk, PALM_BONE)
	return sk.global_transform * (sk.get_bone_global_pose(bi) * PALM_OFF) if bi >= 0 else Vector3.INF

<<<<<<< HEAD
## The coin: a chunky gold disc 0.44 m across, a darker struck face each side and a green-fire rim
## ("Glow"). Solid colours, so it reads gold and lime on any ground.
func _coin_mesh() -> Node3D:
||||||| ba6b62f7a1
## The launcher's puff: at the bell once it has swung forward, or at once where there is no swinging bell.
func _launcher_puff(at: Vector3, d: Vector2) -> void:
	var bell := WardenGlb.anchor(h.model, TUBE_BELL)
	if bell == null:
		_puff(at, d)
		return
	m.later(TUBE_SWING, func():
		if is_instance_valid(bell) and is_instance_valid(h):
			_puff(bell.global_position, h.aim_dir()))

func _puff(at: Vector3, d: Vector2) -> void:
	puffs += 1
	last_puff = at
	m.fx.muzzle(at, d, EMBER, 2.0)

## The charge: a bronze ball about 0.3 m across, a dark band round it, an ember heart showing through
## and eight hot spikes. Solid colours, so it reads bronze and ember on any ground.
func _burr_mesh() -> Node3D:
=======
## The launcher's puff: at the bell once it has swung forward, or at once where there is no swinging bell.
func _launcher_puff(at: Vector3, d: Vector2) -> void:
	var bell := WardenGlb.anchor(h.model, TUBE_BELL)
	if bell == null:
		_puff(at, d)
		return
	m.later(TUBE_SWING, func():
		if is_instance_valid(bell) and is_instance_valid(h):
			_puff(bell.global_position, h.aim_dir()))

func _puff(at: Vector3, d: Vector2) -> void:
	puffs += 1
	last_puff = at
	vfx("rmb_puff", at, d)

## The charge: a bronze ball about 0.3 m across, a dark band round it, a lime heart showing through
## and eight hot spikes. Solid colours, so it reads bronze and green fire on any ground.
func _burr_mesh() -> Node3D:
>>>>>>> origin/main
	var n := own_node()
<<<<<<< HEAD
	var spin := Node3D.new()
	spin.name = "Spin"
	n.add_child(spin)
	var body := Models.part(spin, Models.cyl(0.22, 0.22, 0.07, 20), solid_mat(GOLD))
	body.rotation.x = PI * 0.5                      # face on along the travel, so the flip shows its faces
	for side in [-1.0, 1.0]:
		var disc := Models.cyl(0.15, 0.15, 0.012, 16)
		var face := Models.part(spin, disc, solid_mat(GOLD_DARK), Vector3(0, 0, side * 0.035))
		face.rotation.x = PI * 0.5
	var rim := Models.part(spin, Models.cyl(0.245, 0.245, 0.04, 20), solid_mat(LIME))
	rim.rotation.x = PI * 0.5
	rim.name = "Glow"
	for ch in n.find_children("*", "GeometryInstance3D", true, false):
||||||| ba6b62f7a1
	Models.part(n, Models.sphere(0.15, 12), Models.shiny(BRONZE, 0.6))
	var band := Models.cyl(0.155, 0.155, 0.06, 14)
	Models.part(n, band, Models.toon(Color("2b2a33"), false, 0.0))
	var heart := Models.part(n, Models.sphere(0.07, 8), solid_mat(EMBER), Vector3(0, 0.1, 0.1))
	heart.name = "Glow"
	for i in 8:
		var a := TAU * i / 8.0
		var out := Vector3(cos(a), sin(i * 2.1) * 0.5, sin(a)).normalized()
		var spike := Models.part(n, Models.crystal(0.04, 0.17, 4), solid_mat(HOT), out * 0.17)
		var up := Vector3.UP if absf(out.y) < 0.95 else Vector3.RIGHT
		spike.look_at_from_position(spike.position, spike.position * 2.0, up)
	for ch in n.get_children():
=======
	Models.part(n, Models.sphere(0.15, 12), Models.shiny(BRONZE, 0.6))
	var band := Models.cyl(0.155, 0.155, 0.06, 14)
	Models.part(n, band, Models.toon(Color("2b2a33"), false, 0.0))
	var heart := Models.part(n, Models.sphere(0.07, 8), solid_mat(LIME), Vector3(0, 0.1, 0.1))
	heart.name = "Glow"
	for i in 8:
		var a := TAU * i / 8.0
		var out := Vector3(cos(a), sin(i * 2.1) * 0.5, sin(a)).normalized()
		var spike := Models.part(n, Models.crystal(0.04, 0.17, 4), solid_mat(HOT), out * 0.17)
		var up := Vector3.UP if absf(out.y) < 0.95 else Vector3.RIGHT
		spike.look_at_from_position(spike.position, spike.position * 2.0, up)
	for ch in n.get_children():
>>>>>>> origin/main
		(ch as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n

func _tick_burrs(dt: float) -> void:
	var bd := rmb_def()["burr"] as Dictionary
	for b in burrs.duplicate():
		var n: Node3D = b["node"]
		if float(b["fuse"]) >= 0.0:
			# stuck: pulses faster, the cone shows back toward the thrower for everyone
			b["fuse"] = float(b["fuse"]) - dt
			var k := 1.0 - float(b["fuse"]) / float(b["fuse0"])
			if is_instance_valid(n):
				n.global_position = b["pos"]
				n.scale = Vector3.ONE * (1.0 + 0.35 * sin(m.time * lerpf(10.0, 44.0, k)))
			var cone := {"from": b["pos"], "dir": b["out"], "len": float(bd["cone_len"]), "deg": float(bd["cone_deg"])}
			cone.merge({"fill": k, "all": true, "col": LIME, "col2": HOT, "hot": k})
			AimKit.cone(h, "burr%d" % n.get_instance_id(), cone)
			if float(b["fuse"]) <= 0.0:
				burrs.erase(b)
				_detonate(b)
			continue
		_fly_burr(b, bd, dt)
		b["spin"] = float(b["spin"]) + dt * COIN_FLIP
		if is_instance_valid(n):
			var dir: Vector2 = b["dir"]
			n.global_position = b["pos"]
			n.rotation = Vector3(0, atan2(-dir.x, -dir.y), 0)
			(n.get_node("Spin") as Node3D).rotation.x = float(b["spin"])

## One frame of flight, read every BURR_SAMPLE m so no tile is skipped: a slight lob that rides up ramps,
## stairs and low ledges, and stops only on a strict wall (`_burr_wall`), on a foe, or at the lane's end (a dud).
func _fly_burr(b: Dictionary, bd: Dictionary, dt: float) -> void:
	var p: Vector3 = b["pos"]
	var dir: Vector2 = b["dir"]
	var speed := float(bd["speed"])
	var steps := maxi(1, ceili(speed * dt / BURR_SAMPLE))
	var run := speed * dt / steps
	var at := p
	var g_last: float = m.world.ground_at(p.x, p.z)
	for _i in steps:
		b["t"] = float(b["t"]) + dt / steps
		var q := at + Vector3(dir.x, 0, dir.y) * run
		var dist: float = float(b["t"]) * speed
		var u := clampf(dist / float(b["range"]), 0.0, 1.0)
		if _burr_wall(g_last, q, run):      # q is still at the height it arrives with
			_stick(b, at)
			return
		var gy := ground(q).y
		q.y = maxf(lerpf(float(b["y0"]), gy + BURR_RIDE, u * u) + 0.6 * sin(PI * u), gy + BURR_RIDE)
		var victim := _burr_victim(at, q)
		if victim != null:
			burrs.erase(b)
			_direct_hit(b, victim, q)
			return
		if dist >= float(b["range"]):
			_dud(b, q)
			return
		at = q
		g_last = m.world.ground_at(q.x, q.z)
	b["pos"] = at
<<<<<<< HEAD
	var back := Vector3(dir.x, 0, dir.y) * 0.35
	fx().smear(p - back, at, DEEP, HOT, 0.3, 0.2)      # the smear behind it (joined up)
	if int(b["t"] * 60.0) % 3 == 0:
		m.fx.burst(at, LIME, 3, 0.6, 0.25, 0.0, 0.7)
||||||| ba6b62f7a1
	var back := Vector3(dir.x, 0, dir.y) * 0.35
	fx().smear(p - back, at, DEEP, HOT, 0.3, 0.2)      # the ember smear behind it (joined up)
	if int(b["t"] * 60.0) % 3 == 0:
		m.fx.burst(at, EMBER, 3, 0.6, 0.25, 0.0, 0.7)
=======
>>>>>>> origin/main

## A strict wall at `q` (the coin's next spot, at its height): a blocker tile standing above it, or ground
## that rose from `g_from` over `run` m by more than a walkable step and steeper than BURR_WALL_DEG, with its
## top above the coin. Ramps and stairs (39 deg) and ledges below the coin are not walls: it rides up them.
func _burr_wall(g_from: float, q: Vector3, run: float) -> bool:
	var g: float = m.world.ground_at(q.x, q.z)
	if m.world.is_block(q.x, q.z):
		return g + World.BLOCK_H > q.y
	return g > q.y and g - g_from > maxf(World.STEP, run * tan(deg_to_rad(BURR_WALL_DEG)))

## The first foe the coin touches between two steps, or null. Reach is the foe's body plus the lane's half width.
func _burr_victim(from: Vector3, to: Vector3) -> Ent:
	var reach_extra := float(rmb_def()["burr"]["lane_w"]) * 0.5
	var from_flat := Vector2(from.x, from.z)
	var to_flat := Vector2(to.x, to.z)
	var best: Ent = null
	var best_along := INF
	for f in m.foes_of(h.team):
		if not f.hittable():
			continue
		var height: float = to.y - f.pos.y
		if height < -0.3 or height > BURR_HIT_HEIGHT:
			continue
		var foe_flat := Vector2(f.pos.x, f.pos.z)
		var closest := Geometry2D.get_closest_point_to_segment(foe_flat, from_flat, to_flat)
		if closest.distance_to(foe_flat) > f.r + reach_extra:
			continue
		var along := from_flat.distance_to(closest)
		if along < best_along:
			best_along = along
			best = f
	return best

## A direct hit: it hurts and Dazes the foe it struck and is spent, with no cone.
func _direct_hit(b: Dictionary, victim: Ent, at: Vector3) -> void:
	var bd := rmb_def()["burr"] as Dictionary
	var n: Node3D = b["node"]
	if is_instance_valid(n):
		n.visible = false
	direct_hits += 1
<<<<<<< HEAD
	var dir: Vector2 = b["dir"]
	var spray := Vector3(-dir.x, 0.2, -dir.y)
	m.fx.flash(at, HOT, 1.2, 0.1)
	m.fx.burst(at, LIME, 12, 6.0, 0.35, 2.0, 1.0, spray, 70.0)
	m.sfx("vn_blast", at, -4.0)
||||||| ba6b62f7a1
	var dir: Vector2 = b["dir"]
	var spray := Vector3(-dir.x, 0.2, -dir.y)
	m.fx.flash(at, HOT, 1.2, 0.1)
	m.fx.burst(at, EMBER, 12, 6.0, 0.35, 2.0, 1.0, spray, 70.0)
	m.sfx("vn_blast", at, -4.0)
=======
>>>>>>> origin/main
	var o := {"src": "abil", "ab": "utility", "tags": ["utility", "burr"]}
	victim.hurt(float(bd["hit_dmg"]) * power("sec"), h, o)
	daze(victim, float(bd["cone_rattle"]))
	_confirm_hit(victim, at, b["dir"])

## Only a charge that strikes a foe does this, so a hit can't be mistaken for a miss (a stick in terrain,
## with a dust puff): a flare and a ring round the foe, its body held lit, and for the thrower a gold hitmarker
## and a ping.
func _confirm_hit(victim: Ent, at: Vector3, dir: Vector2) -> void:
	victim.flash_t = maxf(victim.flash_t, HIT_HOLD)
	vfx("rmb_hit", victim.pos, -dir, {"r": victim.r + 0.9})
	if h == m.player and m.hud:
		m.hud.hitmarker(true)
		m.sfx("crit", at, -2.0, 0.8)

## RecastCue's badge: Dazed foes (her rifle and Palm Lance hit harder; a Palm Lance on a Dazed rival SKEWERS).
func combo_marks(out: Array) -> void:
	super(out)
	for key in daze_for.keys():
		var f := instance_from_id(key) as Ent
		var left: float = KitStatus.rattled_left(f) if f != null else 0.0
		if left <= 0.0:
			daze_for.erase(key)
		elif not f.dead:
			out.append(RecastCue.mark(f, 0, left, maxf(left, float(daze_for[key])), true))

<<<<<<< HEAD
## Dazed: the foe takes more from the rifle and the Palm Lance (rattle_k in the data) and is slowed.
||||||| ba6b62f7a1
## Dazed: the foe takes more from the rifle and Longneedle (rattle_k in the data) and is slowed.
=======
## Dazed: the foe takes more from the rifle and Longneedle (rattle_k in the data). The status draws its own
## crown of stars over the head (KitStatus).
>>>>>>> origin/main
func daze(foe: Ent, seconds: float) -> void:
	KitStatus.apply(foe, "rat", seconds)
	daze_for[foe.get_instance_id()] = seconds

## It meets a wall and sticks: the cone points back the way it came.
func _stick(b: Dictionary, at: Vector3) -> void:
	var bd := rmb_def()["burr"] as Dictionary
	b["pos"] = at
	b["fuse"] = float(bd["fuse"])
	b["fuse0"] = float(bd["fuse"])
	b["out"] = -(b["dir"] as Vector2)
<<<<<<< HEAD
	net_cone(at, b["out"], float(bd["cone_len"]), float(bd["cone_deg"]), float(bd["fuse"]), LIME)
	m.sfx("gunslinger_grenade_thunk", at, -3.0)
	fx().star(at, LIME, HOT, 0.6, 0.12)
	m.fx.burst(at, SCRAPE, 6, 2.5, 0.4, 6.0, 0.8)       # a dull dust puff, no flash, nothing on a foe
||||||| ba6b62f7a1
	net_cone(at, b["out"], float(bd["cone_len"]), float(bd["cone_deg"]), float(bd["fuse"]), EMBER)
	m.sfx("gunslinger_grenade_thunk", at, -3.0)
	fx().star(at, EMBER, HOT, 0.6, 0.12)
	m.fx.burst(at, SCRAPE, 6, 2.5, 0.4, 6.0, 0.8)       # a dull dust puff, no flash, nothing on a foe
=======
	net_cone(at, b["out"], float(bd["cone_len"]), float(bd["cone_deg"]), float(bd["fuse"]), LIME)
	vfx("rmb_stick", at, b["out"])       # the miss: a small flare and a dull dust puff, nothing on a foe
>>>>>>> origin/main

## The lane's end with no foe and no wall, wherever the coin is (ground or air): a miss is a miss. A small
## puff and a dull low thunk, no damage, no Daze, no cone.
func _dud(b: Dictionary, at: Vector3) -> void:
	burrs.erase(b)
	duds += 1
	var n: Node3D = b["node"]
	if is_instance_valid(n):
		n.visible = false
	m.fx.burst(at, DUD_DUST, 5, 1.5, 0.35, 2.0, 0.6)
	m.sfx("gunslinger_grenade_thunk", at, -9.0, 0.6)

func _detonate(b: Dictionary) -> void:
	var bd := rmb_def()["burr"] as Dictionary
	var n: Node3D = b["node"]
	if is_instance_valid(n):
		n.visible = false
		AimKit.hide(h, "burr%d" % n.get_instance_id())
	var at: Vector3 = b["pos"]
	rattles += 1
	_cone(at, b["out"] as Vector2, bd)

## The blast: a cone back out of the stick point, shoving everything in it along the cone (toward the
## thrower) and Dazing it; a hunter shoved into more terrain is stunned.
func _cone(at: Vector3, out: Vector2, bd: Dictionary) -> void:
<<<<<<< HEAD
	fx().fan(ground(at), out, float(bd["cone_len"]), float(bd["cone_deg"]), LIME, HOT, 0.35)
	var spray := Vector3(out.x, 0.2, out.y)
	m.fx.burst(at + Vector3(out.x, 0.4, out.y) * 1.5, LIME, 18, 8.0, 0.4, 3.0, 1.4, spray, float(bd["cone_deg"]) * 0.5)
||||||| ba6b62f7a1
	fx().fan(ground(at), out, float(bd["cone_len"]), float(bd["cone_deg"]), EMBER, HOT, 0.35)
	var spray := Vector3(out.x, 0.2, out.y)
	m.fx.burst(at + Vector3(out.x, 0.4, out.y) * 1.5, EMBER, 18, 8.0, 0.4, 3.0, 1.4, spray, float(bd["cone_deg"]) * 0.5)
=======
	vfx("rmb_blast", ground(at), out, {"len": float(bd["cone_len"])})   # the flame front and its scorched cone
>>>>>>> origin/main
	for f in m.foes_of(h.team):
		if not f.hittable(): continue
		if absf(f.pos.y - at.y) > 2.6: continue
		if not AimMode.in_cone(at, out, float(bd["cone_len"]), float(bd["cone_deg"]), f.pos, 0.3, f.r): continue
		var to := Vector2(f.pos.x - at.x, f.pos.z - at.z)
		var away := (out * 0.6 + to.normalized() * 0.4).normalized() if to.length() > 0.2 else out
		var o := {"src": "abil", "ab": "utility", "tags": ["utility", "burr"], "kb": away * float(bd["push"])}
		o["lift"] = 2.0
		f.hurt(float(bd["cone_dmg"]) * power("sec"), h, o)
		daze(f, float(bd["cone_rattle"]))         # the training dummy too
		if f is Hunter and KnockWall.hit(m, f, away, 2.4, h):
			wall_slams += 1
			var slam := {"src": "abil", "ab": "utility", "tags": ["utility", "burr"], "stun": float(bd["wall_stun"])}
			slam["dr"] = true
			f.hurt(0.1, h, slam)
			daze(f, float(bd["cone_rattle"]) + float(bd["wall_daze"]))     # the data: walled, "Dazed longer"

# ------------------------------------------------------------------ E: Palm Lance
func cast_e() -> bool:
	if not needle.is_empty(): return false
	var ed := e_def()
	needle = {"t": 0.0, "dir": h.aim_dir(), "push": _push_want()}
	e_t = float(ed["charge"]) + 0.1
	m.sfx("vn_ion_charge", h.pos, -3.0)
	play("gunslinger_e")
	return true

## A Boki merge ends the Palm Lance's charge with no shot and cuts a Slipstep short (no refund, no speed buff).
func _drop_holds() -> void:
	_end_needle()
	if not slide.is_empty():
		slide = {}
		h.roll_t = 0.0
	rmb_down = false
	rmb_t = 0.0

func _end_needle() -> void:
	if needle.is_empty():
		return
	needle = {}
	e_t = 0.0
	AimKit.hide(h, "e")

## While the Palm Lance charges she aims along the capped line, not the cursor (ZERO otherwise: free).
func aim_lock() -> Vector2:
	return needle.get("dir", Vector2.ZERO)

func _tick_needle(dt: float) -> void:
	var ed := e_def()
	needle["t"] = float(needle["t"]) + dt
	if h.downed or h.stun_t > 0.0 or Hex.active(h):
		_end_needle()
		return
	_turn_needle(dt)
	var k := clampf(float(needle["t"]) / float(ed["charge"]), 0.0, 1.0)
	# a bright wide line drawn full length at once, narrowing to a thin core as the cast completes
	var wide := beam_width()
	var lane := {"len": float(ed["range"]), "width": wide, "width_to": wide * 0.12, "k": k, "all": true}
	lane.merge({"col": LIME, "col2": HOT})
	AimKit.lane(h, "e", lane)
	needle["push"] = lerpf(float(needle["push"]), _push_want(), 1.0 - exp(-PUSH_EASE * dt))
	if h.is_local() and m.cam:
		var push := float(needle["push"])
		m.cam.cast_view(h.aim_dir(), float(ed["view_zoom"]) * push, float(ed["range"]) * push)   # (the caster's camera)
<<<<<<< HEAD
	AimKit.charge(h, k, {"col": LIME, "col2": HOT})
	HeroVfx.of(m).hold(h, "e_charge", k)          # lime sparks drawn into the muzzle through the cast
	# green fire swells in her raised palm through the cast
	if int(m.time * 20.0) != int((m.time - dt) * 20.0):
		fx().star(palm_at(), LIME, HOT, 0.35 + 0.6 * k, 0.07)
||||||| ba6b62f7a1
	AimKit.charge(h, k, {"col": EMBER, "col2": HOT})
	# an ember orb swells at the muzzle through the cast
	if int(m.time * 20.0) != int((m.time - dt) * 20.0):
		fx().star(_muzzle(h.aim_dir()), EMBER, HOT, 0.35 + 0.6 * k, 0.07)
=======
	AimKit.charge(h, k, {"col": LIME, "col2": HOT})
	HeroVfx.of(m).hold(h, "e_charge", k)       # green fire drawn into the muzzle through the cast
>>>>>>> origin/main
	if float(needle["t"]) >= float(ed["charge"]) + 0.03:          # (a beat at full so the full tick plays)
		_fire_needle()                                              # along the capped aim, so before the lock lifts
		_end_needle()

## The locked aim turns toward the cursor at the data's capped rate (deg/s): a flick across the screen can't drag it.
func _turn_needle(dt: float) -> void:
	var want := _cursor()
	if want.length() < 0.05:
		return
	var cur: Vector2 = needle["dir"]
	var step := deg_to_rad(float(e_def()["turn_deg_s"])) * dt
	needle["dir"] = cur.rotated(clampf(cur.angle_to(want), -step, step)).normalized()

## The cursor relative to her on the ground: where she wants to aim, as against the capped aim she holds.
func _cursor() -> Vector2:
	var a: Vector3 = h.inp["aim"]
	return Vector2(a.x - h.pos.x, a.z - h.pos.z)

## How much of the view push-out this aim distance asks for: none inside view_near_m, all of it at full range.
func _push_want() -> float:
	var ed := e_def()
	return smoothstep(float(ed["view_near_m"]), float(ed["range"]), _cursor().length())

## The beam's full width in m: what it hits, so the line, the beam and the hit all agree.
func beam_width() -> float:
	return float(e_def()["width"]) * 2.0

func dash_charge() -> float:
	return -1.0

func charge_now() -> Array:
	if not needle.is_empty():
		return ["needle", clampf(float(needle["t"]) / float(e_def()["charge"]), 0.0, 1.0)]
	return super.charge_now()

func _fire_needle() -> void:
	var ed := e_def()
	var d := h.aim_dir()
	var a := palm_at()                        # the beam leaves her open palm; what it hits is still from her feet
	var L := float(ed["range"])
	L = minf(L, Blockers.cut(m.verbs.walls, a, a + Vector3(d.x, 0, d.y) * L, h.team, "pierce"))   # placed walls stop it
	needle_dir = d
<<<<<<< HEAD
	# a taut needle of light (deep body, white-hot core, sparks shed along it), a bloom at her palm,
	# recoil smoke round her
	vfx("e_fire", a, d, {"len": L, "r": beam_width()})
||||||| ba6b62f7a1
	# an ember body, a hot core, a bronze shimmer down its edges; the ember muzzle orb and its flare
	fx().beam(a, b, EMBER, HOT, beam_width(), float(ed["linger"]), BRONZE)
	fx().star(a, EMBER, HOT, 1.3, 0.16)
	m.fx.flash(a, EMBER, 1.2, 0.08)
	fx().pillar(ground(h.pos), SMOKE, EMBER, 1.6, 0.45, 0.4)   # recoil smoke puffs up round her (no ground ring)
	net_bolt(a, b, EMBER)
	m.sfx("vn_ion_fire", h.pos, 1.0)
=======
	# a taut needle of light (deep body, white-hot core, sparks shed along it), a muzzle bloom, recoil smoke round her
	vfx("e_fire", a, d, {"len": L, "r": beam_width()})
>>>>>>> origin/main
	h.impulse(-d * float(ed.get("recoil", 6.0)))                  # the recoil shoves her back a step
	commit_end = float(m.time) + E_RECOVER
	var hits := 0
	var dmg0: float = float(ed["dmg"]) * power("kin")
	for f in m.foes_of(h.team):
		if not f.hittable(): continue
		var v := Vector2(f.pos.x - h.pos.x, f.pos.z - h.pos.z)
		var along := v.dot(d)
		if along < 0.0 or along > L + f.r: continue
		if absf(v.cross(d)) > float(ed["width"]) + f.r: continue
		if absf(f.pos.y - h.pos.y) > 2.6: continue
		var rat := KitStatus.rattled(f)
		var dmg: float = dmg0 * ((1.0 + float(ed["rattle_k"])) if rat else 1.0)
		var o := {"src": "abil", "ab": "k1", "tags": ["k1", "needle"]}
		if rat:
			ComboMark.payoff(m, h, f)
			o["payoff"] = f is Hunter
		f.hurt(dmg, h, o)
		needle_hits += 1
		vfx("e_hit", f.pos + Vector3(0, 1.0, 0), d)
		if f is Hunter:
			hits += 1
			if rat:
				skewers += 1
				payoff_fx(f.pos, LIME, "", h.dir_to(f), f)
				m.sfx("hero_skewer", f.pos, 0.0)
	if hits > 0:
		var maxcd := float(ed["cooldown"]) * cd_k("kin")
		var cut := float(ed["shave"])
		if rank("kin") >= 3:
			cut = float(ed["shave_rank3"]) * hits       # rank 3: 30% for every hunter hit
		cd["e"] = maxf(0.0, float(cd["e"]) - maxcd * cut)

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	var aimp := tgt.pos + Vector3(0, 0.9, 0)
	if not needle.is_empty() or rmb_down:
		h.inp["aim"] = aimp
		return
	if HeroUlt.ready(self) and tgt is Hunter and los and dist > 2.5:
		h.inp["aim"] = aimp
		if HunterKeys.ult_pressed(h):
			return
	var needle_ok := int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and los and dist > 4.0 and dist < 17.0
	if needle_ok and (KitStatus.rattled(tgt) or randf() < 0.15):
		h.inp["aim"] = aimp
		h.inp["sig"] = true
		return
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and los and dist < 10.0 and dist > 2.0 and randf() < 0.4:
		# throw it past them so the cone comes back over them
		h.inp["aim"] = aimp
		h.inp["sec"] = true
		return
	if h.hp < h.max_hp * 0.4 and h.dashes >= 1.0 and randf() < 0.1:
		h.inp["dash"] = true
		bot_hold["dash"] = 0.5
