extends RefCounted
## --sentry-check: crash reporting (docs/SENTRY.md) stays off where it must: no DSN is committed, the SDK never
## auto-starts, and CrashReport only starts with a DSN, a window and the addon all present (so checks and the
## headless server send nothing). The release name carries the game version; this run itself started nothing.

const CrashReport := preload("res://scripts/core/crash_report.gd")

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("SENTRYCHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	var cfg := ConfigFile.new()
	ok(cfg.load("res://project.godot") == OK, "project.godot reads")
	ok(str(cfg.get_value("sentry", "options/dsn", "")) == "", "no DSN committed")
	ok(cfg.get_value("sentry", "options/auto_init", true) == false, "the SDK does not auto-start")
	ok(CrashReport.should_start("https://k@o0.ingest.sentry.io/1", "Windows", true), "starts with DSN, window, addon")
	ok(not CrashReport.should_start("", "Windows", true), "off with no DSN")
	ok(not CrashReport.should_start("https://k@o0.ingest.sentry.io/1", "headless", true), "off when headless")
	ok(not CrashReport.should_start("https://k@o0.ingest.sentry.io/1", "Windows", false), "off with no addon")
	ok(CrashReport.release_name() == "project-boki@" + Net.VERSION, "release is project-boki@<Net.VERSION>")
	ok(CrashReport.environment_name() == ("dev" if OS.is_debug_build() else "release"), "environment by build")
	var sdk_live: bool = Engine.has_singleton("SentrySDK") and Engine.get_singleton("SentrySDK").is_enabled()
	ok(not sdk_live, "Sentry is not running in this check")
	print("SENTRYCHECK DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
