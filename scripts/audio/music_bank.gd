# CC0 循环配乐，按主菜单/白天/夜晚/地下/Boss 场景切换。
# 作者、许可与文件校验值见 assets/music/source-manifest.json。
extends Node
const BGM_FADE_SEC := 1.0
const BGM_VOLUME_DB := -30.0
const AMBIENT_VOLUME_DB := -30.0
const DB_SILENT := -80.0
const TRACK_NAMES := ["title", "day", "night", "cave", "boss"]
var _tracks: Dictionary = {}
var _original_ambience: Node
var _bgm_a: AudioStreamPlayer
var _bgm_b: AudioStreamPlayer
var _active_bgm: AudioStreamPlayer
var _current_track := ""
var _bgm_target_db := BGM_VOLUME_DB
var _fade_t := 0.0
var _fading := false
var _outgoing_start_db := BGM_VOLUME_DB

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for context in TRACK_NAMES:
		var stream := load("res://assets/music/" + context + ".ogg") as AudioStreamOggVorbis
		if stream != null:
			stream.loop = true
			_tracks[context] = stream
	_bgm_a = AudioStreamPlayer.new()
	_bgm_b = AudioStreamPlayer.new()
	add_child(_bgm_a)
	add_child(_bgm_b)
	_active_bgm = _bgm_a
	_original_ambience = preload("res://scripts/audio/original_ambience.gd").new()
	add_child(_original_ambience)
	_play_initial_track("title")

func _play_initial_track(context: String) -> void:
	if not _tracks.has(context): return
	_current_track = context
	_active_bgm.stream = _tracks[context]
	_active_bgm.volume_db = BGM_VOLUME_DB
	_active_bgm.play()

func set_context(context: String) -> void:
	if context == _current_track or not _tracks.has(context): return
	_current_track = context
	var incoming := _bgm_b if _active_bgm == _bgm_a else _bgm_a
	_outgoing_start_db = _active_bgm.volume_db
	incoming.stop()
	incoming.stream = _tracks[context]
	incoming.volume_db = DB_SILENT
	incoming.play()
	_active_bgm = incoming
	_bgm_target_db = BGM_VOLUME_DB
	_fade_t = 0.0
	_fading = true

func _process(delta: float) -> void:
	if not _fading: return
	_fade_t = minf(1.0, _fade_t + delta / BGM_FADE_SEC)
	var outgoing := _bgm_b if _active_bgm == _bgm_a else _bgm_a
	_active_bgm.volume_db = lerpf(DB_SILENT, _bgm_target_db, _fade_t)
	outgoing.volume_db = lerpf(_outgoing_start_db, DB_SILENT, _fade_t)
	if _fade_t >= 1.0:
		_fading = false
		outgoing.stop()

func note_liquid_flow(kind: String, world: Node, position: Vector2) -> void:
	if _original_ambience != null: _original_ambience.note_flow(kind, world, position)
