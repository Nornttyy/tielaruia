# 矿洞远景视差层. ParallaxBackground 含 3 个 ParallaxLayer (远岩壁/钟乳石/水晶).
# 远岩壁用 _shallow_alpha (浅石头层就显示);
# 钟乳石/水晶用 _deep_alpha (深石头层才显示).
# 两个 alpha 由 ScenicDirector 按玩家深度独立控制.
extends ParallaxBackground

const CaveBgArt = preload("res://scripts/art/cave_bg_art.gd")

const ROCKS_W := 1024
const ROCKS_H := 480
const STAL_W := 1024
const STAL_H := 200
const CRYSTAL_W := 1024
const CRYSTAL_H := 400

# 跟 mountains_layer 的 HORIZON_Y 同步: 矿洞背景从屏幕顶到底覆盖
const TOP_Y := 0

var _rock_sprites: Array = []       # 远岩壁 (浅层就显)
var _stalactite_sprites: Array = [] # 钟乳石 (深层才显)
var _crystal_sprites: Array = []    # 水晶 (深层才显, sin 闪烁)
var _shallow_alpha: float = 0.0     # 远岩壁 alpha (由 ScenicDirector 设)
var _deep_alpha: float = 0.0        # 钟乳石/水晶 alpha
var _time_accum: float = 0.0


func _ready() -> void:
	# 矿洞用 layer = -9 (在天空 -10 之上, 默认 0 之下)
	layer = -9
	# (撤掉 scroll_ignore_camera_zoom = true)
	# 远岩壁 (motion_scale 0.10)
	var rock_pl := _add_layer(0.10, CaveBgArt.rocks(ROCKS_W, ROCKS_H, 7), TOP_Y, ROCKS_W)
	_collect_sprites(rock_pl, _rock_sprites)
	# 钟乳石 (motion_scale 0.18, 顶部下垂)
	var stal_pl := _add_layer(0.18, CaveBgArt.stalactites(STAL_W, STAL_H, 14, 11), TOP_Y, STAL_W)
	_collect_sprites(stal_pl, _stalactite_sprites)
	# 水晶 (motion_scale 0.25), 数量 30 → 18 (perf)
	var crystal_pl := _add_layer(0.25, CaveBgArt.crystals(CRYSTAL_W, CRYSTAL_H, 18, 23), 80, CRYSTAL_W)
	_collect_sprites(crystal_pl, _crystal_sprites)
	# 初始 alpha=0, 由 ScenicDirector 切换
	_apply_alphas()


func _add_layer(motion_scale_x: float, tex: ImageTexture, y_pos: int, mirror_w: int) -> ParallaxLayer:
	var pl := ParallaxLayer.new()
	pl.motion_scale = Vector2(motion_scale_x, 0.0)
	pl.motion_mirroring = Vector2(mirror_w, 0)
	add_child(pl)
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.position = Vector2(0, y_pos)
	pl.add_child(sp)
	return pl


func _collect_sprites(parent: Node, into: Array) -> void:
	for child in parent.get_children():
		if child is Sprite2D:
			into.append(child)


func _process(delta: float) -> void:
	_time_accum += delta
	# 水晶层呼吸闪烁 (基础 alpha 来自 _deep_alpha)
	if _crystal_sprites.is_empty():
		return
	var twinkle: float = (sin(_time_accum * 2.0) + 1.0) * 0.5  # 0..1
	var crystal_alpha: float = (0.6 + twinkle * 0.4) * _deep_alpha
	for sp in _crystal_sprites:
		sp.modulate.a = crystal_alpha


# 单一 alpha 接口 (兼容老调用): 浅层 + 深层 都用这个 alpha
func set_layer_alpha(a: float) -> void:
	_shallow_alpha = clamp(a, 0.0, 1.0)
	_deep_alpha = _shallow_alpha
	_apply_alphas()


# 双 alpha 接口: 浅石头层 alpha (只显远岩壁) + 深石头层 alpha (加钟乳石/水晶)
func set_depth_alphas(shallow_a: float, deep_a: float) -> void:
	_shallow_alpha = clamp(shallow_a, 0.0, 1.0)
	_deep_alpha = clamp(deep_a, 0.0, 1.0)
	_apply_alphas()


func _apply_alphas() -> void:
	# 远岩壁: shallow_alpha
	for sp in _rock_sprites:
		sp.modulate.a = _shallow_alpha
	# 钟乳石: deep_alpha
	for sp in _stalactite_sprites:
		sp.modulate.a = _deep_alpha
	# 水晶 alpha 由 _process 跑 sin 闪烁, 这里不重置 (会被下一帧覆盖)


func current_alpha() -> float:
	return _shallow_alpha  # 老接口返浅层 alpha


func shallow_alpha() -> float:
	return _shallow_alpha


func deep_alpha() -> float:
	return _deep_alpha


# 测试用
func layer_count() -> int:
	var n: int = 0
	for child in get_children():
		if child is ParallaxLayer:
			n += 1
	return n
