# 远景协调器: 按玩家 Y 跟 "玩家所在列原始地表" 的差值 (= depth_below_surface)
# 平滑切换地表背景 ↔ 矿洞背景.
#
# "原始地表" 用墙 (walls) 查询: 第一行非 AIR 墙 = 草/土/石生成时的 surf 行.
# 这样玩家挖洞下去, surface_y 不变 (墙不能挖, 仍标记着原生地表位置).
#
# 切换分两阶段:
#   [0..10 格 上层]      天空 + 山, 矿洞 0  (含泥土层 6 格 + 浅石头过渡 4 格)
#   [10..14 格]          浅 t 0→1 远岩壁渐入 (能看到棕褐墙 + 蘑菇 + 化石)
#   [14..30 格]          浅 t = 1, 深 t = 0  (只有岩壁, 没有钟乳石/水晶)
#   [30..36 格]          深 t 0→1 钟乳石+水晶+岩浆+蝠 渐入
#   [36+ 格]             完全矿洞
#
extends Node

const Chunk = preload("res://scripts/world/chunk.gd")
const ChunkConstants = preload("res://scripts/world/chunk_constants.gd")
const WorldGenerator = preload("res://scripts/world/world_generator.gd")
const TILE_SIZE := 16

# 距离原始草方块多少格才开始切换
const SHALLOW_START_TILES := 10      # >10 格深才开始显远岩壁
const SHALLOW_TRANSITION_TILES := 4  # 10→14 格 浅 t 0→1
const DEEP_START_TILES := 30         # >30 格深才开始显钟乳石/水晶
const DEEP_TRANSITION_TILES := 6     # 30→36 格 深 t 0→1

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
# Biome 远景切换 (用户要求"不同群系不同背景"):
# 玩家在群系内时, 远山/天空 modulate 缓慢 lerp 到该群系的色调.
var _biome_tint_current: Color = Color.WHITE       # 当前实际 tint (lerp 用)
var _biome_tint_target: Color = Color.WHITE        # 目标 tint
const _BIOME_TINT_LERP_PER_SEC := 1.5              # 每秒 lerp 多少 (0→1 大约 0.7s)
# 各 biome 的 modulate (multiply 上, 1.0=不变)
const _BIOME_TINTS := {
	0: Color(1.0, 1.0, 1.0),    # FOREST 默认
	1: Color(1.30, 1.00, 0.65), # DESERT 橙黄
	2: Color(0.85, 1.00, 1.25), # SNOW 蓝白
	3: Color(0.75, 1.15, 0.75), # JUNGLE 深绿
	4: Color(0.85, 0.95, 0.85), # SWAMP 灰绿
}


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


# 给 World._apply_graphics_settings 用 — 切远景视觉层的可见性.
# ScenicDirector 本身 extends Node 无 .visible 属性, 不能直接 .visible = b.
func set_layers_visible(b: bool) -> void:
	if _mountains != null:
		_mountains.visible = b
	if _celestial != null:
		_celestial.visible = b
	if _cave_bg != null:
		_cave_bg.visible = b
	if _sky_bg != null:
		_sky_bg.visible = b


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


# 节流: 深度计算 + alpha 应用每 0.1s 一次 (够丝滑, 不必每帧).
const _UPDATE_INTERVAL := 0.1
var _update_timer: float = 0.0


func _process(delta: float) -> void:
	if _world == null:
		return
	# Biome tint lerp (每帧, 平滑过渡)
	_update_biome_tint(delta)
	_update_timer -= delta
	if _update_timer > 0.0:
		return
	_update_timer = _UPDATE_INTERVAL
	var depth_tiles: float = _player_depth_below_surface_tiles()
	var shallow_t: float = compute_shallow_t_from_depth(depth_tiles)
	var deep_t: float = compute_deep_t_from_depth(depth_tiles)
	_apply_depths(shallow_t, deep_t)


# 检查玩家所在 biome → 更新 target tint, lerp current 朝 target
func _update_biome_tint(delta: float) -> void:
	var player: Node2D = _world.get_player() if _world.has_method("get_player") else null
	if player == null:
		return
	var world_seed: int = _world.world_seed if "world_seed" in _world else 0
	var player_x_tile: int = int(floor(player.global_position.x / float(TILE_SIZE)))
	var biome_id: int = WorldGenerator._biome_at(player_x_tile, world_seed)
	_biome_tint_target = _BIOME_TINTS.get(biome_id, Color.WHITE)
	# Lerp current → target
	_biome_tint_current = _biome_tint_current.lerp(_biome_tint_target, clamp(delta * _BIOME_TINT_LERP_PER_SEC, 0.0, 1.0))
	# 应用到远山 (modulate). cave_bg / sky_bg 暂不动 (它们由 depth/time 控制 alpha, 加 tint 容易冲突).
	if _mountains != null and _mountains is CanvasItem:
		var ci: CanvasItem = _mountains
		# 保留原 alpha (depth alpha 别覆盖)
		var a: float = ci.modulate.a
		ci.modulate = Color(_biome_tint_current.r, _biome_tint_current.g, _biome_tint_current.b, a)


