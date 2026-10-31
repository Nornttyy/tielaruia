# 原版 Liquid_0 / Liquid_1 只跟随附近实际下落的水与岩浆。
extends Node
const Original = preload("res://scripts/audio/original_sfx.gd")
const AMBIENT_DB := -30.0
const SILENT_DB := -80.0
const RANGE := 420.0
const SOURCE_LIFETIME := 0.6
var _players: Dictionary = {}
var _sources: Dictionary = {}
var _targets: Dictionary = {"water": SILENT_DB, "lava": SILENT_DB}

func _ready() -> void:
	for kind in ["water", "lava"]:
		var variants := Original.streams("waterfall" if kind == "water" else "lavafall")
		if variants.is_empty(): continue
		# 使用副本配置循环，不能把共享的短音效资源改成永不结束。
		var stream := variants[0].duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(round(stream.get_length() * stream.mix_rate))
		var voice := AudioStreamPlayer.new()
		voice.stream = stream
		voice.volume_db = SILENT_DB
		add_child(voice)
		_players[kind] = voice

func note_flow(kind: String, world: Node, position: Vector2) -> void:
	if not _players.has(kind) or not is_instance_valid(world): return
	var listener := get_tree().get_first_node_in_group("player") as Node2D
	if listener == null or listener.global_position.distance_to(position) >= RANGE: return
	var cell := Vector2i(floori(position.x / 12.0), floori(position.y / 12.0))
	_sources[cell] = {"world": weakref(world), "kind": kind, "position": position, "ttl": SOURCE_LIFETIME}

func _process(delta: float) -> void:
	var listener := get_tree().get_first_node_in_group("player") as Node2D
	var nearest := {"water": RANGE, "lava": RANGE}
	for cell in _sources.keys():
		var source: Dictionary = _sources[cell]
		source.ttl -= delta
		var world: Node = source.world.get_ref()
		if source.ttl <= 0.0 or world == null or not world.is_inside_tree() or world.is_queued_for_deletion():
			_sources.erase(cell)
			continue
		if listener != null and not get_tree().paused:
			nearest[source.kind] = minf(nearest[source.kind], listener.global_position.distance_to(source.position))
	for kind in _players:
		var voice: AudioStreamPlayer = _players[kind]
		var gain: float = pow(maxf(0.0, 1.0 - nearest[kind] / RANGE), 2.0)
		_targets[kind] = maxf(SILENT_DB, AMBIENT_DB + linear_to_db(gain)) if gain > 0.001 else SILENT_DB
		if _targets[kind] > SILENT_DB and not voice.playing: voice.play()
		voice.volume_db = move_toward(voice.volume_db, _targets[kind], delta * 75.0)
		if voice.volume_db <= SILENT_DB: voice.stop()
