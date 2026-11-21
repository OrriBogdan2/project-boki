class_name KinWispProc
extends RefCounted
## A carried passive acting, heard and named. When a passive the wisp carries acts on its hunter (a heal, a shield
## soak or damage cut, a damage bonus on a shot, a run speed boost) the wisp makes one very short, quiet chirp in
## its species' own voice (KinVoice.cue), pitched by body size and placed on the wisp; a rival's wisp chirps too,
## quieter, within the sound's reach. Your own Boki's first cue also gives the one-time tip that names the passive
## (tip, Match._tips). It reads the hunter's state (hp, shield, armor, muzzle, speed), so a rival's wisp cues from
## the snapshot as well. One instance per wisp (Kin.proc); KinWisp.render calls watch. Mix level: docs/AUDIO.md.

const EVERY_S := 0.8  # s: at most one chirp per wisp
const OWN_DB := -20.0  # dB: your wisp, a quiet tick under the gun
const RIVAL_DB := -26.0  # dB: another hunter's wisp, before distance
const DUCK_S := 0.35  # s after its hunter's ability cast in which the chirp gives way
const DUCK_DB := -8.0  # dB: how far it gives way
const SIZE_PITCH := {"small": 1.3, "medium": 1.0, "large": 0.78}  # small bodies chirp higher
const RUN_START := 3.0  # m/s the hunter must pass, from standing, for the speed boost to read
const TIP_KEEP_S := 6.0  # s a cue may wait for the first-proc tip (the tip lane can be busy)
const KINDS := {  # cue kind -> the carry passive stats that make it
	"heal": ["regen"],
	"shield": ["armor", "damage_reduction", "knockback_resist"],
	"damage": ["damage"],
	"speed": ["move_speed"],
}

static var played := 0  # chirps played this run (the check counts them)

var last_kind := ""  # the kind of the last cue
var last_at := -1e9  # Match.time of the last cue
var _seen := false
var _hp := 0.0
var _soak := 0.0  # armor plus kin shield last frame
var _muzzle := 0.0
var _moving := false


## Watch one wisp's hunter this frame and chirp if a passive of the wisp acted (KinWisp.render calls it).
static func watch(k: Kin) -> void:
	if k.ks == null or k.ks.carry_passives.is_empty():
		return
	if k.proc == null:
		k.proc = KinWispProc.new()
	k.proc._look(k)


## The carry passives of `k` that make a cue of this kind.
static func passives_of(k: Kin, kind: String) -> Array:
	return k.ks.carry_passives.filter(func(ps): return String(ps["stat"]) in KINDS[kind])


## The first-proc tip for your Boki `k`, "<Boki>'s <passive>: <what it does>" from its carry data, while its last
## cue is under TIP_KEEP_S old ("" otherwise). Match._tips shows it once per save.
static func tip(k: Kin) -> String:
	if k.proc == null or k.proc.last_kind == "" or k.m.time - k.proc.last_at > TIP_KEEP_S:
		return ""
	var share := float(KinSteal.rules()["passive_k"]) if KinSteal.stolen(k) else 1.0
	return (
		"%s's carry passive: %s"
		% [k.rec.get("name", "Your Boki"), KinText.passives(passives_of(k, k.proc.last_kind), share)]
	)


## How loud this hunter's chirp is: yours over a rival's, and under any ability it just cast.
static func level_db(h: Hunter) -> float:
	var db := OWN_DB if h == h.m.player else RIVAL_DB
	return db + (DUCK_DB if h.m.time - h.cast_at < DUCK_S else 0.0)


func _look(k: Kin) -> void:
	var h := k.owner_h
	if h == null or h.downed or h.out:
		_seen = false
		return
	var soak := h.armor + h.kin_shield
	var speed := Vector2(h.vel.x, h.vel.z).length()
	var kind := ""
	if _seen:
		if h.hp > _hp and not passives_of(k, "heal").is_empty():
			kind = "heal"
		elif (soak < _soak - 0.01 or h.hp < _hp - 0.01) and not passives_of(k, "shield").is_empty():
			kind = "shield"
		elif h.muzzle_t > _muzzle and not passives_of(k, "damage").is_empty():
			kind = "damage"
		elif speed > RUN_START and not _moving and not passives_of(k, "speed").is_empty():
			kind = "speed"
	_hp = h.hp
	_soak = soak
	_muzzle = h.muzzle_t
	_moving = speed > RUN_START * 0.5
	_seen = true
	if kind != "" and k.m.time - last_at >= EVERY_S:
		_chirp(k, h, kind)


func _chirp(k: Kin, h: Hunter, kind: String) -> void:
	last_kind = kind
	last_at = k.m.time
	var pitch := float(SIZE_PITCH.get(k.ks.size, 1.0)) * Unique.voice(k.rec)
	k.m.sfx(KinVoice.cue(k.species, "happy"), k.global_position, level_db(h), pitch)
	played += 1
