class_name RaidSfx
extends RefCounted
## Heart Raid's sounds (tools/gen_sfx_raid.py, content/sfx/raid.json), through the one Sfx path. The wave and the
## boss cues come from the director's state (update), so the host and a client, whose state arrives by "hr", hear
## the same; the gate ticks follow the marks (HeartRaidGates.show_marks), which every machine works out alike.
##   gate tick     raid_gate_tick      a marked gate, once a second in the last TICK_S s, at the gate
##   wave opens    raid_wave_open      the wave leaves its gates (flat)
##   boss rises    raid_boss_rise      at the Heart
##   phase change  raid_phase          at the boss (Boss._phase_up, host only: a client's boss is a plain Mob)
##   rockfall      raid_rockfall_warn  at the boss, as a Nightmare boss starts its extra rockfall (Boss, host only)
## Voice limits: Sfx merges one name within 30 ms and stacks at most 3 within 90 ms, so a wave's gates tick
## GATE_STAGGER_S apart (3 gates at most, one tick each per second).

const TICK_S := 3                 # s: a marked gate ticks on each whole second of the countdown up to this
const GATE_STAGGER_S := 0.1       # s between one gate's tick and the next (past Sfx.STACK_MS)
const TICK_DB := -6.0             # a soft tell
const WAVE_DB := -2.0
const RISE_DB := 0.0
const PHASE_DB := 0.0
const WARN_DB := -2.0

var cues: Array = []              # every cue in order, for the check
var _rd: HeartRaid
var _wave := -1
var _phase := -1

func _init(raid: HeartRaid) -> void:
	_rd = raid

## Cues what changed since the last look (a wave sent, the boss up).
func update() -> void:
	if _wave >= 0 and _rd.wave > _wave:
		_cue("raid_wave_open", null, WAVE_DB)
	if _phase >= 0 and _phase == HeartRaid.P.WAVES and _rd.phase == HeartRaid.P.BOSS:
		_cue("raid_boss_rise", _rd.m.heart.site, RISE_DB)
	_wave = _rd.wave
	_phase = _rd.phase

## One tick for the gate `n` of the marked wave (0 first), at its spot.
func gate_tick(at: Vector3, n: int) -> void:
	_rd.m.later(n * GATE_STAGGER_S, func(): _cue("raid_gate_tick", at, TICK_DB))

func boss_phase(at: Vector3) -> void:
	_cue("raid_phase", at, PHASE_DB)

func rockfall(at: Vector3) -> void:
	_cue("raid_rockfall_warn", at, WARN_DB)

func _cue(sname: String, at, vol: float) -> void:
	cues.append(sname)
	_rd.m.sfx(sname, at, vol)
