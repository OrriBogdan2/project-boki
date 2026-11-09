class_name HealRead
extends Node
## How a heal or a shield gain reads, one look for every source (as the source game shows it): the one
## healed gets a short green rise up the body and a green "+N" that adds up every heal landing on them
## inside MERGE_S; a shield gain flashes their shield shell white (ShieldLook.gain). Your heals and your
## squad's always show; a rival's only when it is big (BIG_K of their health inside one window).
## Every heal goes through Hunter.heal or Effects._heal, which call healed(); every shield gain calls
## shield(). The heal that comes with a dash reset (DashReset.takedown) is quiet: its number, no rise
## (no bursts on dashes or resets). Remote Hunters heal on their own game; here their health and shield
## rising in the state snapshot (note / synced) gets the same look. Checked by --heal-read-check.

const MERGE_S := 0.3          # s: heals on one body inside this window show as one number
const BIG_K := 0.1            # of max health: a rival's heal this big (per window) is shown
const SYNC_MIN := 2.0         # hp: a remote rise per snapshot under this is regen, not a heal
const GREEN := Color("8ff0a0")
const RISE_N := 22            # dots in the green rise
const RISE_SPEED := 3.0       # m/s: how fast they leave the feet
const RISE_LIFT := 5.0        # m/s²: they speed up as they climb (negative gravity)
const RISE_S := 0.55          # s: how long they live (about a body height)
const RISE_SPREAD := 18.0     # degrees off straight up
const RISE_SIZE := 1.5        # dot size (Fx.burst size_k)

var m: Match
var heals := 0                # (checks) heals read, quiet ones too
var rises := 0                # (checks) green rises shown
var numbers := 0              # (checks) green numbers shown, and the last one's amount
var last_number := 0.0
var _open := {}               # Ent -> [amount so far, age, risen]
var _hp0 := 0.0               # a remote Hunter's health, shield and max health before its snapshot
var _sh0 := 0.0
var _top0 := 0.0
var _up0 := false

func _init(match_node: Match) -> void:
	m = match_node
	name = "HealRead"

## `e` just gained `n` health. `quiet`: show the number only (a dash reset's heal).
func healed(e: Ent, n: float, quiet := false) -> void:
	if n <= 0.0 or e == null:
		return
	heals += 1
	var w: Array = _open.get(e, [])
	if w.is_empty():
		w = [0.0, 0.0, false]
		_open[e] = w
	w[0] = float(w[0]) + n
	if not quiet and not bool(w[2]) and _shows(e, float(w[0])):
		w[2] = true
		rises += 1
		m.fx.burst(e.pos + Vector3(0, 0.25, 0), GREEN, RISE_N, RISE_SPEED, RISE_S, -RISE_LIFT, RISE_SIZE, Vector3.UP,
			RISE_SPREAD)

## Raise `e`'s shield to at least `amount`; a real gain flashes the shell (a Boki has none: a small ring).
func shield(e: Ent, amount: float) -> void:
	var before := 0.0
	if e is Hunter:
		before = (e as Hunter).shield
		(e as Hunter).shield = maxf(before, amount)
	elif e is Kin:
		before = (e as Kin).shield
		(e as Kin).shield = maxf(before, amount)
	else:
		return
	if amount <= before or e.remote:
		return       # (a remote Hunter's own game sends the new shield; synced() flashes it then)
	if e is Hunter:
		ShieldLook.gain(e as Hunter)
	else:
		m.fx.ring(e.pos + Vector3(0, 0.1, 0), 0.7, Color.WHITE, 0.3)

## Before a remote Hunter's snapshot is applied: what it had.
func note(h: Hunter) -> void:
	_hp0 = h.hp
	_sh0 = h.shield
	_top0 = h.max_hp
	_up0 = not h.downed and not h.out

## After it: a heal or a shield gain that happened on its own game shows here too (not a revive, not a
## level's extra health, not regen).
func synced(h: Hunter) -> void:
	if not _up0 or h.downed or h.out:
		return
	if h.hp - _hp0 >= SYNC_MIN and is_equal_approx(h.max_hp, _top0):
		healed(h, h.hp - _hp0)
	if h.shield > _sh0 + 0.5:
		ShieldLook.gain(h)

func _process(dt: float) -> void:
	tick(dt)

## Ages the open windows; a closed one shows its number.
func tick(dt: float) -> void:
	if _open.is_empty():
		return
	for e in _open.keys():
		var w: Array = _open[e]
		w[1] = float(w[1]) + dt
		if float(w[1]) < MERGE_S:
			continue
		_open.erase(e)
		if is_instance_valid(e) and float(w[0]) >= 1.0 and _shows(e, float(w[0])):
			numbers += 1
			last_number = float(w[0])
			m.fx.number(e.pos + Vector3(0, 1.6, 0), float(w[0]), GREEN, false, "+")

## Whether the local player sees a heal of `amount` on `e`: their own and their squad's always (a Boki
## counts as its Hunter's side), a rival's only when big.
func _shows(e: Ent, amount: float) -> bool:
	var body: Ent = e
	if e is Kin and (e as Kin).owner_h != null:
		body = (e as Kin).owner_h
	var lp: Hunter = m.player
	if lp == null or body.team == lp.team:
		return true
	return amount >= BIG_K * e.max_hp
