# 远景协调器: 按玩家 Y (地表 vs 矿洞深处) 平滑切换地表背景 ↔ 矿洞背景.
# 接 setup(refs: Dictionary) 拿到所有 layer 引用, 每帧调 modulate.a.
extends Node

const ChunkConstants = preload("res://scripts/world/chunk_constants.gd")
const WorldGenerator = preload("res://scripts/world/world_generator.gd")
const TILE_SIZE := 16

# 矿洞远景按"浅层" / "深层" 两阶段切换:
#
#   [0..6 格 泥土层]     全屏地表 (天空+山), 矿洞 0
#   [6..14 格 浅石头层]   远岩壁 0→1 fade 进来 (能看到棕褐岩壁 + 蘑菇 🍄 + 化石 💀)
#   [14..24 格 深石头层]  钟乳石 + 水晶 0→1 fade 进来 (整个矿洞场景到位)
#
# 远岩壁用 shallow_t, 钟乳石+水晶用 deep_t (cave_background_layer 双 alpha).
# 地表层 (山/日月星/鸟/彩虹/极光) 用 shallow_t 来反向 fade out.
const STONE_LAYER_TILES := 6         # 泥土层厚度 (跟 WorldGenerator.DIRT_DEPTH 同步)
const SHALLOW_TRANSITION_TILES := 8  # 进石头层 8 格内 → 浅 cave_t 0→1
const DEEP_START_TILES := 14         # 14 格深开始显钟乳石/水晶
const DEEP_TRANSITION_TILES := 10    # 14→24 格内 deep_t 0→1

var _world: Node = null
var _mountains: Node = null
var _celestial: Node = null
var _cave_bg: Node = null
var _sky_bg: Node = null
# 点缀 (Phase 4 接入)
var _bird: Node = null
var _bat: Node = null
var _rainbow: Node = null
var _aurora: Node = null
var _lava_drip: Node = null


# 由 World 在 _ready 调用, 把所有 layer 引用绑进来. 任何 key 缺省 = 该层不存在 (跳过).
func setup(refs: Dictionary) -> void:
	_world = refs.get("world", null)
	_mountains = refs.get("mountains", null)
	_celestial = refs.get("celestial", null)
	_cave_bg = refs.get("cave_bg", null)
	_sky_bg = refs.get("sky_bg", null)
	_bird = refs.get("bird", null)
	_bat = refs.get("bat", null)
	_rainbow = refs.get("rainbow", null)
	_aurora = refs.get("aurora", null)
	_lava_drip = refs.get("lava_drip", null)


# 自动从父节点 (World) 找 sibling 节点 (按名称约定).
# 这样可以直接把 ScenicDirector 挂到 world.tscn 里, 不用改 world.gd 代码.
func _ready() -> void:
	if _world != null:
		return  # setup 已被调用, 不自动发现
	var parent: Node = get_parent()
	if parent == null:
		return
	_world = parent
	_mountains = parent.get_node_or_null("MountainsLayer")
	_celestial = parent.get_node_or_null("CelestialLayer")
	_cave_bg = parent.get_node_or_null("CaveBackgroundLayer")
	_sky_bg = parent.get_node_or_null("SkyBackground")
	_bird = parent.get_node_or_null("BirdLayer")
	_bat = parent.get_node_or_null("BatLayer")
	_rainbow = parent.get_node_or_null("RainbowLayer")
	_aurora = parent.get_node_or_null("AuroraLayer")
	_lava_drip = parent.get_node_or_null("LavaDripLayer")


func _process(_delta: float) -> void:
	if _world == null:
		return
	var player_y_px: float = _get_player_y()
	var shallow_t: float = compute_shallow_t(player_y_px)
	var deep_t: float = compute_deep_t(player_y_px)
	_apply_depths(shallow_t, deep_t)


