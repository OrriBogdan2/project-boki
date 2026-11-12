extends RefCounted
## --steal-call-check: a stolen kill reads once to each squad (StealCall); other kills read nothing.
##   1. a contested warden: the loser's squad reads "<Hunter> stole the <monster>", the stealer's "Stolen: <monster>"
##   2. the player lands the last hit: exactly one line in the lane; their own kill says nothing
##   3. an ordinary monster nobody carried a key on says nothing even when contested
##   4. a contested key carrier shows the key mark
## With --shots-dir=<dir> (a real renderer) it also saves what each squad reads over the fight as a PNG.
## Never touches the save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("STEAL %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4, "no_drop": true, "arch": "thief",
		"cls": Arch.weight("thief"), "weapon": Arch.signature("thief")})
	m.set_process(false)
	await main.get_tree().process_frame
	var me: Hunter = m.player
	var rival: Hunter = m.hunters.filter(func(h): return h.team != me.team)[0]
	var lane: MsgLane = m.hud.msgs
	var warden := _fight(m, "warden", rival, 0.7, me)
	lane.clear()
	StealCall.on_dead(m, warden, me)
	var name_txt: String = warden.md["name"]
	var got := str(lane.texts())
	ok(got == str(["Stolen: %s" % name_txt]), "the stealer reads one Stolen line (%s)" % got)
	lane.clear()
	StealCall.on_dead(m, warden, rival)
	ok(_steal_lines(lane) == 0, "the squad that did the damage and got the kill reads nothing")
	var seen := StealCall.line(warden, me, rival.team, false)
	var want := "%s stole the %s" % [me.pname, name_txt.trim_prefix("The ")]
	ok(seen.get("text", "") == want, "the loser reads who stole it (%s)" % str(seen))
	ok(StealCall.line(warden, me, 99, false).is_empty(), "a third squad reads nothing")
	lane.clear()
	var own := _fight(m, "warden", me, 1.0, me)
	StealCall.on_dead(m, own, me)
	ok(_steal_lines(lane) == 0, "an uncontested boss kill reads nothing")
	lane.clear()
	var skit := _fight(m, "skitter", rival, 0.7, me)
	StealCall.on_dead(m, skit, me)
	ok(_steal_lines(lane) == 0, "an ordinary contested monster reads nothing")
	KeyCarry.mark(skit)
	var keyed := StealCall.line(skit, me, me.team, true)
	ok(keyed.get("icon", "") == "key", "a key carrier's line has the key mark")
	await _shots(m, warden)
	m.queue_free()
	print("STEAL DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## A `kind` monster `first` took `frac` of the health off and `last` hit once more (it does not die).
func _fight(m: Match, kind: String, first: Hunter, frac: float, last: Hunter) -> Mob:
	var mb: Mob = m.spawn_mob(kind, last.pos + Vector3(6, 0, 0))
	mb.hurt(mb.max_hp * frac, first)
	if last != first:
		mb.hurt(mb.max_hp * (1.0 - frac) * 0.5, last)
	return mb

## How many lines of the lane are steal callouts (a kill's own toasts may sit beside them).
func _steal_lines(lane: MsgLane) -> int:
	return lane.texts().filter(func(t: String): return t.begins_with("Stolen") or " stole the " in t).size()

## The loser's and the stealer's lines (the key mark on the first) as <dir>/loser.png and stealer.png.
func _shots(m: Match, warden: Mob) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	if dir == "":
		return
	DirAccess.make_dir_recursive_absolute(dir)
	if main.fade:
		await main.fade.reveal(0.01)
	var me: Hunter = m.player
	var rival: Hunter = m.hunters.filter(func(h): return h.team != me.team)[0]
	var views := {"loser": [rival.team, true], "stealer": [me.team, true]}
	for v in views:
		m.hud.msgs.clear()
		var s := StealCall.line(warden, me, views[v][0], views[v][1])
		m.hud.msgs.push(s["text"], s["col"], s["prio"], 6.0, s["icon"])
		for i in 20:
			m.hud.msgs._process(0.05)
			await main.get_tree().process_frame
		await RenderingServer.frame_post_draw
		main.get_viewport().get_texture().get_image().save_png(dir.path_join(v + ".png"))