# === 公开 compute (静态, 容易测) ===

# 给定玩家在地表下面多少 tile, 算浅 t (远岩壁渐入)
static func compute_shallow_t_from_depth(depth_tiles: float) -> float:
	var beyond: float = depth_tiles - float(SHALLOW_START_TILES)
	if beyond <= 0.0:
		return 0.0
	return clamp(beyond / float(SHALLOW_TRANSITION_TILES), 0.0, 1.0)


# 给定玩家在地表下面多少 tile, 算深 t (钟乳石/水晶渐入)
static func compute_deep_t_from_depth(depth_tiles: float) -> float:
	var beyond: float = depth_tiles - float(DEEP_START_TILES)
	if beyond <= 0.0:
		return 0.0
	return clamp(beyond / float(DEEP_TRANSITION_TILES), 0.0, 1.0)


# === 兼容旧接口 (老测试 / 老代码用 player_y_px + 平均 surface_base) ===

static func compute_shallow_t(player_y_px: float) -> float:
	var surface_y_px: float = WorldGenerator.SURFACE_BASE \
		* float(ChunkConstants.WORLD_HEIGHT) * float(TILE_SIZE)
	var depth_tiles: float = (player_y_px - surface_y_px) / float(TILE_SIZE)
	return compute_shallow_t_from_depth(depth_tiles)


static func compute_deep_t(player_y_px: float) -> float:
	var surface_y_px: float = WorldGenerator.SURFACE_BASE \
		* float(ChunkConstants.WORLD_HEIGHT) * float(TILE_SIZE)
	var depth_tiles: float = (player_y_px - surface_y_px) / float(TILE_SIZE)
	return compute_deep_t_from_depth(depth_tiles)


static func compute_cave_t(player_y_px: float) -> float:
	return compute_shallow_t(player_y_px)


# === 实例方法: 算玩家当前所在 X 列的真实 depth_below_surface (in tiles) ===

func _player_depth_below_surface_tiles() -> float:
	var p: Node2D = _get_player_node()
	if p == null:
		return 0.0
	var px_tile: int = int(floor(p.global_position.x / float(TILE_SIZE)))
	var surf_y_tile: int = _find_surface_y_tile(px_tile)
	if surf_y_tile < 0:
		# fallback: 用平均 surface_y
		var avg_y: float = WorldGenerator.SURFACE_BASE \
			* float(ChunkConstants.WORLD_HEIGHT)
		return p.global_position.y / float(TILE_SIZE) - avg_y
	var player_y_tile: float = p.global_position.y / float(TILE_SIZE)
	return player_y_tile - float(surf_y_tile)


# 用 chunk.surfaces 取原始地表 y_tile (世界生成时存下, 不被玩家挖动).
func _find_surface_y_tile(world_x_tile: int) -> int:
	if _world == null:
		return -1
	var cm = _world.get("chunk_manager")
	if cm == null:
		return -1
	var chunk_x: int = Chunk.chunk_x_of(world_x_tile)
	var local_x: int = Chunk.local_x_of(world_x_tile)
	# 不加 : Chunk 类型注解 (mock 测试用别的类). 鸭子类型 surfaces 即可.
	var ch = cm.get_chunk(chunk_x)
	if ch == null:
		return -1
	if not ("surfaces" in ch) or ch.surfaces == null or ch.surfaces.size() <= local_x:
		return -1
	return ch.surfaces[local_x]


func _get_player_node() -> Node2D:
	if _world == null or not _world.has_method("get_player"):
		return null
	return _world.get_player()


func _get_player_y() -> float:
	var p: Node2D = _get_player_node()
	if p == null:
		return 0.0
	return p.global_position.y


func _apply_depths(shallow_t: float, deep_t: float) -> void:
	# 地表层用 shallow_t 反向 fade out (玩家一进浅过渡区就开始 fade)
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
	return compute_shallow_t_from_depth(_player_depth_below_surface_tiles())


func current_shallow_t() -> float:
	return compute_shallow_t_from_depth(_player_depth_below_surface_tiles())


func current_deep_t() -> float:
	return compute_deep_t_from_depth(_player_depth_below_surface_tiles())
