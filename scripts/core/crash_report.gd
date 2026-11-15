extends Node
## Starts Sentry crash and error reporting (docs/SENTRY.md) as the first autoload, before the others load.
## Only exported builds carry a DSN: the release and itch workflows write it into project.godot just before they
## export. With no DSN, no addon (tools/sentry_addon.sh fetches it at export time) or a headless run (checks,
## the dedicated server) it stays off and sends nothing.

const DSN_SETTING := "sentry/options/dsn"
const RELEASE_PREFIX := "project-boki@"   # Sentry release names: "project-boki@<Net.VERSION>"
const NET := preload("res://scripts/core/net.gd")   # the Net autoload itself loads after this one
## `<game> -- --sentry-test-error` sends one error event, to see that a build reports (docs/SENTRY.md).
const TEST_ERROR_ARG := "--sentry-test-error"

func _init() -> void:
	var dsn := str(ProjectSettings.get_setting(DSN_SETTING, ""))
	if not should_start(dsn, DisplayServer.get_name(), Engine.has_singleton("SentrySDK")):
		return
	# The addon is optional (absent in checks and editor runs), so its singleton is looked up by name.
	Engine.get_singleton("SentrySDK").init(_configure)
	if TEST_ERROR_ARG in OS.get_cmdline_user_args():
		push_error("Sentry test error %s" % Time.get_datetime_string_from_system(true))

## True when Sentry may start: a DSN was baked in, a window exists, and the addon is installed.
static func should_start(dsn: String, display_server: String, has_sdk: bool) -> bool:
	return dsn != "" and display_server != "headless" and has_sdk

## The Sentry release name, from the game version (Net.VERSION, also the vX.Y.Z release tag).
static func release_name() -> String:
	return RELEASE_PREFIX + NET.VERSION

## "dev" for debug builds and editor runs, "release" for release exports.
static func environment_name() -> String:
	return "dev" if OS.is_debug_build() else "release"

func _configure(options: Object) -> void:
	options.release = release_name()
	options.environment = environment_name()
