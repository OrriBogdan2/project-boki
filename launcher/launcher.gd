extends Control
## Project Boki launcher: log in with Discord, keep the game up to date from GitHub Releases, play.
##
## Flow
##  1. Log in: opens Discord in the browser (implicit grant, scope "identify"). Discord sends the
##     browser back to http://127.0.0.1:53134/cb with the token in the URL fragment; a tiny page we
##     serve posts it to /tok. The token is kept in user://session.json until it expires.
##  2. Update: asks GitHub for the latest release, downloads ProjectBoki-<platform>.zip if the
##     installed version is older, unpacks it into user://game/<version>/.
##  3. Play: starts the game with `-- --server=<relay> --token=<discord token>`.
##
## Settings live in launcher_config.json next to this script (shipped in the build).

const CALLBACK_PORT := 53134
const CONFIG_PATH := "res://launcher_config.json"
const SESSION_PATH := "user://session.json"
const INSTALL_PATH := "user://installed.json"

var cfg := {
	"discord_client_id": "",
	"repo": "OrriBogdan2/project-boki",
	"server": "play.projectboki.com:7777",
	"asset_windows": "ProjectBoki-windows.zip",
	"asset_macos": "ProjectBoki-macos.zip",
	"asset_linux": "ProjectBoki-linux.zip",
}
var session := {}        # {token, expires, name}
var installed := {}      # {version, exe}
var latest := {}         # {version, url, size}

var title_l: Label
var who_l: Label
var status_l: Label
var bar: ProgressBar
var login_b: Button
var play_b: Button
var logout_b: Button

var tcp: TCPServer
var waiting_login := false
var busy := false

const BG := Color("0d0b14")
const PANEL := Color("181425")
const ACCENT := Color("8b6cf0")
const INK := Color("f2eefb")
const MUTED := Color("9a92b4")

# ------------------------------------------------------------------ setup
func _ready() -> void:
	_load_config()
	session = _read_json(SESSION_PATH)
	installed = _read_json(INSTALL_PATH)
	_build_ui()
	if _logged_in():
		_check_updates()
	else:
		_refresh()

func _load_config() -> void:
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if typeof(d) == TYPE_DICTIONARY:
			cfg.merge(d, true)

func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if typeof(d) == TYPE_DICTIONARY else {}

func _write_json(path: String, d: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 40; box.offset_right = -40; box.offset_top = 48; box.offset_bottom = -40
	box.add_theme_constant_override("separation", 16)
	add_child(box)
	var logo := TextureRect.new()
	logo.texture = load("res://icon.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(0, 200)
	box.add_child(logo)
	title_l = _label("Project Boki", 34, INK)
	box.add_child(title_l)
	who_l = _label("", 16, MUTED)
	box.add_child(who_l)
	var sp := Control.new(); sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(sp)
	status_l = _label("", 15, MUTED)
	status_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status_l)
	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 10)
	bar.show_percentage = false
	bar.visible = false
	var fill := StyleBoxFlat.new(); fill.bg_color = ACCENT; fill.set_corner_radius_all(5)
	var back := StyleBoxFlat.new(); back.bg_color = PANEL; back.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	box.add_child(bar)
	login_b = _button("Log in with Discord", _login)
	box.add_child(login_b)
	play_b = _button("Play", _play)
	box.add_child(play_b)
	logout_b = _button("Log out", _logout, true)
	box.add_child(logout_b)

func _label(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func _button(t: String, cb: Callable, quiet := false) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 30 if quiet else 52)
	b.add_theme_font_size_override("font_size", 14 if quiet else 20)
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0, 0, 0, 0) if quiet else ACCENT
	n.set_corner_radius_all(10)
	var h := n.duplicate(); h.bg_color = Color(1, 1, 1, 0.06) if quiet else ACCENT.lightened(0.12)
	var d := n.duplicate(); d.bg_color = Color(0, 0, 0, 0) if quiet else PANEL
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", MUTED if quiet else INK)
	b.add_theme_color_override("font_disabled_color", MUTED)
	b.pressed.connect(cb)
	return b

func _refresh() -> void:
	var li := _logged_in()
	if not _login_required():
		who_l.text = "Playtest"
	else:
		who_l.text = ("Logged in as %s" % session.get("name", "")) if li else "Closed playtest · Discord login required"
	login_b.visible = not li
	logout_b.visible = li and _login_required()
	play_b.visible = li
	var ready := installed.has("version") and FileAccess.file_exists(_exe_path())
	play_b.disabled = busy or not ready
	play_b.text = "Play" if ready else "Installing..."
	if not busy and li and ready and status_l.text == "":
		status_l.text = "Version %s" % installed["version"]

