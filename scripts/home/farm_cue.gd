class_name FarmCue
extends RefCounted
## The four sounds for a farm reaction (tools/gen_sfx_ui.py). Pick the one for what happened and play it
## with Sfx.play(FarmCue.X, ...); the bare "unlock" chime is left to real unlocks (--farm-sound-check).

const APPEAR := "farm_appear"    # a new thing shows up: an offer, a build, a Boki, an egg, a bridge
const BUY := "farm_buy"          # gems or goods change hands: a purchase, an upgrade, a sale, a ransom
const LEVEL := "farm_level"      # something grows a level or a stage: a Boki level, evolving, a bigger island
const GOAL := "farm_goal"        # a goal is done: a claim, a Hunter challenge, the tutorial
