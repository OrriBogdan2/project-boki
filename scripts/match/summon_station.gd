class_name SummonStation
extends RefCounted
## The Training Area's Boki summon pad (DECISIONS 2026-11-09, Boki wisps). Stand on it for a short card: the
## round-vs-critter rule, the Summon key (live key cap) and the pad's Boki, out of its wisp for its species'
## window and then resting for its cooldown (KinSummon, content/rules/boki_summon.json). Interact on the pad
## brings the next of three practice Bokis, each with its own window. It rides as a wisp here even with the
## wisp setting off, and the range's dummies are the targets. The guardian summon (a downed Hunter's Boki
## bursting out on its own) is not on this base, so the pad has no go-down step.

const RULES_PATH := "res://content/rules/summon_station.json"
const NAME := "Summon pad"    # the goal line's dummy name (station_goals.json "who")
const CARD_LIFT := 3.0         # m above the pad
const COL_PAD := Color("9ad8ff")
static var rules: Dictionary = _load()

var a: Arena
var pad: Vector3
var card: Label3D
var _was_out := false          # its Boki was out last tick (a burst ticks the goal once)
var _line := ""                # the card's last text (it is only rewritten when it changes)

static func _load() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	assert(parsed is Dictionary, "%s did not parse" % RULES_PATH)
	return parsed

func _init(arena: Arena) -> void:
	a = arena
	pad = a._arena_point(Vector3(rules["at"][0], 0, rules["at"][1]))
	var disc := MeshInstance3D.new()
	disc.mesh = Models.flat_quad(2.0 * float(rules["r"]))
	disc.material_override = Models.ring_mat(COL_PAD, 0.12)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.position = pad + Vector3(0, 0.05, 0)
	a.m.add_child(disc)
	card = Label3D.new()
	card.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	card.font = UI.big
	card.font_size = 30
	card.outline_size = 10
	card.pixel_size = 0.0075
	card.modulate = Color("ffe9b8")
	card.position = pad + Vector3(0, CARD_LIFT, 0)
	card.visible = false
	a.m.add_child(card)

func on_pad() -> bool:
	var P: Hunter = a.m.player
	return not P.downed and P.flat_dist(pad) < float(rules["r"])

## Interact on the pad: the next practice Boki, as a wisp with its summon ready.
func cycle() -> void:
	var ids: Array = rules["species"]
	var k: Kin = a.m.player.kin
	var at := ids.find(String(k.species)) if k and not k.dead else -1
	a.set_kin(String(ids[(at + 1) % ids.size()]))
	KinWisp.set_wisp(a.m.player.kin, true)

func tick() -> void:
	var k: Kin = a.m.player.kin
	var out := k != null and k.summon != null and k.summon.left > 0.0 and on_pad()
	if out and not _was_out:
		a.goals.hit(NAME.to_upper(), "summons")
	_was_out = out
	var here := on_pad()
	card.visible = here
	if not here:
		return
	var text := _text()
	if text != _line:
		_line = text
		card.text = text

## "name: window, cooldown" for a species, the card's data line.
static func times_line(sp: String) -> String:
	var t := KinSummon.times(KinLib.kin(sp))
	return "%s: out %d s, rests %d s" % [Data.KIN[sp]["name"], int(t.x), int(t.y)]

func _text() -> String:
	var k: Kin = a.m.player.kin
	var head := "SUMMON PAD\nYour Boki rides with you as a little critter-shaped glow;\n"
	head += "a Hunter's downed wisp is round. Round = Hunter, critter = Boki.\n"
	if k == null or k.dead or k.summon == null or not (rules["species"] as Array).has(String(k.species)):
		return head + "%s  ·  bring a practice Boki" % Settings.key_cap("interact")
	var s := k.summon
	var now := "ready: press %s" % Settings.key_cap("summon")
	if s.left > 0.0:
		now = "out: %d s left  ·  %s sends it back" % [ceili(s.left), Settings.key_cap("summon")]
	elif s.out():
		now = "shrinking back"
	elif s.cd > 0.0:
		now = "resting: %d s" % ceili(s.cd)
	var next := Settings.key_cap("interact")
	return "%s%s\n%s\n%s  ·  next practice Boki" % [head, times_line(String(k.species)), now, next]