func _set_status(t: String) -> void:
	status_l.text = t

# ------------------------------------------------------------------ Discord login
func _login_required() -> bool:
	return String(cfg["discord_client_id"]) != ""

func _logged_in() -> bool:
	if not _login_required():
		return true
	return session.has("token") and float(session.get("expires", 0)) > Time.get_unix_time_from_system() + 60

func _login() -> void:
	if cfg["discord_client_id"] == "":
		_set_status("This launcher build has no Discord app set up yet.")
		return
	tcp = TCPServer.new()
	if tcp.listen(CALLBACK_PORT, "127.0.0.1") != OK:
		_set_status("Couldn't start the login helper (port %d busy). Close other launchers and try again." % CALLBACK_PORT)
		return
	waiting_login = true
	var url := "https://discord.com/oauth2/authorize?client_id=%s&response_type=token&scope=identify&prompt=none&redirect_uri=%s" % [
		cfg["discord_client_id"], ("http://127.0.0.1:%d/cb" % CALLBACK_PORT).uri_encode()]
	OS.shell_open(url)
	_set_status("Finish logging in in your browser...")

func _process(_dt: float) -> void:
	if waiting_login and tcp and tcp.is_connection_available():
		_handle_http(tcp.take_connection())

func _handle_http(c: StreamPeerTCP) -> void:
	var raw := ""
	for i in 50:
		c.poll()
		var n := c.get_available_bytes()
		if n > 0:
			raw += c.get_utf8_string(n)
			if raw.find("\r\n\r\n") >= 0: break
		OS.delay_msec(10)
	var line := raw.get_slice("\r\n", 0)
	var path := line.get_slice(" ", 1)
	var body := ""
	if path.begins_with("/cb"):
		# the token is in the fragment, which browsers don't send; this page forwards it to /tok
		body = "<html><body style='background:#0d0b14;color:#f2eefb;font-family:sans-serif;text-align:center;padding-top:80px'>Logging in...<script>var h=location.hash.substring(1);fetch('/tok?'+h).then(function(){document.body.innerHTML='You are logged in. You can close this tab and go back to the launcher.'});</script></body></html>"
	elif path.begins_with("/tok"):
		var q := path.get_slice("?", 1)
		var params := {}
		for kv in q.split("&"):
			params[kv.get_slice("=", 0)] = kv.get_slice("=", 1).uri_decode()
		if params.has("access_token"):
			session = {"token": params["access_token"], "expires": Time.get_unix_time_from_system() + float(params.get("expires_in", "604800"))}
			_on_logged_in()
		body = "ok"
	else:
		body = "Project Boki launcher"
	var resp := "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [body.to_utf8_buffer().size(), body]
	c.put_data(resp.to_utf8_buffer())
	c.disconnect_from_host()

func _on_logged_in() -> void:
	waiting_login = false
	if tcp: tcp.stop()
	var me = await _get_json("https://discord.com/api/v10/users/@me", ["Authorization: Bearer " + String(session["token"])])
	if typeof(me) == TYPE_DICTIONARY:
		session["name"] = me.get("global_name") if me.get("global_name") != null else me.get("username", "")
		session["uid"] = me.get("id", "")
	_write_json(SESSION_PATH, session)
	get_window().grab_focus()
	_check_updates()

func _logout() -> void:
	session = {}
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))
	_set_status("")
	_refresh()

# ------------------------------------------------------------------ updates
func _platform_asset() -> String:
	if OS.has_feature("windows"): return cfg["asset_windows"]
	if OS.has_feature("macos"): return cfg["asset_macos"]
	return cfg["asset_linux"]

func _check_updates() -> void:
	busy = true
	_refresh()
	_set_status("Checking for updates...")
	var rel = await _get_json("https://api.github.com/repos/%s/releases/latest" % cfg["repo"], ["Accept: application/vnd.github+json"])
	if typeof(rel) != TYPE_DICTIONARY or not rel.has("tag_name"):
		busy = false
		_set_status("Couldn't check for updates." + (" You can still play the installed version." if installed.has("version") else " Check your internet and reopen the launcher."))
		_refresh()
		return
	var want := _platform_asset()
	for a in rel.get("assets", []):
		if String(a.get("name", "")) == want:
			latest = {"version": String(rel["tag_name"]), "url": String(a["browser_download_url"]), "size": int(a.get("size", 0))}
	if latest.is_empty():
		busy = false
		_set_status("No build for this computer in the latest release yet.")
		_refresh()
		return
	if installed.get("version", "") == latest["version"] and FileAccess.file_exists(_exe_path()):
		busy = false
		_set_status("Up to date · version %s" % latest["version"])
		_refresh()
		return
	await _download_and_install()

