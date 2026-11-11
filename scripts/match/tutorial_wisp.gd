class_name TutorialWisp
extends RefCounted
## The tutorial's Boki-wisp beats (DECISIONS 2026-11-09 "Soul-linked Boki", docs/specs/TUTORIAL_WISP.md). Only
## when this match's Boki ride as wisps (KinWisp.mode); then they take the places of the walking Boki's steps
## (WALK_STEPS: gkey). wisp and summon come after shoot, on the open meadow (gkey's camp under the lookout is out of
## a summon's reach); steal comes before wayout.
## Three steps, seven beats:
##   wisp   - it rides with you as a wisp (1), and its carry passive is yours (2: the detail line names it)
##   summon - summon it at the camp (3); it fights for a short window (4), then rests as a wisp while its ring
##            fills (5: the cooldown); its camp pays no XP (pick_kin tops the level up to 3)
##   steal  - a downed decoy Hunter (a round wisp) beside its Boki wisp (a critter outline) (6); its wisp broke
##            loose: hold interact to steal it and carry it out (7)
## Every beat has a fallback, so nothing strands: the wisp step ends by itself, the Boki comes out by itself after
## SELF_T, the loose wisp comes to you after FLOAT_T. Nothing is lost: stolen wisps go home at match end
## (KinSteal.match_end) and the decoy is the tutorial's own.
## The steps, words and fallbacks: content/rules/tutorial.json.

const STEPS := ["wisp", "summon", "steal"]
const WALK_STEPS := ["gkey"]     # the walking Boki's step these replace
const WISP_T := 3.0       # s the wisp step stays up
const SELF_T := 20.0      # s before a Boki not yet summoned comes out by itself
const WINDOW_S := 6.0     # s: the summon window here (shorter than any species' own; content/rules/boki_summon.json)
const REST_SEE_T := 1.5   # s of the resting wisp (its ring filling) before the summon step is done
const OUTLINE_T := 3.0    # s the outline line shows before the grab line (sooner beside the wisp, banner settled)
const NEAR_M := 4.0       # m from the loose wisp that brings the grab line
const FLOAT_T := 14.0     # s before the loose wisp comes to you by itself
const DECOY_NAME := "Rival"

var tu: Tutorial
var m: Match
var seen_out := false     # the summon came out this step
var rest_t := 0.0         # s it has rested since
var decoy: Hunter = null  # the steal step's downed Hunter
var dk: Kin = null        # and its Boki wisp

func _init(tutorial: Tutorial, match_node: Match) -> void:
	tu = tutorial
	m = match_node

## Do this player's Boki ride as wisps here?
func on() -> bool:
	var k: Kin = m.player.kin
	return k != null and k.summon != null and KinWisp.mode(m)

## -1: not a step this decides; else whether it applies (wisp steps with wisps on, the walking ones without).
func applies(sid: String) -> int:
	if sid in STEPS:
		return 1 if on() else 0
	if sid in WALK_STEPS and on():
		return 0
	return -1

func enter(sid: String) -> void:
	seen_out = false
	rest_t = 0.0
	match sid:
		"summon":
			tu.camps.spawn("summon")
		"steal":
			_spawn_decoy()

## The step's test, run every frame (with its fallback).
func done(sid: String, dt: float) -> bool:
	var k: Kin = m.player.kin
	match sid:
		"wisp": return tu.t >= WISP_T
		"summon":
			var s := k.summon
			if not seen_out and not s.out() and tu.t >= SELF_T and s.cd <= 0.0 and k.wisp:
				s.burst(WINDOW_S)          # (the fallback: it comes out by itself)
			if s.left > WINDOW_S:
				s.left = WINDOW_S
			seen_out = seen_out or s.out()
			if seen_out and not s.out():
				rest_t += dt
			tu.flag = seen_out
			tu.seen["boki"] = tu.seen.get("boki", false) or seen_out
			return rest_t >= REST_SEE_T and tu._camp_done(sid)      # (a camp felled before the summon comes back)
		"steal":
			if decoy == null or dk == null:
				return true
			if KinSteal.stolen(dk) and dk.owner_h == m.player:
				return true
			if KinSteal.loose(dk):
				dk.loose_t = maxf(dk.loose_t, 2.0)      # (it waits for you instead of going home)
				if tu.t >= FLOAT_T:
					KinSteal.grab(dk, m.player)        # (the fallback: it comes to you)
			return false
	return false

## The alt line's key in tutorial.json "alt" for where the step is now, "" for the step's own line.
func alt(sid: String) -> String:
	match sid:
		"summon":
			if m.player.kin.summon.out():
				return "summon_out"
			return "summon_rest" if seen_out else ""
		"steal":
			var near := dk != null and m.player.flat_dist(dk) < NEAR_M
			return "steal_grab" if tu.t >= OUTLINE_T or (near and tu.t >= Tutorial.CARD_T) else ""
	return ""

## Where the marker points: the loose wisp in the steal step.
func goal(sid: String) -> Vector3:
	if sid == "steal" and dk != null and KinSteal.loose(dk):
		return dk.pos
	return Vector3.INF

## Every frame: the decoy stays down to the end (it never bleeds out, stands up or comes back).
func tick() -> void:
	if decoy and decoy.downed:
		decoy.down_hp = float(Data.MATCH["down_hp"])
		decoy.revive = 0.0

## Ready again, as every move is on a new step or when its action lands (Tutorial._refresh).
func ready() -> void:
	var k: Kin = m.player.kin
	if k and k.summon and not k.summon.out():
		k.summon.cd = 0.0

## The summon cooldown runs as fast as the rest here (Tutorial._quicken).
func quicken(extra: float) -> void:
	var k: Kin = m.player.kin
	if k and k.summon:
		k.summon.cd = maxf(0.0, k.summon.cd - extra)

## A rival Hunter a few steps ahead, already down: their Boki wisp breaks loose beside them (KinSteal).
func _spawn_decoy() -> void:
	var p := m.player
	var o := tu.outpost()
	var ang := 0.0 if o.is_empty() else atan2(float(o["pos"].z) - p.pos.z, float(o["pos"].x) - p.pos.x)
	var at := tu.spot(8.0, ang)      # (on the way out, so it is in view)
	if at == Vector3.INF:
		return
	var sp := String(Data.common_kin()[0])
	if sp == p.kin.species:
		sp = String(Data.common_kin()[1])
	var rec := Save.new_kin(sp, "", m.kin_seed("tut_decoy"))
	rec["name"] = Data.KIN[sp]["name"]
	decoy = m.make_hunter("tutd", 1, "medium", DECOY_NAME, "idle", rec, at, {"weapon": "?"})
	decoy.inp["move"] = Vector2.ZERO
	dk = decoy.kin
	m.knock(decoy, null, {})
