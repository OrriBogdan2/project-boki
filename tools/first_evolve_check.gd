extends RefCounted
## --first-evolve-check: the one-time beat the first time a Boki can evolve (FirstEvolveBeat). Which Boki
## count as ready (a due meter that has picked an end, a held Ink), then on a stand-in home: the marker over
## the Boki, the three lines in order, the card on its Growth tab; it never runs twice; skipping (a panel
## opens) ends it with no card; tips off keeps it quiet. Never touches the real save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("FIRSTEVO %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## Enough of Home for the beat: its Boki, the open panel, the message lane's host and the card.
class FakeHome extends RefCounted:
	var kins: Array = []
	var panel_open := ""
	var root_ui := Control.new()
	var kin_tab := "Care"
	var opened: Array = []
	func _open_kin(r: Dictionary) -> void:
		opened.append([String(r["name"]), kin_tab])
		panel_open = "kin"

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	Save.d = Save.fresh()
	Save.d["tutorial"]["day1_done"] = true
	Settings.v["tips"] = true
	_ready_rule()
	_beat()
	_skip_and_tips()
	print("FIRSTEVO DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _boki(species: String, level: int, nm: String) -> Dictionary:
	var rec := Save.new_kin("zapple", nm)
	rec["species"] = species
	rec["level"] = level
	for st in Care.STATS:
		rec["stats"][st] = 20
	for t in rec["traits"]:
		rec["traits"][t] = 0.5
	rec["lean"] = {}
	rec["path"] = []
	rec["stay"] = false
	return rec

## A Zapple at its line's level whose meter leans to a final with art.
func _ready_boki(nm: String) -> Dictionary:
	var r := _boki("zapple", EvoPath.level({"species": "zapple"}), nm)
	r["lean"] = {"fairy": Evo.LEAN_FULL}
	return r

func _ready_rule() -> void:
	var r := _ready_boki("Pim")
	var leads := EvoPath.due(r) and EvoPath.winner(r) >= 0
	ok(leads and FirstEvolveBeat.can_evolve(r), "a due Zapple whose meter leads: ready")
	r["level"] = EvoPath.level(r) - 1
	ok(not FirstEvolveBeat.can_evolve(r), "a level short: not yet")
	r["level"] = EvoPath.level(r)
	r["stay"] = true
	ok(not FirstEvolveBeat.can_evolve(r), "a worn Stayleaf: not ready")
	var even := _boki("sporcupine", 36, "Bur")
	ok(EvoPath.blocked(even) == "undecided" and not FirstEvolveBeat.can_evolve(even), "an undecided meter: not ready")
	ok(not FirstEvolveBeat.can_evolve(_boki("pebbit", 30, "Peb")), "a line that does not branch: never")
	var jar := _boki("jarmit", 1, "Jar")
	ok(not FirstEvolveBeat.can_evolve(jar), "Jarmit with no Ink: not ready")
	Goods.give("good:ink_storm")
	ok(FirstEvolveBeat.can_evolve(jar), "a held Storm Ink offers Stormit: ready")
	Goods.take("good:ink_storm")

func _home(recs: Array) -> FakeHome:
	var h := FakeHome.new()
	main.add_child(h.root_ui)
	for r in recs:
		var n := Node3D.new()
		main.add_child(n)
		h.kins.append({"rec": r, "node": n})
	return h

func _lines(h: FakeHome) -> Array:
	return Array(MsgLane.of(h.root_ui).texts())

func _beat() -> void:
	var idle := _boki("zapple", 3, "Nib")
	var h := _home([idle, _ready_boki("Pim")])
	var beat := FirstEvolveBeat.new(h)
	beat.tick(FirstEvolveBeat.SCAN_S)
	var node: Node3D = h.kins[1]["node"]
	var marked: bool = is_instance_valid(beat.marker) and beat.marker.get_parent() == node
	ok(marked and beat.rec["name"] == "Pim", "the beat starts on the ready Boki, with a marker over it")
	ok(FirstEvolveBeat.seen(), "it is marked seen as it starts")
	var want := ["Pim is ready to change.", "Pick what it grows into.", "It keeps its name and memories."]
	for i in want.size():
		beat.tick(FirstEvolveBeat.LINE_S)
		ok(_lines(h).slice(0, i + 1) == want.slice(0, i + 1), "line %d: '%s' (%s)" % [i + 1, want[i], _lines(h)])
	ok(h.opened.is_empty(), "no card before the last line has had its time")
	beat.tick(FirstEvolveBeat.LINE_S)
	ok(h.opened == [["Pim", "Growth"]], "then Pim's card opens on Growth, the Evolve prompt (%s)" % [h.opened])
	ok(beat.marker == null and beat.rec.is_empty(), "the marker goes with it")
	h.panel_open = ""
	var again := FirstEvolveBeat.new(h)
	for i in 5:
		again.tick(FirstEvolveBeat.SCAN_S)
	ok(again.rec.is_empty() and h.opened.size() == 1, "once per save: a second ready Boki gets no beat")

func _skip_and_tips() -> void:
	Save.d["tutorial"].erase("first_evolve")
	var h := _home([_ready_boki("Tok")])
	Settings.v["tips"] = false
	var quiet := FirstEvolveBeat.new(h)
	quiet.tick(FirstEvolveBeat.SCAN_S)
	ok(quiet.rec.is_empty() and not FirstEvolveBeat.seen(), "tips off: no beat, and it is not used up")
	Settings.v["tips"] = true
	var beat := FirstEvolveBeat.new(h)
	beat.tick(FirstEvolveBeat.SCAN_S)
	beat.tick(FirstEvolveBeat.LINE_S)
	h.panel_open = "menu"
	beat.tick(0.1)
	ok(beat.rec.is_empty() and beat.marker == null, "a panel opening skips it: marker gone")
	h.panel_open = ""
	for i in 5:
		beat.tick(FirstEvolveBeat.LINE_S)
	var one_line := _lines(h) == ["Tok is ready to change."]
	ok(h.opened.is_empty() and one_line, "skipped: no more lines, no card (%s)" % [_lines(h)])
	ok(FirstEvolveBeat.seen(), "skipped counts as seen: it never comes back")
