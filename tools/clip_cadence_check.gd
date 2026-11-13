extends RefCounted
## --clip-cadence-check: a warden clip must fit the kit's cadence. Per Hunter and move listed in
## content/rules/clip_cadence.json: the clip as played (content/rules/warden_anim/<art>.json "scale" speeds it up, "cut"
## ends it early; a "hold_from" move loops and is exempt) lasts no longer than the move's cadence (else it restarts
## mid-swing or pops into the next move), and its strike (the frame its hand moves fastest in the .glb) lands no more
## than the slack after the kit's hit time. Prints the table. Never touches the save.

const TABLE := "res://content/rules/clip_cadence.json"
const DT := 1.0 / 60.0

var bad := 0
var table: Dictionary
var holder: Node3D

func ok(cond: bool, what: String) -> void:
	if not cond:
		print("CADENCE FAIL ", what)
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	table = JSON.parse_string(FileAccess.get_file_as_string(TABLE))
	holder = Node3D.new()
	main.add_child(holder)
	print("CADENCE art/move: clip s, played s (scale/cut), cadence s, strike s (played), hit s")
	var rows := 0
	for id in Arch.ids():
		var art_name := WardenGlb.art(String(id))
		if table.has(art_name):
			rows += await _hero(String(id), art_name)
	ok(rows > 0, "the table covers at least one move")
	print("CLIP_CADENCE_DONE, moves: %d, failures: %d" % [rows, bad])
	main.get_tree().quit(1 if bad > 0 else 0)

## A number, or "file:path" into content/ (a list is summed).
func _val(spec) -> float:
	if spec is Array:
		var sum := 0.0
		for s in spec:
			sum += _val(s)
		return sum
	if not spec is String:
		return float(spec)
	var at := (spec as String).split(":")
	var node = JSON.parse_string(FileAccess.get_file_as_string("res://content/" + at[0]))
	for key in at[1].split("."):
		node = node[key]
	return float(node)

func _hero(id: String, art_name: String) -> int:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	holder.add_child(m)
	var sync := m.get_node("Warden/Sync") as WardenGlb.Sync
	sync.set_process(false)
	var clips: WardenClips = sync.clips
	var moves: Dictionary = WardenClips.data(art_name)["kmoves"]
	var n := 0
	for km in table[art_name]:
		var spec: Dictionary = table[art_name][km]
		ok(moves.has(km), "%s: %s is not a move of warden_anim/%s.json" % [art_name, km, art_name])
		if not moves.has(km):
			continue
		var mv: Dictionary = moves[km]
		var length := clips.lib.get_animation(String(mv["clip"])).length
		var rate := float(mv.get("scale", 1.0))
		var cut := float(mv.get("cut", length))
		var played := minf(length, cut) / rate
		var cadence := _val(spec["cadence"])
		var hand := m.get_node(String(WardenGlb.BONES[spec.get("hand", "hand.R")])) as Node3D
		var strike := await _strike(sync, clips, hand, String(mv["clip"]), length) / rate
		var hit := float(spec.get("hit", -1.0))
		var slack := float(table["strike_slack"])
		var what := "%s/%s" % [art_name, km]
		ok(mv.has("hold_from") or played <= cadence + float(table["tolerance"]),
				"%s: the clip plays %.3f s, past its %.3f s cadence (scale or cut it in warden_anim)"
				% [what, played, cadence])
		ok(hit < 0.0 or strike <= hit + slack,
				"%s: the strike is at %.3f s, after the kit's hit at %.3f s (+%.2f)"
				% [what, strike, hit, slack])
		print("CADENCE %s: %.2f, %.2f (x%.2f cut %.2f), %.2f, %.2f, %.2f"
				% [what, length, played, rate, cut, cadence, strike, hit])
		n += 1
	m.free()
	return n

## When the hand moves fastest in the clip (seconds; the Hero's own frame, so a step forward does not count).
func _strike(sync: Node, clips: WardenClips, hand: Node3D, clip: String, length: float) -> float:
	var best := 0.0
	var at := 0.0
	var last := Vector3.INF
	var t := 0.0
	while t < length:
		clips.force = {"clip": clip, "t": minf(t, length - 0.001)}
		sync.call("_process", DT)
		await holder.get_tree().process_frame
		var p: Vector3 = (holder.get_child(0) as Node3D).to_local(hand.global_position)
		if last != Vector3.INF and p.distance_to(last) > best:
			best = p.distance_to(last)
			at = t
		last = p
		t += DT
	clips.force = {}
	return at
