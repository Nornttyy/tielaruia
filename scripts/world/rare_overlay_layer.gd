# 彩虹 + 极光 共用 layer. CanvasLayer (固定屏幕), layer = -7 (在山前云后).
# 一对参数化预设: setup_rainbow(weather) / setup_aurora().
# 内部 cooldown/active/fadeout 状态机, 触发条件由 trigger predicate 决定.
extends CanvasLayer

const RareOverlayArt = preload("res://scripts/art/rare_overlay_art.gd")

const VIEWPORT_W := 1280.0
const VIEWPORT_H := 720.0
const FADE_IN := 2.0
const FADE_OUT := 2.0

@export var kind: String = "rainbow"

var _sprite: Sprite2D
var _state: String = "idle"   # idle / fading_in / active / fading_out
var _state_timer: float = 0.0
var _active_duration: float = 30.0
var _cooldown_sec: float = 300.0
var _cooldown_timer: float = 0.0
var _check_timer: float = 0.0
var _check_interval: float = 60.0
var _trigger_chance: float = 0.2
var _need_night: bool = false  # 极光只在夜里出
var _was_rainy: bool = false   # 雨停后触发彩虹
var _weather_ref: Node = null


func _ready() -> void:
	layer = -7
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.modulate.a = 0.0
	add_child(_sprite)
	# 按 @export kind 自动配置 (允许在 tscn 设 kind="rainbow"/"aurora")
	# 父节点找 Weather (兄弟节点)
	if _sprite.texture == null:
		match kind:
			"rainbow":
				var w: Node = get_parent().get_node_or_null("Weather") if get_parent() != null else null
				setup_rainbow(w)
			"aurora":
				setup_aurora()


# 接 ScenicDirector 的 set_layer_alpha 接口 — RareOverlay 用自身渐入渐出, 不被 SD 直接控
func set_layer_alpha(_a: float) -> void:
	# 矿洞里 RareOverlay 应不可见, 通过隐藏 _sprite
	if _sprite != null:
		if _a < 0.05 and _sprite.modulate.a > 0.0:
			_sprite.modulate.a = 0.0
			_state = "idle"


func setup_rainbow(weather: Node = null) -> void:
	kind = "rainbow"
	_sprite.texture = RareOverlayArt.rainbow(800, 400)
	# 居中放屏幕下半部
	_sprite.position = Vector2(VIEWPORT_W * 0.5 - 400, VIEWPORT_H * 0.45)
	_active_duration = 30.0
	_cooldown_sec = 180.0
	_weather_ref = weather
	if weather != null and weather.has_signal("weather_changed"):
		weather.weather_changed.connect(_on_weather_changed)


func setup_aurora() -> void:
	kind = "aurora"
	_sprite.texture = RareOverlayArt.aurora(int(VIEWPORT_W), 300)
	_sprite.position = Vector2(0, 60)
	_active_duration = 60.0
	_cooldown_sec = 240.0
	_check_interval = 60.0
	_trigger_chance = 0.25
	_need_night = true


func _on_weather_changed(state: String) -> void:
	if kind != "rainbow":
		return
	if _was_rainy and state == "clear":
		_try_activate()
	_was_rainy = (state == "rainy")


func _process(delta: float) -> void:
	_state_timer -= delta
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
	# 极光按计时检查
	if kind == "aurora" and _state == "idle":
		_check_timer -= delta
		if _check_timer <= 0.0:
			_check_timer = _check_interval
			if _need_night and TimeOfDay.is_night():
				if randf() < _trigger_chance:
					_try_activate()
	# 状态机
	match _state:
		"fading_in":
			var t: float = 1.0 - _state_timer / FADE_IN
			_sprite.modulate.a = clamp(t, 0.0, 1.0)
			if _state_timer <= 0.0:
				_state = "active"
				_state_timer = _active_duration
				_sprite.modulate.a = 1.0
		"active":
			if _state_timer <= 0.0:
				_state = "fading_out"
				_state_timer = FADE_OUT
		"fading_out":
			var t2: float = _state_timer / FADE_OUT
			_sprite.modulate.a = clamp(t2, 0.0, 1.0)
			if _state_timer <= 0.0:
				_state = "idle"
				_sprite.modulate.a = 0.0
				_cooldown_timer = _cooldown_sec


func _try_activate() -> void:
	if _state != "idle" or _cooldown_timer > 0.0:
		return
	_state = "fading_in"
	_state_timer = FADE_IN
	_sprite.modulate.a = 0.0


# 测试用
func is_active() -> bool:
	return _state != "idle"


func force_activate() -> void:
	_try_activate()
