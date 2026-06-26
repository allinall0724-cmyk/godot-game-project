extends Node
## Thin CrazyGames SDK wrapper (registered as the `CrazyGames` autoload).
##
## The SDK <script> itself is injected into the page <head> by the Web export preset
## (see export_presets.cfg -> html/head_include). Every method here is a NO-OP off
## the web, so the desktop build is completely unaffected and you can call these
## freely from gameplay code.
##
## Implements the pieces CrazyGames asks for: SDK init, loading + gameplay events,
## and ad breaks that mute the game's audio while an ad plays.
##
## IMPORTANT: the JS calls below follow CrazyGames SDK **v3** (window.CrazyGames.SDK).
## Re-check the current SDK docs before submitting — the API can change.

var available := false
var _gameplay_active := false
var _mute_cb            # JS callback so ad code can mute/unmute our audio


func _ready() -> void:
	if not OS.has_feature("web"):
		return
	# Expose a JS-callable hook the ad callbacks use to mute/unmute Godot audio.
	_mute_cb = JavaScriptBridge.create_callback(_on_js_mute)
	var window = JavaScriptBridge.get_interface("window")
	window.godotSetMuted = _mute_cb
	# Kick off SDK init (async on the JS side; safe to fire and forget).
	JavaScriptBridge.eval("""
		(async () => {
			try {
				if (window.CrazyGames && window.CrazyGames.SDK) {
					await window.CrazyGames.SDK.init();
					window.__cgReady = true;
				}
			} catch (e) { console.error('CrazyGames SDK init failed', e); }
		})();
	""", true)
	available = true


# --- Loading + gameplay state (called from main.gd) -------------------------

func loading_start() -> void:
	_eval("window.CrazyGames.SDK.game.loadingStart();")

func loading_stop() -> void:
	_eval("window.CrazyGames.SDK.game.loadingStop();")

## Call when active play begins (after the player takes control).
func gameplay_start() -> void:
	if _gameplay_active:
		return
	_gameplay_active = true
	_eval("window.CrazyGames.SDK.game.gameplayStart();")

## Call when play pauses (menus, ads, game over).
func gameplay_stop() -> void:
	if not _gameplay_active:
		return
	_gameplay_active = false
	_eval("window.CrazyGames.SDK.game.gameplayStop();")

## Signal a positive beat (level up, boss kill) — CrazyGames may show a smile prompt.
func happytime() -> void:
	_eval("window.CrazyGames.SDK.game.happytime();")


# --- Ads --------------------------------------------------------------------

## A non-rewarded ad break (e.g. on respawn). Mutes audio while it plays.
func midgame_ad() -> void:
	if not available:
		return
	_set_muted(true)
	JavaScriptBridge.eval("""
		try {
			window.CrazyGames.SDK.ad.requestAd('midgame', {
				adStarted: () => window.godotSetMuted(true),
				adFinished: () => window.godotSetMuted(false),
				adError: () => window.godotSetMuted(false),
			});
		} catch (e) { console.error(e); window.godotSetMuted(false); }
	""")


# --- Internals --------------------------------------------------------------

func _eval(js: String) -> void:
	if not available:
		return
	JavaScriptBridge.eval("try { %s } catch (e) { console.error(e); }" % js)


func _on_js_mute(args: Array) -> void:
	var muted := bool(args[0]) if args.size() > 0 else false
	_set_muted(muted)


func _set_muted(muted: bool) -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_mute(bus, muted)