# 浅 t: 进入石头层就开始 fade 远岩壁
static func compute_shallow_t(player_y_px: float) -> float:
	var surface_y_px: float = WorldGenerator.SURFACE_BASE \
		* float(ChunkConstants.WORLD_HEIGHT) * float(TILE_SIZE)
	var depth_below_px: float = player_y_px - surface_y_px
	var depth_in_stone_px: float = depth_below_px - float(STONE_LAYER_TILES * TILE_SIZE)
	if depth_in_stone_px <= 0.0:
		return 0.0
	return clamp(depth_in_stone_px / float(SHALLOW_TRANSITION_TILES * TILE_SIZE), 0.0, 1.0)


# 深 t: 14 格深才开始 fade 钟乳石/水晶
static func compute_deep_t(player_y_px: float) -> float:
	var surface_y_px: float = WorldGenerator.SURFACE_BASE \
		* float(ChunkConstants.WORLD_HEIGHT) * float(TILE_SIZE)
	var depth_below_px: float = player_y_px - surface_y_px
	var depth_in_deep_px: float = depth_below_px - float(DEEP_START_TILES * TILE_SIZE)
	if depth_in_deep_px <= 0.0:
		return 0.0
	return clamp(depth_in_deep_px / float(DEEP_TRANSITION_TILES * TILE_SIZE), 0.0, 1.0)


# 兼容老接口 (test_scenic_director 旧版本 + 自动发现路径里可能调用)
static func compute_cave_t(player_y_px: float) -> float:
	return compute_shallow_t(player_y_px)


func _get_player_y() -> float:
	if _world == null or not _world.has_method("get_player"):
		return 0.0
	var p = _world.get_player()
	if p == null:
		return 0.0
	return p.global_position.y


func _apply_depths(shallow_t: float, deep_t: float) -> void:
	# 地表层用 shallow_t 反向 fade out (玩家一进石头层就开始 fade)
	_set_alpha(_mountains, 1.0 - shallow_t * 0.85)  # 矿洞里山留 15% 阴影
	_set_alpha(_celestial, 1.0 - shallow_t)
	# SkyBackground 节点是 CanvasLayer; 实际 ColorRect 在 Bg 子节点
	_set_alpha_sky(1.0 - shallow_t * 0.7)
	# 矿洞背景: 远岩壁用 shallow_t, 钟乳石/水晶用 deep_t (走双 alpha 接口)
	if _cave_bg != null and _cave_bg.has_method("set_depth_alphas"):
		_cave_bg.set_depth_alphas(shallow_t, deep_t)
	else:
		_set_alpha(_cave_bg, shallow_t)
	# 鸟/蝠/彩虹/极光跟 shallow_t (粗粒度切换), 岩浆滴跟 deep_t (深层才滴)
	_set_alpha(_bird, 1.0 - shallow_t)
	_set_alpha(_bat, deep_t)
	_set_alpha(_rainbow, 1.0 - shallow_t)
	_set_alpha(_aurora, 1.0 - shallow_t)
	_set_alpha(_lava_drip, deep_t)


# 优先用 set_layer_alpha() 方法 (ParallaxBackground/CanvasLayer 没 modulate);
# 否则直接 modulate.a (Node2D 等 CanvasItem)
func _set_alpha(layer: Node, a: float) -> void:
	if layer == null:
		return
	if layer.has_method("set_layer_alpha"):
		layer.set_layer_alpha(a)
	elif layer is CanvasItem:
		var ci: CanvasItem = layer
		var m: Color = ci.modulate
		m.a = a
		ci.modulate = m


# SkyBackground 树: CanvasLayer / Bg(ColorRect script=sky_background.gd)
func _set_alpha_sky(a: float) -> void:
	if _sky_bg == null:
		return
	# 找 ColorRect 子节点 (脚本在子上)
	var bg: Node = _sky_bg.get_node_or_null("Bg")
	if bg != null and bg.has_method("set_layer_alpha"):
		bg.set_layer_alpha(a)
		return
	# fallback: 树根有脚本 (单 ColorRect 直接挂)
	if _sky_bg.has_method("set_layer_alpha"):
		_sky_bg.set_layer_alpha(a)


# 测试用
func current_cave_t() -> float:
	return compute_shallow_t(_get_player_y())


func current_shallow_t() -> float:
	return compute_shallow_t(_get_player_y())


func current_deep_t() -> float:
	return compute_deep_t(_get_player_y())
