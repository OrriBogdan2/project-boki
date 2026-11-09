class_name DeathRecap
extends Node
## The card you get when you are downed or out: who got you (a Hunter, in their squad colour), the ability
## that did it, the damage you took in the last WINDOW_S seconds by source, and, while a teammate is still
## up, a key (Settings.key_cap of CYCLE_ACTION) that cycles the camera between your living teammates.
## Each Hunter's recent hits are kept here, from CombatBus.hit_landed alone (the hit event already carries
## the attacker, so nothing is added to Net). Added as a child of the match (Match.start).

const WINDOW_S := 10.0            # s of damage the card adds up
const SHOWN_SOURCES := 3          # sources named on the damage line; the rest fold into "others"
const CYCLE_ACTION := "fire"      # the key that cycles the watched teammate (a dead Hunter has no use for it)
## A hit's tag -> the key of the Hunter's own ability in its archetype file (its name is the label).
const ABILITY_KEY := {"rmb": "rmb", "secondary": "rmb", "utility": "e", "e": "e", "ult": "x", "ultimate": "x", "x": "x", "dodge": "dash"}
## A hit's tag -> plain words, for hits that are not a named ability.
const TAG_WORDS := {"primary": "a weapon shot", "shot": "a weapon shot", "flame": "flames", "burn": "burning",
	"mob": "a monster", "fall": "a fall", "boom": "an explosion", "wall": "a wall slam", "hazard": "a hazard",
	"kin": "a Boki", "k1": "a Boki move", "k2": "a Boki move"}
const PANEL_W := 460.0            # px
const LINE_H := 22.0              # px between card lines
const INK := Color("e8eef5")
const MUTED := Color("aab4c2")

var m: Match
var _hits := {}                   # Hunter id -> [{t, who: String, hunter: Hunter or null, amt, how: String}]
var _hit_cb: Callable
var _watch: Hunter = null

func _init(match_node: Match) -> void:
	m = match_node
	name = "DeathRecap"

func _ready() -> void:
	_hit_cb = _on_hit
	CombatBus.hit_landed.connect(_hit_cb)

func _exit_tree() -> void:
	if CombatBus.hit_landed.is_connected(_hit_cb):
		CombatBus.hit_landed.disconnect(_hit_cb)

func _on_hit(attacker: Node, target: Node, amount: float, tags: Array) -> void:
	if not target is Hunter or amount <= 0.0:
		return
	var by := HunterFeats.credit_of(attacker)
	var rec := {"t": m.time, "amt": amount, "hunter": by, "who": _source(attacker, by, target), "how": _how(by, tags)}
	var list: Array = _hits.get(target.get_instance_id(), [])
	while not list.is_empty() and m.time - float(list[0]["t"]) > WINDOW_S:
		list.pop_front()
	list.append(rec)
	_hits[target.get_instance_id()] = list

## Who a hit's damage is counted under on the card.
func _source(attacker: Node, by: Hunter, target: Node) -> String:
	if by == target:
		return "yourself"
	if by:
		return by.pname
	if attacker is Blight:
		return "the Blight"
	return "a monster" if attacker else "the world"

## What did it: the Hunter's own ability name when the hit's tags name one, else plain words.
func _how(by: Hunter, tags: Array) -> String:
	for t in tags:
		if by and by.arch != "" and ABILITY_KEY.has(t):
			var ab = Arch.def(by.arch).get(ABILITY_KEY[t])
			if ab is Dictionary and String(ab.get("name", "")) != "":
				return String(ab["name"])
	for t in tags:
		if TAG_WORDS.has(t):
			return TAG_WORDS[t]
	return "an attack"

## The hits `h` took in the WINDOW_S seconds up to `until` (the match time, or the moment they went out).
func recent(h: Hunter, until: float) -> Array:
	return (_hits.get(h.get_instance_id(), []) as Array).filter(func(r): return until - float(r["t"]) <= WINDOW_S and float(r["t"]) <= until)

## "Rin 84, a monster 12": damage by source, biggest first.
static func by_source(hits: Array) -> String:
	var sums := {}
	for r in hits:
		sums[r["who"]] = float(sums.get(r["who"], 0.0)) + float(r["amt"])
	var names := sums.keys()
	names.sort_custom(func(a, b): return sums[a] > sums[b])
	var parts: Array = []
	var rest := 0.0
	for i in names.size():
		if i < SHOWN_SOURCES:
			parts.append("%s %d" % [names[i], roundi(sums[names[i]])])
		else:
			rest += sums[names[i]]
	if rest > 0.0:
		parts.append("others %d" % roundi(rest))
	return ", ".join(parts)

## The teammates the camera can follow while you are dead (empty while you are alive or gone).
func mates() -> Array:
	var p: Hunter = m.player
	if p == null or not p.out or p.gone or m.time - float(p.get_meta("died_at", m.time)) < 2.5:
		return []
	return m.hunters.filter(func(x): return x.team == p.team and x != p and not x.out and not x.extracted)

## The teammate the camera follows, or null. Follows the last one picked while they are still up.
func watched() -> Hunter:
	var list := mates()
	if list.is_empty():
		return null
	if not list.has(_watch):
		_watch = list[0]
	return _watch

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(CYCLE_ACTION) or event.is_echo():
		return
	var list := mates()
	if list.is_empty() or Overlay.is_open():
		return
	_watch = list[(maxi(0, list.find(watched())) + 1) % list.size()]
	get_viewport().set_input_as_handled()

## One short card centred on `at` (its top edge): who, how, the damage line, the camera key.
func draw(c: CanvasItem, at: Vector2, p: Hunter) -> void:
	var hits := recent(p, float(p.get_meta("died_at", m.time)) if p.out else m.time)
	var mate := watched()
	var lines := 1 + (0 if hits.is_empty() else 1) + (1 if mate else 0)
	var box := Rect2(at - Vector2(PANEL_W * 0.5, 0), Vector2(PANEL_W, 14.0 + lines * LINE_H))
	c.draw_style_box(HudStyle.box(Color(0.04, 0.05, 0.08, 0.82), 10, Color(0.5, 0.55, 0.65, 0.5), 1), box)
	var y := box.position.y + 24.0
	var verb := "Finished by " if p.out else "Downed by "
	if hits.is_empty():
		HudStyle.ctext(c, Vector2(at.x, y), "You were %s" % ("finished" if p.out else "downed"), 16, INK)
	else:
		_who_line(c, at.x, y, verb, hits.back() as Dictionary)
		HudStyle.ctext(c, Vector2(at.x, y + LINE_H), "Last %d s: %s" % [int(WINDOW_S), by_source(hits)], 14, MUTED)
	if mate:
		var next := "  (%s: next teammate)" % Settings.key_cap(CYCLE_ACTION) if mates().size() > 1 else ""
		HudStyle.ctext(c, Vector2(at.x, box.end.y - 10.0), "Watching %s%s" % [mate.pname, next], 14, INK)

## "Downed by Rin with Shadow Knife", the Hunter's name in their squad colour.
func _who_line(c: CanvasItem, cx: float, y: float, verb: String, last: Dictionary) -> void:
	var h: Hunter = last["hunter"]
	var segs := [[verb, INK], [str(last["who"]), SideColor.of(m, h) if h else INK], [" with %s" % last["how"], INK]]
	var w := 0.0
	for s in segs:
		w += TextCache.width(HudStyle.BIG, s[0], 16)
	var x := cx - w * 0.5
	for s in segs:
		HudStyle.text(c, Vector2(x, y), s[0], 16, s[1])
		x += TextCache.width(HudStyle.BIG, s[0], 16)
