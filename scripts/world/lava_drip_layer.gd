# 矿洞远处岩浆滴落. Node2D 挂 World, 每 2-5 秒从屏幕顶部远岩壁随机位置
# 生成一个橙色光点, 向下匀加速掉到屏幕下方消失. 常驻 5-15 个.
# modulate.a 由 ScenicDirector 控制 (地表 0 / 矿洞 1).
extends Node2D

const VIEWPORT_W := 1280.0
const VIEWPORT_H := 720.0
const MAX_DRIPS := 12
const SPAWN_INTERVAL_MIN := 1.5
const SPAWN_INTERVAL_MAX := 3.5
const GRAVITY := 380.0   # 匀加速

var _spawn_timer: float = 1.0
var _rng := RandomNumberGenerator.new()
var _drip_tex: ImageTexture = null


func _ready() -> void:
	_rng.randomize()
	z_index = -2
	_drip_tex = _make_drip_texture()
	modulate.a = 0.0  # 默认隐藏 (地表), 由 ScenicDirector 控制


func _process(delta: float) -> void:
	if modulate.a < 0.01:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = _rng.randf_range(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_MAX)
		if get_child_count() < MAX_DRIPS:
			_spawn_drip()
	# 更新现有滴
	for child in get_children():
		if not (child is Sprite2D):
			continue
		var sp: Sprite2D = child
		var vy: float = sp.get_meta("vy", 0.0)
		vy += GRAVITY * delta
		sp.position.y += vy * delta
		sp.set_meta("vy", vy)
		# 出屏幕底 → 销毁
		if sp.position.y > VIEWPORT_H + 20.0:
			sp.queue_free()


func _spawn_drip() -> void:
	var sp := Sprite2D.new()
	sp.texture = _drip_tex
	sp.centered = true
	sp.position = Vector2(_rng.randf_range(0.0, VIEWPORT_W), _rng.randf_range(-20.0, 30.0))
	sp.modulate = Color(1.0, 0.55, 0.20, 0.85)
	sp.set_meta("vy", _rng.randf_range(20.0, 60.0))
	add_child(sp)


# 5x5 像素橙色光点 (中心亮 + 周围软光)
static func _make_drip_texture() -> ImageTexture:
	var img := Image.create(7, 7, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(3, 3)
	for y in 7:
		for x in 7:
			var d: float = Vector2(x, y).distance_to(center)
			if d <= 1.5:
				img.set_pixel(x, y, Color(1.0, 0.95, 0.55, 1.0))  # 中心白热
			elif d <= 2.5:
				img.set_pixel(x, y, Color(1.0, 0.65, 0.20, 0.95))  # 中圈橙
			elif d <= 3.5:
				img.set_pixel(x, y, Color(1.0, 0.45, 0.10, 0.55))  # 外圈柔光
	return ImageTexture.create_from_image(img)


# 测试用
func drip_count() -> int:
	var n: int = 0
	for child in get_children():
		if child is Sprite2D:
			n += 1
	return n


func spawn_one_for_test() -> void:
	_spawn_drip()