func _download_and_install() -> void:
	var zip_path := "user://download.zip"
	var req := HTTPRequest.new()
	req.download_file = zip_path
	req.use_threads = true
	add_child(req)
	bar.visible = true
	bar.value = 0
	_set_status("Downloading version %s..." % latest["version"])
	var err := req.request(latest["url"])
	if err != OK:
		_fail("Download failed to start.")
		return
	var done := false
	var result = null
	req.request_completed.connect(func(r, code, _h, _b): result = [r, code]; done = true)
	while not done:
		await get_tree().create_timer(0.2).timeout
		var total := maxi(int(latest["size"]), req.get_body_size())
		if total > 0:
			bar.value = 100.0 * req.get_downloaded_bytes() / total
			_set_status("Downloading version %s... %d / %d MB" % [latest["version"], req.get_downloaded_bytes() / 1048576, total / 1048576])
	req.queue_free()
	if result[0] != HTTPRequest.RESULT_SUCCESS or int(result[1]) != 200:
		_fail("Download failed (%s). Try again in a minute." % str(result[1]))
		return
	_set_status("Installing...")
	await get_tree().process_frame
	var dest := "user://game/%s" % latest["version"]
	var exe := _unzip(zip_path, dest)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(zip_path))
	if exe == "":
		_fail("Couldn't unpack the game.")
		return
	var old: String = installed.get("version", "")
	installed = {"version": latest["version"], "exe": exe}
	_write_json(INSTALL_PATH, installed)
	if old != "" and old != latest["version"]:
		_remove_dir(ProjectSettings.globalize_path("user://game/%s" % old))
	bar.visible = false
	busy = false
	_set_status("Up to date · version %s" % latest["version"])
	_refresh()

func _fail(t: String) -> void:
	busy = false
	bar.visible = false
	_set_status(t)
	_refresh()

## Unpacks the zip and returns the game executable's path inside it ("" on failure).
func _unzip(zip_path: String, dest: String) -> String:
	var zr := ZIPReader.new()
	if zr.open(zip_path) != OK:
		return ""
	var root := ProjectSettings.globalize_path(dest)
	_remove_dir(root)
	DirAccess.make_dir_recursive_absolute(root)
	var exe := ""
	for f in zr.get_files():
		var out := root.path_join(f)
		if f.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(out)
			continue
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		var w := FileAccess.open(out, FileAccess.WRITE)
		if w == null:
			zr.close()
			return ""
		w.store_buffer(zr.read_file(f))
		w.close()
		if OS.has_feature("windows") and f.ends_with(".exe"):
			exe = f
		elif OS.has_feature("macos") and f.contains(".app/Contents/MacOS/") and not f.ends_with("/"):
			exe = f
		elif OS.has_feature("linux") and (f.ends_with(".x86_64") or f.ends_with(".sh")):
			exe = f
	zr.close()
	if exe != "" and not OS.has_feature("windows"):
		# zips don't keep the "can run" bit
		OS.execute("chmod", ["+x", root.path_join(exe)])
	return exe

func _remove_dir(abs_path: String) -> void:
	var d := DirAccess.open(abs_path)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	for sub in d.get_directories():
		_remove_dir(abs_path.path_join(sub))
	DirAccess.remove_absolute(abs_path)

func _exe_path() -> String:
	if not installed.has("exe"):
		return ""
	return ProjectSettings.globalize_path("user://game/%s" % installed["version"]).path_join(installed["exe"])

# ------------------------------------------------------------------ play
func _play() -> void:
	if not _logged_in():
		_set_status("Your login expired. Log in again.")
		session = {}
		_refresh()
		return
	var args := ["--", "--server=" + String(cfg["server"])]
	if session.has("token"):
		args.append("--token=" + String(session["token"]))
	var pid := OS.create_process(_exe_path(), args)
	if pid <= 0:
		_set_status("Couldn't start the game.")
		return
	_set_status("Have fun!")
	await get_tree().create_timer(2.0).timeout
	get_tree().quit()

# ------------------------------------------------------------------ http
func _get_json(url: String, headers: Array):
	var req := HTTPRequest.new()
	req.timeout = 15.0
	add_child(req)
	headers.append("User-Agent: ProjectBokiLauncher")
	if req.request(url, PackedStringArray(headers)) != OK:
		req.queue_free()
		return null
	var res = await req.request_completed
	req.queue_free()
	if int(res[1]) != 200:
		return null
	return JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
