extends "res://tools/displace_net_check.gd"
## --zone-net-check: a kit's ground zones show on the other games too (HeroVfxZone: the zone rides its move's
## "hvfx" message with its life). Two real games over the desktop relay, set up like --displace-net-check: the host
## casts each zone through its kit and asks the guest what its zone layer draws: the centre, radius and life left
## match the host's kit, a zone that follows a body rides it, and each is gone once its life ends. Gil's slime
## puddle, Meeko's seed field (under the guest's own hunter) and Hearthlight (on the host's), Motley's Nightwell,
## and Vex's X disc and burning patch (AimKit `all` telegraphs, Net "tele").
## --shots-dir=<dir> (GPU, jobq): the guest draws, and saves what it sees of each zone (zone_net_<case>.png,
## MANIFEST.txt). Lines: ZONENET ok|FAIL <what>.

const POS_TOL := 0.35  # m a zone's centre may differ between the games (a snapshot of travel)
const LEFT_TOL := 0.35  # s its life left may differ (the message's trip and a step)
const NEAR := Vector3(3.0, 0, 0)  # m from home: where the guest stands, in the seed's leash
const AIM := Vector3(6.0, 0, 0)  # m from home: where the host aims a placed zone
const GONE_S := 1.2  # s past its end a zone may still be on the guest (one beat plus its fade)

var shots_dir := ""
var lines: Array = []


func _init() -> void:
	tag = "ZONENET"
	guest_flag = "--zone-net-check=guest"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			shots_dir = a.substr(12)


func _start_guest() -> int:
	var args := "%s --dn-port=%d" % [guest_flag, port]
	if shots_dir != "":
		args += " --shots-dir=" + shots_dir
	return CheckChild.start(args, dir.path_join("guest.log"), shots_dir == "")


# ------------------------------------------------------------------ the host
func _host() -> void:
	var guest := await _host_up()
	if guest == null:
		return _finish()
	if shots_dir != "":
		DirAccess.make_dir_recursive_absolute(shots_dir)
	await _gil(guest)
	await _seed(guest)
	await _hearth(guest)
	await _well(guest)
	await _vex(guest)
	ok(HeroVfx.of(m).zones.live.is_empty(), "the caster's own game never draws its zones twice (its kit draws them)")
	if shots_dir != "":
		var f := FileAccess.open(shots_dir.path_join("MANIFEST.txt"), FileAccess.WRITE)
		for l in lines:
			f.store_line(l)
		f.close()
	_finish()


## The host plays `arch`, the guest's copy of it too, and the guest stands NEAR.
func _start(guest: Hunter, arch: String) -> void:
	_kit(arch)
	_aim(home + AIM)
	Net.lobby_emit("dn", {"c": "arch", "arch": arch})
	await _place(guest, home + NEAR)


func _gil(guest: Hunter) -> void:
	await _start(guest, "gil")
	var kit: GilKit = m.player.ak
	kit._shatter({"v": "slime", "at": home + AIM})
	await _run(0.5)
	var pd: Dictionary = kit.puddles[0]
	await _same("Gil's slime puddle", pd["at"], float(pd["r"]), float(pd["left"]))
	await _shot("gil_puddle", "Gil's slime puddle, cast on the host")
	await _run(float(pd["left"]) + 0.2)
	await _gone("Gil's slime puddle")


func _seed(guest: Hunter) -> void:
	await _start(guest, "tender")
	var kit: TenderKit = m.player.ak
	kit._stick(guest)
	await _run(0.8)
	var own := await _same("Meeko's seed field", Vector3.INF, kit.burst_radius(), -1.0)
	ok(
		_zone_at().distance_to(own) < POS_TOL,
		"Meeko's seed field: it rides the stuck player on their own game",
		"zone %s, player %s" % [_s(_zone_at() - home), _s(own - home)]
	)
	await _shot("meeko_seed", "Meeko's seed field under the guest, cast on the host")
	await _run(float(kit.rmb_def()["seed"]["build"]) + 0.5)
	ok(kit.burrs.is_empty(), "Meeko's seed field: it burst on the host")
	await _run(GONE_S)
	await _gone("Meeko's seed field")


func _hearth(guest: Hunter) -> void:
	await _start(guest, "tender")
	var kit: TenderKit = m.player.ak
	kit.cast_e()
	await _run(1.0)
	await _same("Meeko's Hearthlight", m.player.pos, kit.hearth_r(), -1.0)
	m.player.teleport(home + Vector3(0, 0, 2.0))
	await _run(0.6)
	await _same("Meeko's Hearthlight: it follows her", m.player.pos, kit.hearth_r(), -1.0)
	await _shot("meeko_hearth", "Meeko's Hearthlight on the host's hunter")
	await _run(float(kit.hearth.get("left", 0.0)) + 0.2)
	await _gone("Meeko's Hearthlight")


func _well(guest: Hunter) -> void:
	await _start(guest, "ostra")
	var kit: OstraKit = m.player.ak
	ok(kit.well.start(), "Motley's Nightwell is cast")
	await _run(float(kit.x_def()["tell"]) + 0.5)
	var w: OstraWell = kit.well
	await _same("Motley's Nightwell", w.center, w.radius, float(kit.x_def()["time"]) - w.phase_t)
	await _shot("motley_well", "Motley's Nightwell, cast on the host")
	await _run(float(kit.x_def()["time"]) - w.phase_t + 0.2)
	await _gone("Motley's Nightwell")


