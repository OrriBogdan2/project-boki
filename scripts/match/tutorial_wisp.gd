class_name TutorialWisp
extends RefCounted
## The tutorial's Boki-wisp beats around main's TutorialSummon (DECISIONS 2026-11-09 "Soul-linked Boki",
## docs/specs/TUTORIAL_WISP.md). Only when this match's Boki ride as wisps (KinWisp.mode); then gkey (the walking
## Boki's step) is skipped. Two steps, four beats; the summon and pack steps between them are TutorialSummon's:
##   wisp   - it rides with you as a wisp (1), and its carry passive is yours (2: the detail line names it)
##   steal  - a downed decoy Hunter (a round wisp) beside its Boki wisp (a critter outline) (3); its wisp broke
##            loose: hold interact to steal it and carry it out (4)
## Every beat has a fallback, so nothing strands: the wisp step ends by itself and the loose wisp comes to you
## after FLOAT_T. Nothing is lost: stolen wisps go home at match end (KinSteal.match_end) and the decoy is the
## tutorial's own.
## The steps, words and fallbacks: content/rules/tutorial.json.

const STEPS := ["wisp", "steal"]
const WISP_T := 3.0       # s the wisp step stays up
const OUTLINE_T := 3.0    # s the outline line shows before the grab line (sooner beside the wisp, banner settled)
const NEAR_M := 4.0       # m from the loose wisp that brings the grab line
const FLOAT_T := 14.0     # s before the loose wisp comes to you by itself
const DECOY_NAME := "Rival"

var tu: Tutorial
var m: Match
var decoy: Hunter = null  # the steal step's downed Hunter
var dk: Kin = null        # and its Boki wisp

func _init(tutorial: Tutorial, match_node: Match) -> void:
	tu = tutorial
	m = match_node

## Do this player's Boki ride as wisps here?
func on() -> bool:
	var k: Kin = m.player.kin
	return k != null and k.summon != null and KinWisp.mode(m)

func enter(sid: String) -> void:
	if sid == "steal":
		_spawn_decoy()

## The step's test, run every frame (with its fallback).
func done(sid: String, dt: float) -> bool:
	match sid:
		"wisp": return tu.t >= WISP_T
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
