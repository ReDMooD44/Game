extends Node
## Autoloaded as `Audio`. Owns the synthesised one-shots and a small pool of
## players, so the number of voices is capped no matter how much goes wrong.

const MAX_VOICES := 12

var _bank := {}
var _music := AudioStreamPlayer.new()
var _ducked := false
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _ready_done := false

func _ready() -> void:
	for i in MAX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_music.bus = "Master"
	add_child(_music)
	_bank = {
		"boom": Sfx.boom(),
		"ding_up": Sfx.ding(true),
		"ding_down": Sfx.ding(false),
		"scrape": Sfx.scrape(),
		"beep": Sfx.beep(false),
		"go": Sfx.beep(true),
		"fanfare": Sfx.fanfare(),
		"click": Sfx.click(),
	}
	_ready_done = true
	# Built after the one-shots so the first race does not wait on it.
	_music.stream = Sfx.music_loop()
	apply_volume()
	start_music()

func apply_volume() -> void:
	var db := -80.0 if not Settings.sound else linear_to_db(clampf(Settings.volume, 0.0, 1.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)
	if not _ready_done:
		return
	_apply_music_volume()
	if Settings.music and Settings.sound and Settings.music_volume > 0.001:
		start_music()
	else:
		_music.stop()

func _apply_music_volume() -> void:
	var v := clampf(Settings.music_volume, 0.0, 1.0)
	if v <= 0.001:
		_music.volume_db = -80.0
		return
	# -6 dB of headroom so the music never buries the engine.
	_music.volume_db = linear_to_db(v) - 6.0 + (-10.0 if _ducked else 0.0)

func start_music() -> void:
	if _ready_done and Settings.music and Settings.sound 			and Settings.music_volume > 0.001 and not _music.playing:
		_music.play()

## Ducked while a results card or menu is up, so the panel can be read.
func set_music_ducked(ducked: bool) -> void:
	_ducked = ducked
	_apply_music_volume()

func play(name: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not _ready_done or not _bank.has(name):
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _bank[name]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()