## Vex's X disc and burning patch are AimKit `all` telegraphs: they reach the guest as "tele" events.
func _vex(guest: Hunter) -> void:
	await _start(guest, "gunslinger")
	var kit: GunslingerKit = m.player.ak
	ok(kit.ult.cast(), "Vex's Cinderfall is cast")
	await _run(1.0)
	await _ask()
	ok(
		_tele().any(func(k: String) -> bool: return k.ends_with(":x1")),
		"Vex's X disc: up on the guest's game",
		str(_tele())
	)
	await _shot("vex_disc", "Vex's X countdown disc, cast on the host")
	await _run(float(kit.ult.data()["delay"]))
	await _ask()
	ok(
		_tele().any(func(k: String) -> bool: return k.ends_with(":xz1")),
		"Vex's burning patch: up on the guest's game",
		str(_tele())
	)
	await _shot("vex_patch", "Vex's burning patch, cast on the host")


## Asks the guest for its zones: one is drawn, at `at` (INF: anywhere), on radius `r`, with `left` s to go
## (< 0: any). Returns where the guest's own hunter is.
func _same(what: String, at: Vector3, r: float, left: float) -> Vector3:
	var own := await _ask()
	var zs := _zones()
	ok(zs.size() == 1, "%s: drawn on the guest's game" % what, "%d zone(s)" % zs.size())
	if zs.size() != 1:
		return own
	var z: Array = zs[0]
	var zat := Vector3(z[1], z[2], z[3])
	ok(
		at == Vector3.INF or Vector2(zat.x - at.x, zat.z - at.z).length() < POS_TOL,
		"%s: on the guest, where the host's kit has it" % what,
		"%s vs %s" % [_s(zat - home), _s(at - home)]
	)
	ok(absf(float(z[4]) - r) < 0.05, "%s: its radius (%.2f m)" % [what, r], "guest %.2f" % float(z[4]))
	ok(
		float(z[5]) > 0.0 and (left < 0.0 or absf(float(z[5]) - left) < LEFT_TOL),
		"%s: its life left" % what,
		"guest %.2f s, host %.2f s" % [float(z[5]), left]
	)
	return own


func _gone(what: String) -> void:
	await _ask()
	ok(_zones().is_empty(), "%s: gone on the guest's game once its life is up" % what, "%d left" % _zones().size())


func _zones() -> Array:
	return replies[0].get("zones", []) if not replies.is_empty() else []


func _tele() -> Array:
	return replies[0].get("tele", []) if not replies.is_empty() else []


func _zone_at() -> Vector3:
	var zs := _zones()
	return Vector3(zs[0][1], zs[0][2], zs[0][3]) if zs.size() == 1 else Vector3.INF


## With --shots-dir, the guest saves what it sees now.
func _shot(case: String, caption: String) -> void:
	if shots_dir == "":
		return
	replies.clear()
	Net.lobby_emit("dn", {"c": "shot", "file": "zone_net_%s.png" % case})
	await _reply()
	ok(bool(replies[0].get("saved", false)) if not replies.is_empty() else false, "%s: the guest's frame" % case)
	lines.append("zone_net|zone_net_%s.png|%s (seen on the guest's game)" % [case, caption])


# ------------------------------------------------------------------ the guest
func _guest() -> void:
	if shots_dir != "":
		RenderingServer.render_loop_enabled = true
		Save.d["tutorial"][KitDrill.SAVE_KEY] = true  # no first-time drill banner over the shots
	await super._guest()


func _on_msg(topic: String, data, from: String) -> void:
	if topic != "dn" or typeof(data) != TYPE_DICTIONARY or m == null:
		super._on_msg(topic, data, from)
		return
	match String(data.get("c", "")):
		"arch":
			for h in m.hunters:
				if h != m.player:
					h.reclass(Arch.weight(String(data["arch"])), String(data["arch"]))
		"shot":
			_save(String(data["file"]))
		_:
			super._on_msg(topic, data, from)


func _say() -> void:
	if m == null or m.player == null:
		return
	var zs := []
	for key: String in HeroVfx.of(m).zones.live:
		var z: Dictionary = HeroVfx.of(m).zones.live[key]
		var p: Vector3 = (z["node"] as Node3D).global_position
		zs.append([key, p.x, p.y, p.z, float(z["r"]), float(z["left"])])
	var me := m.player
	Net.lobby_emit("dn_r", {"pos": [me.pos.x, me.pos.y, me.pos.z], "zones": zs, "tele": AimKit.layer(m).entries.keys()})


func _save(file: String) -> void:
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	if m.hud:
		m.hud.visible = false
	m.cam.snap(home + NEAR)
	for h in m.hunters:
		h.render(DT, 1.0)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := main.get_viewport().get_texture().get_image()
	var saved := img != null and img.save_png(shots_dir.path_join(file)) == OK
	var me := m.player
	Net.lobby_emit("dn_r", {"pos": [me.pos.x, me.pos.y, me.pos.z], "saved": saved})
