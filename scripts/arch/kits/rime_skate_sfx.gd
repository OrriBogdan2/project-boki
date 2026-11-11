class_name RimeSkateSfx
extends RefCounted
## Neve's skate sounds for the 11-11 skate (a carve that builds to dash.steer, a 0.7x slide-out); her set is
## content/sfx/rimewright.json, made by tools/gen_sfx_claire.py. Ticked once a frame for her on every screen
## (ArchKit.sound_tick): her own game reads the running skate, other players' games read her synced move and
## velocity (ArchKit.apply_net_move, Hunter.net_vel), so they hear it positional and quieter, with no Net change.
##   glide   the skate loop, held while she skates, its pitch and level following her speed
##   stride  each stride's scrape as the stride move restarts, levelled by her speed
##   carve   an edge scrape every CARVE_GAP s while she turns, louder and higher as the turn rate nears the cap
##   hiss    the slide-out's hiss, held from the release until she stops

const SKATE_MOVES := ["tm_skate_go", "tm_skate", "tm_skate_air"]
const STRIDE_MOVES := ["tm_skate", "tm_skate_air"]
const STOP_MOVE := "tm_skate_stop"
const GLIDE_DB := Vector2(-20.0, -10.0)       # dB of the skate loop at a standstill and at skate speed
const GLIDE_PITCH := Vector2(0.8, 1.1)        # its pitch at a standstill and at skate speed
const STRIDE_DB := Vector2(-11.0, -5.0)       # dB of a stride's scrape at a standstill and at skate speed
const CARVE_FROM := 0.3        # share of the steer cap under which the edge stays quiet
const CARVE_GAP := 0.12        # s between two carve scrapes: throttled, never one a frame
const CARVE_DB := Vector2(-16.0, -5.0)        # dB of a carve scrape at CARVE_FROM and at the cap
const CARVE_PITCH := Vector2(0.92, 1.15)      # its pitch at CARVE_FROM and at the cap
const TURN_IN := 12.0          # 1/s: smoothing of another player's turn rate, read off their synced velocity
const HISS_DB := Vector2(-21.0, -7.0)         # dB of the slide-out hiss as she stops and at the release
const STILL_V := 0.05          # m/s: under this she has stopped, and the slide-out is over
const OTHERS_DB := -6.0        # dB under yours for another player's skate

var glide_key := ""            # Sfx loop keys, one pair per hunter (made on the first tick)
var hiss_key := ""
var gliding := false           # the skate loop was held last tick
var stride_at := -1.0          # anim_at of the last stride move scraped
var carve_t := 0.0             # s until the next carve scrape may play
var turn := 0.0                # rad/s, another player's turn rate (smoothed)
var heading := Vector2.ZERO    # their last direction of travel
var slide_at := -1.0           # anim_at of the stop move whose slide-out hisses
var hiss_v := 0.0              # m/s at that release (0: no slide-out hissing)
var last_v := 0.0              # m/s last tick
var stats := {"carve": 0, "carve_db": 0.0, "hiss": false, "hiss_t": 0.0}     # for the checks

func tick(k: RimewrightKit, dt: float) -> void:
	var h := k.h
	if glide_key == "":
		glide_key = "neve_glide%d" % h.get_instance_id()
		hiss_key = "neve_hiss%d" % h.get_instance_id()
	var v3 := h.net_vel if h.remote else h.vel
	var vel := Vector2(v3.x, v3.z)
	var v := vel.length()
	var trim := 0.0 if h.is_local() else OTHERS_DB
	var sk := clampf(v / float(k.dash_def().get("speed", 11.5)), 0.0, 1.0)
	var skating := _net_skating(k) if h.remote else k.rinkrunning()
	if skating:
		var db := lerpf(GLIDE_DB.x, GLIDE_DB.y, sk) + trim
		Sfx.loop_hold(glide_key, "rimewright_skate_glide", h.pos, db, lerpf(GLIDE_PITCH.x, GLIDE_PITCH.y, sk))
		_stride(k, sk, trim)
		_carve(k, vel, dt, trim)
	elif gliding:
		Sfx.loop_stop(glide_key)
		carve_t = 0.0
		turn = 0.0
	gliding = skating
	_hiss(k, v, dt, trim)
	last_v = v

## Another player's skate: one of the skate moves, still inside its length (the stride replays every length).
func _net_skating(k: RimewrightKit) -> bool:
	return k.anim_id in SKATE_MOVES and k.m.time - k.anim_at <= KMovesCare.length(k.anim_id) + 0.1

func _stride(k: RimewrightKit, sk: float, trim: float) -> void:
	if not k.anim_id in STRIDE_MOVES or k.anim_at == stride_at:
		return
	stride_at = k.anim_at
	k.m.sfx("rimewright_skate_scrape", k.h.pos, lerpf(STRIDE_DB.x, STRIDE_DB.y, sk) + trim, 1.0)

func _carve(k: RimewrightKit, vel: Vector2, dt: float, trim: float) -> void:
	var rate := _net_turn(vel, dt) if k.h.remote else float(k.rinkrun.get("rate", 0.0))
	var near := absf(rate) / float(k.dash_def().get("steer", 1.6))
	carve_t -= dt
	if near < CARVE_FROM or carve_t > 0.0:
		return
	carve_t = CARVE_GAP
	var c := clampf(inverse_lerp(CARVE_FROM, 1.0, near), 0.0, 1.0)
	stats["carve"] = int(stats["carve"]) + 1
	stats["carve_db"] = lerpf(CARVE_DB.x, CARVE_DB.y, c)
	k.m.sfx("rimewright_skate_carve", k.h.pos, float(stats["carve_db"]) + trim, lerpf(CARVE_PITCH.x, CARVE_PITCH.y, c))

## Another player's turn rate: how fast their synced velocity swings round, smoothed over the packets.
func _net_turn(vel: Vector2, dt: float) -> float:
	if vel.length() < 0.5 or dt <= 0.0:
		return turn
	var dir := vel.normalized()
	var now := heading.angle_to(dir) / dt if heading != Vector2.ZERO else 0.0
	heading = dir
	turn = lerpf(turn, now, 1.0 - exp(-TURN_IN * dt))
	return turn

## The slide-out: the hiss starts with the stop move on the ground and lasts while she slides, fading with her
## speed; it stops the tick she stops (or speeds up again, leaves the ground or does anything else).
func _hiss(k: RimewrightKit, v: float, dt: float, trim: float) -> void:
	var h := k.h
	var grounded := (h.pos.y - h.ground() <= Match.HOP_STAND) if h.remote else h.grounded
	var stopping := k.anim_id == STOP_MOVE and grounded
	if stopping and k.anim_at != slide_at:
		slide_at = k.anim_at
		hiss_v = v
	var on := stopping and k.anim_at == slide_at and hiss_v > 0.0 and v > STILL_V and v <= last_v + 0.01
	if on:
		var db := lerpf(HISS_DB.x, HISS_DB.y, clampf(v / hiss_v, 0.0, 1.0)) + trim
		Sfx.loop_hold(hiss_key, "rimewright_skate_hiss", h.pos, db, 1.0)
		stats["hiss_t"] = float(stats["hiss_t"]) + dt
	elif bool(stats["hiss"]):
		Sfx.loop_stop(hiss_key)
		hiss_v = 0.0
	stats["hiss"] = on
