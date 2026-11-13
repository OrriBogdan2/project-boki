extends RefCounted
## --tutorial-check[=<arch>]: the match tutorial works for any first Relic (gunslinger = Vex, archer = Lace,
## juggernaut = Kael). The Hunter is forced by the param, so it never waits for the pick screen.
## Each run plays the whole course with the driver and asserts: every line names this kit's ability and
## key, no banner talks about ammo or a rifle, the E step (kin) waits for E, the shoot step takes the kit's own
## attack (Lace's draw and release, Kael's melee combo), the dummies stand where the kit can reach them,
## and the course ends at the lift.

var bad := 0
var arch := "gunslinger"

## Words no kit-neutral line may use: not every first Relic has a rifle or ammo.
const KIT_WORDS := ["ammo", "reload", "rifle", "bullet", "magazine"]
const FOE_STEPS := ["sec", "shoot", "gkey", "kin", "hook", "ult"]
const MAX_RUN_T := 900.0       # s of game time before the course counts as stuck
const IDLE_E_T := 3.0          # s the E step must keep waiting while E is not pressed
const REACH_FLAT := 12.0       # m: a dummy farther than this on foot is out of reach of any kit

func ok(cond: bool, what: String) -> void:
	print("TUTCHECK %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tutorial-check="): arch = a.substr(17)
	Save.no_write = true
	var m := Match.new()
	main.add_child(m)
	m.start({"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "demo_kin": "cindle",
			"cls": Arch.weight(arch), "arch": arch, "weapon": Arch.signature(arch), "tut_test": true})
	m.set_process(false)
	ok(m.player.ak != null and m.player.ak.id == arch, "the Hunter is forced to %s" % arch)
	var tu: Tutorial = m.tut
	var seen := {}
	var last := -1
	var t := 0.0
	var idle_ok := true
	var reach := ""
	while t < MAX_RUN_T and not m.player.extracted:
		if tu.id() == "kin" and tu.t < IDLE_E_T:
			idle_ok = idle_ok and tu.got == 0
			_hold_fire(m)
		else:
			TutorialDrive.drive(m)
		m.step(Match.DT)
		t += Match.DT
		if tu.step != last:
			last = tu.step
			seen[tu.id()] = {"text": tu.text, "detail": tu.detail, "cap": tu.key_cap}
			if tu.id() in FOE_STEPS:
				reach += _unreachable(m, tu.id())      # (the step's dummies were just placed by its start)
	ok(m.player.extracted, "the course finishes (%d steps in %.0fs)" % [seen.size(), t])
	_words(m.player, seen)
	ok(idle_ok, "the E step waits for E (no progress in the first %.0fs without it)" % IDLE_E_T)
	ok(reach == "", "every dummy stands where this kit can reach it" + reach)
	print("TUTCHECK DONE %s, failures: %d" % [arch, bad])
	main.get_tree().quit(1 if bad > 0 else 0)

## Stands still and does nothing at the E step's start: any progress here would not be E.
func _hold_fire(m: Match) -> void:
	var p := m.player
	for k in ["fire", "sec", "sig", "dash", "jump", "throw", "interact"]:
		p.inp[k] = false
	p.inp["move"] = Vector2.ZERO

## " name@dist" for each live dummy off the player's island or too far to walk to.
func _unreachable(m: Match, sid: String) -> String:
	var out := ""
	var p := m.player
	for mb in m.mobs:
		if mb.dead:
			continue
		var off: bool = m.world.island_of(mb.pos.x, mb.pos.z) != m.world.island_of(p.pos.x, p.pos.z)
		if off or p.flat_dist(mb) > REACH_FLAT:
			out += " %s %s@%.1f" % [sid, mb.kind, p.flat_dist(mb)]
	return out

## The kit's lines: ability and key named, no rifle or ammo talk, no unfilled %tokens.
func _words(p: Hunter, seen: Dictionary) -> void:
	var all := ""
	var banners := ""
	for sid in seen:
		all += " " + String(seen[sid]["text"]) + " " + String(seen[sid]["detail"])
		banners += " " + String(seen[sid]["text"])
	ok(not RegEx.create_from_string("%[A-Za-z]").search(all), "no unfilled token in any line")
	var low := banners.to_lower()      # (a detail may quote the kit's own card: Vex does have a rifle)
	var hit := KIT_WORDS.filter(func(w): return low.contains(w))
	ok(hit.is_empty(), "no line assumes ammo or a rifle %s" % str(hit))
	var e_name := String(p.ak.e_def().get("name", ""))
	var s: Dictionary = seen.get("kin", {})
	var e_line := String(s.get("text", ""))
	ok(e_name != "" and e_line.contains(e_name), "the E line names %s ('%s')" % [e_name, e_line])
	ok(String(s.get("cap", "")) == Settings.key_cap("signature"), "and shows the E key (%s)" % s.get("cap", ""))
	var r_name := String(p.ak.rmb_def().get("name", ""))
	var u: Dictionary = seen.get("sec", {})
	var r_line := String(u.get("text", ""))
	ok(r_name != "" and r_line.contains(r_name), "the right-click line names %s ('%s')" % [r_name, r_line])
	ok(String(u.get("cap", "")) == Settings.key_cap("secondary"), "and shows its key (%s)" % u.get("cap", ""))
	var sh: Dictionary = seen.get("shoot", {})
	var melee: bool = p.wpn.get("melee", false)
	var want := "Hold to draw" if p.wpn.has("draw") else "Now shoot"
	if melee:
		want = "Step in and swing"
	ok(String(sh.get("text", "")).begins_with(want), "the attack line fits the weapon ('%s')" % sh.get("text", ""))
	ok(String(sh.get("cap", "")) == Settings.key_cap("fire"), "and shows the attack key (%s)" % sh.get("cap", ""))
