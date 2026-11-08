class_name DemoQuick
extends RefCounted
## Settings > Demo > Quick start (or `--demo=<id>`): one click into a scene made for filming, with no
## tutorial in the way. Each plays on a made-up save held in memory and never written; the real save
## comes back when the title screen opens (restore).
##   expedition  a full lobby of bots in the showcase Hunters, you as Kael with a bot squadmate
##   farm        a farm at work: evolved Boki, the work buildings up, every isle bridged
##   hatch       the creator, then the eggs and the hatch, as a new game plays them

const IDS := ["expedition", "farm", "hatch"]
const NAMES := ["Expedition (busy)", "Farm (grown)", "Hatch"]
## The Hunters with authored ability effects (content/vfx) plus Vex: the ones that read best on camera.
const SHOWCASE := ["juggernaut", "archer", "rimewright", "tender", "ashwick", "gunslinger"]
const YOU := "juggernaut"          # Kael: your Hunter in the expedition
const MATE := "archer"             # Lace: your squadmate, who leads the drop (Match._demo_drop)
const FARM_LEVEL := 13             # Boki level on the grown farm: three forms each (Evo, a form every 4 levels)

static var _real := {}             # the real save while a made-up one plays (empty when none is held)
static var _real_no_write := false

## The quick start a `--demo=<id>` launch asks for, or "".
static func arg(args: Array) -> String:
	for a in args:
		if String(a).begins_with("--demo=") and String(a).substr(7) in IDS:
			return String(a).substr(7)
	return ""

static func start(id: String) -> void:
	match id:
		"expedition":
			_swap(grown_save())
			Game.goto("match", expedition_opts())
		"farm":
			_swap(grown_save())
			Game.goto("home")
		"hatch":
			_swap(hatch_save())
			Game.goto("hatch")

## Puts the real save back (the title screen calls this): a no-op unless a quick start holds it.
static func restore() -> void:
	if _real.is_empty():
		return
	Save.d = _real
	Save.no_write = _real_no_write
	_real = {}

static func _swap(d: Dictionary) -> void:
	if _real.is_empty():
		_real = Save.d
		_real_no_write = Save.no_write
	Save.no_write = true
	Save.d = d

## The Demo match (Match.demo_opts) with every seat filled by showcase Hunters, straight in (no lobby).
static func expedition_opts() -> Dictionary:
	var o := Match.demo_opts()
	o["arch"] = YOU; o["cls"] = Arch.weight(YOU); o["weapon"] = Arch.signature(YOU)
	o["bot_archs"] = SHOWCASE
	o["mates"] = [{"name": String(Names.BOT[0]), "arch": MATE}]
	return o

## HomeWork's farm at work, its Boki grown to FARM_LEVEL with the forms and parts that brings.
static func grown_save() -> Dictionary:
	var d := HomeWork.demo_save()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1109
	for r in d["roster"]:
		r["level"] = FARM_LEVEL
		Evo.simulate(r, rng)
	d["bridges"] = Data.ISLES.keys()
	d["buildings"] = Data.BUILDINGS.keys()
	d["name"] = "Hunter"
	d["look"] = Unmasked.default_look()
	return d

## A brand new game past the intro card: the creator opens first.
static func hatch_save() -> Dictionary:
	var d := Save.fresh()
	d["tutorial"]["intro"] = true
	return d
