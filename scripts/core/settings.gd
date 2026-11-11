extends Node
## Global, persisted player settings. Autoloaded as `Settings`.

const SAVE_PATH := "user://settings.cfg"

## Fires once per session when the player has been at it this long. The paper
## that came with the brief lists losing track of time as one of the clearest
## warning signs, and setting your own stopping point as the first thing that
## helps - so the game says it out loud instead of hoping nobody notices.
signal play_reminder(minutes: int)

enum Quality { LOW, MEDIUM, HIGH }

var quality: int = Quality.MEDIUM
var target_fps: int = 60
var tilt_control: bool = false
var tilt_sensitivity: float = 1.0   # 0.5 .. 2.0
var flight_assist: bool = true
var haptics: bool = true
var rubber_banding: bool = true
var difficulty: int = 1  # 0 easy, 1 normal, 2 hard
var sound: bool = true
var music: bool = true
var volume: float = 0.8
var music_volume: float = 0.6
var mode: int = 0        # 0 race, 1 time trial
var seen_tutorial: bool = false
var trail_skin: int = 0
var track: int = 0
var records: Dictionary = {}   # track name -> {"lap": seconds, "medal": String}
var achievements: Dictionary = {}   # key -> true, see Progression
var won_maps: Array = []            # names of tracks won at least once
var play_seconds: float = 0.0       # lifetime, across sessions
var reminder_minutes: int = 45      # 0 turns the reminder off

var session_seconds := 0.0
var _reminded := 0

func _ready() -> void:
	load_settings()
	apply()

func _process(delta: float) -> void:
	session_seconds += delta
	play_seconds += delta
	if reminder_minutes <= 0:
		return
	var due := int(session_seconds / 60.0) / reminder_minutes
	if due > _reminded:
		_reminded = due
		play_reminder.emit(due * reminder_minutes)

func is_skin_unlocked(skin: int) -> bool:
	if skin <= 0:
		return true
	var rule := Progression.rule_for(skin)
	if rule.is_empty():
		return true
	return achievements.has(str(rule["key"]))

## Records what a finished race was worth and returns the skins it just
## unlocked, so the results card can name them.
func note_race(track_name: String, place: int, medal: String) -> PackedInt32Array:
	if place == 1 and not won_maps.has(track_name):
		won_maps.append(track_name)
	var fresh := PackedInt32Array()
	for key in Progression.keys_earned(place, medal, won_maps):
		if achievements.has(key):
			continue
		achievements[key] = true
		for skin in Progression.skins_for(PackedStringArray([key])):
			fresh.append(skin)
	save_settings()
	return fresh

func apply() -> void:
	Engine.max_fps = target_fps
	var scale := 0.6
	match quality:
		Quality.LOW:
			scale = 0.6
		Quality.MEDIUM:
			scale = 0.8
		Quality.HIGH:
			scale = 1.0
	get_tree().root.scaling_3d_scale = scale
	get_tree().root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	get_tree().root.msaa_3d = Viewport.MSAA_DISABLED
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		get_tree().root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA

## Returns 0 when the track has never been completed.
func best_lap_for(track_name: String) -> float:
	if not records.has(track_name):
		return 0.0
	return float(records[track_name].get("lap", 0.0))

func best_medal_for(track_name: String) -> String:
	if not records.has(track_name):
		return ""
	return str(records[track_name].get("medal", ""))

## Keeps the better of the two; the medal is kept even if a later lap is worse.
func record_lap(track_name: String, seconds: float, medal: String) -> bool:
	var previous := best_lap_for(track_name)
	var improved := previous <= 0.0 or seconds < previous
	var kept_medal := best_medal_for(track_name)
	if improved:
		records[track_name] = {"lap": seconds, "medal": medal if medal != "" else kept_medal}
		save_settings()
	elif medal != "" and kept_medal == "":
		records[track_name] = {"lap": previous, "medal": medal}
		save_settings()
	return improved

func vibrate(ms: int) -> void:
	if haptics and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "quality", quality)
	cfg.set_value("video", "target_fps", target_fps)
	cfg.set_value("input", "tilt_control", tilt_control)
	cfg.set_value("input", "tilt_sensitivity", tilt_sensitivity)
	cfg.set_value("input", "flight_assist", flight_assist)
	cfg.set_value("input", "haptics", haptics)
	cfg.set_value("game", "rubber_banding", rubber_banding)
	cfg.set_value("game", "difficulty", difficulty)
	cfg.set_value("game", "mode", mode)
	cfg.set_value("game", "seen_tutorial", seen_tutorial)
	cfg.set_value("game", "trail_skin", trail_skin)
	cfg.set_value("game", "track", track)
	cfg.set_value("audio", "sound", sound)
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("records", "data", records)
	cfg.set_value("progress", "achievements", achievements)
	cfg.set_value("progress", "won_maps", won_maps)
	cfg.set_value("progress", "play_seconds", play_seconds)
	cfg.set_value("progress", "reminder_minutes", reminder_minutes)
	cfg.save(SAVE_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	quality = cfg.get_value("video", "quality", quality)
	target_fps = cfg.get_value("video", "target_fps", target_fps)
	tilt_control = cfg.get_value("input", "tilt_control", tilt_control)
	tilt_sensitivity = cfg.get_value("input", "tilt_sensitivity", tilt_sensitivity)
	flight_assist = cfg.get_value("input", "flight_assist", flight_assist)
	haptics = cfg.get_value("input", "haptics", haptics)
	rubber_banding = cfg.get_value("game", "rubber_banding", rubber_banding)
	difficulty = cfg.get_value("game", "difficulty", difficulty)
	mode = cfg.get_value("game", "mode", mode)
	seen_tutorial = cfg.get_value("game", "seen_tutorial", seen_tutorial)
	trail_skin = cfg.get_value("game", "trail_skin", trail_skin)
	track = cfg.get_value("game", "track", track)
	sound = cfg.get_value("audio", "sound", sound)
	music = cfg.get_value("audio", "music", music)
	volume = cfg.get_value("audio", "volume", volume)
	music_volume = cfg.get_value("audio", "music_volume", music_volume)
	records = cfg.get_value("records", "data", {})
	achievements = cfg.get_value("progress", "achievements", {})
	won_maps = cfg.get_value("progress", "won_maps", [])
	play_seconds = cfg.get_value("progress", "play_seconds", 0.0)
	reminder_minutes = cfg.get_value("progress", "reminder_minutes", 45)
	# A save from before the skins had to be earned can name one that is not
	# unlocked yet; fall back to the stock trail rather than wearing it.
	if not is_skin_unlocked(trail_skin):
		trail_skin = 0
