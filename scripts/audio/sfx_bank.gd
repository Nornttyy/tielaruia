# 原版短音效播放器。只读取核对过的 WAV，不再在启动时合成占位音。
extends Node

const OriginalSfx = preload("res://scripts/audio/original_sfx.gd")
const POOL_SIZE := 16
const GLOBAL_ATTEN_DB := -4.0
signal sound_played(event: String, source: String)
var _original_events: Dictionary = {}
var _sfx: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _cooldowns: Dictionary = {}
var _voice_cursor := 0

func _ready() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_build_all()

func _process(delta: float) -> void:
	for event in _cooldowns.keys():
		_cooldowns[event] = maxf(0.0, _cooldowns[event] - delta)

func has_sound(event: String) -> bool:
	return _sfx.has(event)

func play(event: String, _legacy_pitch_variation: float = 0.05, volume_db: float = 0.0) -> void:
	var variants: Array = _sfx.get(event, [])
	if variants.is_empty() or _cooldowns.get(event, 0.0) > 0.0: return
	var stream: AudioStreamWAV = variants.pick_random()
	var voice: AudioStreamPlayer = null
	for player in _players:
		if not player.playing:
			voice = player
			break
	# 密集战斗时替换一个旧声部，玩家死亡等新事件不能被静默丢弃。
	if voice == null:
		voice = _players[_voice_cursor % POOL_SIZE]
		_voice_cursor += 1
		voice.stop()
	voice.stream = stream
	var spread: float = OriginalSfx.PITCH_SPREAD.get(event, 0.0)
	var pitch := randf_range(-spread * 0.5, spread * 0.5)
	if event == "bird": pitch = randf_range(-0.7, 0.26)
	voice.pitch_scale = pow(2.0, pitch)
	# 主音量已在 Master 总线应用，不要在这里再乘一次。
	voice.volume_db = volume_db + GLOBAL_ATTEN_DB + float(OriginalSfx.VOLUME_DB.get(event, 0.0))
	voice.play()
	_cooldowns[event] = float(OriginalSfx.MIN_INTERVAL.get(event, 0.0))
	sound_played.emit(event, stream.resource_path)

func play_at(event: String, world_pos: Vector2, max_dist: float = 240.0,
		pitch_variation: float = 0.05) -> void:
	var listener := get_tree().get_first_node_in_group("player") as Node2D
	if listener == null or max_dist <= 0.0: return
	var distance := listener.global_position.distance_to(world_pos)
	if distance >= max_dist: return
	var factor := pow(1.0 - distance / max_dist, 2.0)
	play(event, pitch_variation, linear_to_db(maxf(factor, 0.001)))

func play_tile_hit(tile_id: int) -> void:
	play(OriginalSfx.tile_sound(tile_id))

func play_creature(kind: String, position: Vector2, died: bool) -> void:
	play_at(OriginalSfx.creature_event(kind, died), position, 240.0)

func _build_all() -> void:
	_sfx.clear()
	_original_events.clear()
	for event in OriginalSfx.EVENTS:
		var variants := OriginalSfx.streams(event)
		if variants.size() != OriginalSfx.EVENTS[event].size():
			push_error("缺少原版音效文件：" + event)
		if not variants.is_empty():
			_sfx[event] = variants
			_original_events[event] = true
