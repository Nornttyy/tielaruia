# 矿洞远景视差层. ParallaxBackground 含 3 个 ParallaxLayer (远岩壁/钟乳石/水晶).
# 整体 alpha 由 ScenicDirector 按玩家深度控制 (地表 0 → 深矿洞 1).
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

var _all_sprites: Array = []     # 所有 layer 的 Sprite2D, 用于统一改 alpha
var _crystal_sprites: Array = []  # 水晶层 sprite, 用于闪烁
var _layer_alpha: float = 0.0      # 当前整体 alpha (由 ScenicDirector 设)
var _time_accum: float = 0.0


func _ready() -> void:
	# 矿洞在远山之前更远, 用 layer = -9 但配合 ScenicDirector 切换 alpha
	# 这里也用 -9, 因为地表和矿洞不会同时全亮
	layer = -9
	# 远岩壁 (motion_scale 0.10)
	_add_layer(0.10, CaveBgArt.rocks(ROCKS_W, ROCKS_H, 7), TOP_Y, ROCKS_W)
	# 钟乳石 (motion_scale 0.18, 顶部下垂)
	_add_layer(0.18, CaveBgArt.stalactites(STAL_W, STAL_H, 14, 11), TOP_Y, STAL_W)
	# 水晶 (motion_scale 0.25)
	var crystal_pl := _add_layer(0.25, CaveBgArt.crystals(CRYSTAL_W, CRYSTAL_H, 30, 23), 80, CRYSTAL_W)
	# 水晶层取 sprite 用于闪烁
	_crystal_sprites = []
	for child in crystal_pl.get_children():
		if child is Sprite2D:
			_crystal_sprites.append(child)
	# 初始 alpha=0, 由 ScenicDirector 切换
	_apply_alpha()


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
	_all_sprites.append(sp)
	return pl


func _process(delta: float) -> void:
	_time_accum += delta
	# 水晶层呼吸闪烁 + 整体 alpha 控制
	# (CanvasLayer 没 modulate, 用 sprite.modulate.a 模拟)
	if _crystal_sprites.is_empty():
		return
	var twinkle: float = (sin(_time_accum * 2.0) + 1.0) * 0.5  # 0..1
	var crystal_alpha: float = (0.6 + twinkle * 0.4) * _layer_alpha
	for sp in _crystal_sprites:
		sp.modulate.a = crystal_alpha


# ScenicDirector 调这个统一改 alpha
func set_layer_alpha(a: float) -> void:
	_layer_alpha = clamp(a, 0.0, 1.0)
	_apply_alpha()


func _apply_alpha() -> void:
	for sp in _all_sprites:
		sp.modulate.a = _layer_alpha


func current_alpha() -> float:
	return _layer_alpha


# 测试用
func layer_count() -> int:
	var n: int = 0
	for child in get_children():
		if child is ParallaxLayer:
			n += 1
	return n
