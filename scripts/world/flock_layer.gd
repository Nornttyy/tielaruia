# 鸟群 / 蝠群 共用 layer. 间歇生成 V 字队形飞过屏幕.
# 不视差, 直接挂世界. modulate.a 由 ScenicDirector 控制 (地表/矿洞切换).
extends Node2D

const FlockArt = preload("res://scripts/art/flock_art.gd")

# 视口尺寸 (跟项目设置同步)
const VIEWPORT_W := 1280.0
const VIEWPORT_H := 720.0

@export var kind: String = "bird"  # "bird" or "bat"

var _spawn_interval_range: Vector2 = Vector2(15.0, 35.0)  # 几秒孵化一群
var _count_range: Vector2i = Vector2i(5, 9)
var _y_range: Vector2 = Vector2(VIEWPORT_H * 0.15, VIEWPORT_H * 0.35)
var _color: Color = Color(1, 1, 1, 0.95)
var _texture: ImageTexture = null
var _flock_scale: float = 1.0
var _spawn_timer: float = 4.0  # 启动 4s 后第一次刷
var _rng := RandomNumberGenerator.new()
var _camera: Camera2D = null  # 跟相机移动, 飞过屏幕


# 预设: 鸟
func setup_bird() -> void:
	kind = "bird"
	_spawn_interval_range = Vector2(20.0, 45.0)
	_count_range = Vector2i(5, 8)
	_y_range = Vector2(VIEWPORT_H * 0.10, VIEWPORT_H * 0.35)
	_color = Color(0.10, 0.10, 0.12, 0.95)
	_flock_scale = 1.0
	_texture = FlockArt.bird_silhouette()


# 预设: 蝠
func setup_bat() -> void:
	kind = "bat"
	_spawn_interval_range = Vector2(12.0, 25.0)
	_count_range = Vector2i(6, 12)
	_y_range = Vector2(VIEWPORT_H * 0.25, VIEWPORT_H * 0.65)
	_color = Color(0.06, 0.04, 0.10, 0.95)
	_flock_scale = 0.7
	_texture = FlockArt.bat_silhouette()


func _ready() -> void:
	_rng.randomize()
	# 按 @export kind 自动配置 (允许在 tscn 里设 kind="bat")
	if _texture == null:
		if kind == "bat":
			setup_bat()
		else:
			setup_bird()
	# z_index 不太大, 在远山之前 (远山是 ParallaxBg 不参与 z_index)
	z_index = -2


func _process(delta: float) -> void:
	if modulate.a < 0.01:
		# 矿洞里鸟 alpha=0, 不刷新
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = _rng.randf_range(_spawn_interval_range.x, _spawn_interval_range.y)
		_spawn_flock()


func _spawn_flock() -> void:
	var count: int = _rng.randi_range(_count_range.x, _count_range.y)
	# 50% 概率从左飞向右 (dir=1), 50% 从右飞向左 (dir=-1)
	var dir: int = 1 if _rng.randf() < 0.5 else -1
	var y_base: float = _rng.randf_range(_y_range.x, _y_range.y)
	var x_base: float = -50.0 if dir == 1 else VIEWPORT_W + 50.0
	var speed: float = _rng.randf_range(60.0, 110.0) * dir
	if kind == "bat":
		speed *= 1.4  # 蝠飞快
	for i in count:
		var bird := Sprite2D.new()
		bird.texture = _texture
		bird.scale = Vector2.ONE * _flock_scale * _rng.randf_range(0.9, 1.3)
		bird.modulate = _color
		# V 字队形: 每只稍微错位
		var offset_x: float = -float(i) * 18.0 * dir
		var offset_y: float = float(abs(i - count / 2)) * 6.0
		bird.position = Vector2(x_base + offset_x, y_base + offset_y)
		add_child(bird)
		bird.set_meta("speed", speed)
		bird.set_meta("flap_phase", _rng.randf() * TAU)


func _physics_process(delta: float) -> void:
	# 每个 sprite 向 X 方向移动, 加 sin 上下扑翼
	for child in get_children():
		if not (child is Sprite2D):
			continue
		var sp: Sprite2D = child
		var speed: float = sp.get_meta("speed", 0.0)
		var phase: float = sp.get_meta("flap_phase", 0.0)
		sp.position.x += speed * delta
		sp.position.y += sin(Time.get_ticks_msec() / 200.0 + phase) * 0.4  # 微抖
		# 飞出屏幕 ±100 px 就销毁
		if sp.position.x < -100.0 or sp.position.x > VIEWPORT_W + 100.0:
			sp.queue_free()


# 测试用
func flock_count() -> int:
	var n: int = 0
	for child in get_children():
		if child is Sprite2D:
			n += 1
	return n


func spawn_one_for_test() -> void:
	_spawn_flock()
