# 小地图渲染: 玩家中心 ±view_tiles_x/y 范围 tile, 每 tile pixel_per_tile 像素.
# 未探索 tile 黑色, 已探索按 _TILE_COLORS 上色. 玩家位置中心红块.
# 200ms 刷新一次. 鼠标滚轮在 minimap 上 → 缩放档位 1/2/3/4 px/tile.
extends Control

const MAP_PIXEL_WIDTH := 192   # minimap UI 总宽 (像素)
const MAP_PIXEL_HEIGHT := 128  # minimap UI 总高
const ZOOM_MIN := 1            # 1 px/tile = 远视野 (看更多 tile, 字最小)
const ZOOM_MAX := 8            # 8 px/tile = 近视野 (全屏地图也能放更大)
const ZOOM_DEFAULT := 2
const REFRESH_INTERVAL := 0.2

var pixel_per_tile: int = ZOOM_DEFAULT
const TILE_SIZE := 12
var view_tiles_x: int = MAP_PIXEL_WIDTH / ZOOM_DEFAULT
var view_tiles_y: int = MAP_PIXEL_HEIGHT / ZOOM_DEFAULT

# 大地图相关 (尺寸固定不可调; 滚轮在大地图状态不生效)
const FULLSCREEN_ZOOM := 24    # 大地图每 tile 24px (tile 大显示, 视野约 50x30 tile)
const FULLSCREEN_SCALE := 1.0  # 大地图占整个屏幕
var _fullscreen: bool = false
var _saved_zoom: int = ZOOM_DEFAULT

const _TILE_COLORS := {
	# air 在地下 = 洞 (深紫), 视觉上区分 "已探索的实心" vs "已探索的空洞"
	Tiles.AIR:           Color8(20, 18, 28),     # 深紫黑 = 洞穴
	Tiles.GRASS:         Color8(90, 165, 70),    # 草绿
	Tiles.DIRT:          Color8(120, 88, 60),    # 泥棕
	Tiles.STONE:         Color8(135, 130, 125),  # 石灰
	Tiles.DEEP_STONE:    Color8(85, 80, 78),     # 深石更深灰
	Tiles.SAND:          Color8(220, 200, 140),  # 沙黄
	Tiles.LOG:           Color8(95, 65, 40),     # 树干深棕
	Tiles.LEAVES:        Color8(70, 130, 60),    # 树叶深绿
	Tiles.LEAVES_PINE:   Color8(40, 95, 55),     # 松针深暖绿
	Tiles.LEAVES_AUTUMN: Color8(195, 100, 50),   # 秋叶橙
	Tiles.PLANKS:        Color8(180, 140, 90),   # 木板亮木
	Tiles.WORKBENCH:     Color8(150, 100, 60),   # 工作台
	Tiles.FURNACE:       Color8(120, 70, 50),    # 熔炉 (暖棕红, 区别于工作台)
	Tiles.MUSHROOM:      Color8(110, 165, 235),  # 矿洞蓝蘑菇 (亮蓝, 在深色矿洞里抢眼)
	Tiles.MIMIC_CHEST:   Color8(180, 120, 60),   # 死人箱 (同 CHEST 色, 地图上不暴露身份)
	Tiles.GOLD_CHEST:    Color8(230, 190, 70),   # 金宝箱 (亮金黄)
	Tiles.DIAMOND_CHEST: Color8(130, 200, 240),  # 钻石宝箱 (亮蓝)
	Tiles.LAVA:          Color8(255, 130, 40),   # 岩浆 (亮橙)
	Tiles.HELL_STONE:    Color8(125, 32, 28),    # 地狱石 (深红)
	Tiles.OBSIDIAN:      Color8(20, 15, 25),     # 黑曜石 (近黑)
	Tiles.HELL_FRUIT:    Color8(225, 65, 45),    # 火果 (红)
	Tiles.SHADOW_CHEST:  Color8(50, 20, 25),     # 阴影宝箱 (深黑红, 跟普通箱区分)
	Tiles.DOOR:          Color8(140, 90, 50),    # 门
	Tiles.BEDROCK:       Color8(35, 32, 40),     # 基岩近黑
	Tiles.TORCH:         Color8(255, 200, 80),   # 火把暖黄
	Tiles.SLIME_TORCH:   Color8(160, 230, 110),  # 史莱姆灯黄绿
	Tiles.COAL_ORE:      Color8(45, 40, 38),     # 煤近黑
	Tiles.IRON_ORE:      Color8(210, 140, 80),   # 铁锈橙
	# 新矿
	Tiles.COPPER_ORE:    Color8(195, 110, 60),   # 铜橙红
	Tiles.TIN_ORE:       Color8(195, 195, 175),  # 锡浅灰
	Tiles.GOLD_ORE:      Color8(230, 200, 60),   # 金黄
	Tiles.DIAMOND_ORE:   Color8(140, 220, 235),  # 钻石冰蓝
	Tiles.HELL_CRYSTAL:  Color8(255, 215, 70),   # 地狱晶: 火魂金黄 (用户改, 不再血红)
	Tiles.HELL_ALLOY_ORE: Color8(85, 60, 110),   # 地狱合金矿: 紫黑 (跟金黄区分)
	Tiles.SANDSTONE:     Color8(210, 175, 95),   # 砂岩: 暖黄 (跟普通沙黄稍区分)
	Tiles.MANA_CRYSTAL:  Color8(110, 90, 230),   # 魔力水晶: 蓝紫 (跟生命水晶粉红区分)
	Tiles.SILVER_ORE:    Color8(220, 225, 235),  # 银亮白
	Tiles.WATER:         Color8(60, 100, 170),   # 水蓝
	Tiles.CHEST:         Color8(180, 120, 60),   # 箱子棕黄
	# 群系
	Tiles.SNOW:          Color8(230, 240, 250),  # 雪白蓝
	Tiles.ICE:           Color8(150, 200, 230),  # 冰蓝
	Tiles.JUNGLE_GRASS:  Color8(50, 130, 50),    # 丛林深绿
	Tiles.JUNGLE_DIRT:   Color8(95, 90, 50),     # 丛林泥
	Tiles.JUNGLE_LEAVES: Color8(35, 110, 45),    # 丛林叶
	Tiles.SWAMP_GRASS:   Color8(90, 110, 80),    # 沼泽灰绿
	Tiles.MUD:           Color8(75, 55, 40),     # 泥
	Tiles.SNOW_DIRT:     Color8(140, 145, 160),  # 冻土灰蓝
	# 平台 + 墙 + 绳
	Tiles.WOOD_PLATFORM: Color8(170, 130, 80),   # 木平台
	Tiles.GRASS_WALL:    Color8(45, 75, 35),     # 草墙
	Tiles.DIRT_WALL:     Color8(60, 45, 30),     # 土墙
	Tiles.STONE_WALL:    Color8(60, 60, 60),     # 石墙
	Tiles.WOOD_WALL:     Color8(95, 65, 38),     # 木墙
	Tiles.ROPE:          Color8(130, 95, 60),    # 绳子
	Tiles.CACTUS:        Color8(80, 140, 70),    # 仙人掌
	Tiles.CACTUS_BODY:   Color8(70, 125, 60),
	# 床 + 水晶 + 装饰
	Tiles.BED:           Color8(180, 60, 70),    # 床: 红被显眼
	Tiles.LIFE_CRYSTAL:  Color8(230, 80, 110),   # 生命水晶: 粉红
	Tiles.PLANT_GRASS:   Color8(110, 180, 70),   # 装饰草: 跟 GRASS 微差
	Tiles.WHEAT_0:       Color8(140, 200, 90),   # 小麦苗: 嫩绿
	Tiles.WHEAT_1:       Color8(160, 200, 85),
	Tiles.WHEAT_2:       Color8(190, 195, 80),   # 中: 偏黄
	Tiles.WHEAT_3:       Color8(225, 195, 70),   # 熟: 金黄
}

const _UNEXPLORED_COLOR := Color8(0, 0, 0, 200)
const _PLAYER_COLOR := Color8(255, 80, 80)

@onready var texture_rect: TextureRect = $TextureRect

var _player: Node2D = null
var _chunk_manager: Node = null
var _minimap_data: Node = null
var _image: Image
var _texture: ImageTexture
var _refresh_timer: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(MAP_PIXEL_WIDTH, MAP_PIXEL_HEIGHT)
	# mouse_filter 在 minimap.tscn 设为 STOP, 此处保留一行兜底
	mouse_filter = Control.MOUSE_FILTER_STOP
	_image = Image.create(MAP_PIXEL_WIDTH, MAP_PIXEL_HEIGHT, false, Image.FORMAT_RGBA8)
	_image.fill(_UNEXPLORED_COLOR)
	_texture = ImageTexture.create_from_image(_image)
	texture_rect.texture = _texture
	texture_rect.size = Vector2(MAP_PIXEL_WIDTH, MAP_PIXEL_HEIGHT)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_toggle_fullscreen()
			accept_event()
		# 滚轮 zoom 只在小地图状态生效, 大地图状态忽略 (避免误触改边框)
		elif not _fullscreen and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(pixel_per_tile + 1)
			accept_event()
		elif not _fullscreen and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(pixel_per_tile - 1)
			accept_event()


func _unhandled_input(event: InputEvent) -> void:
	# ESC 关闭全屏地图 (优先于 pause menu)
	if _fullscreen and event.is_action_pressed("ui_cancel"):
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()


func _set_zoom(z: int) -> void:
	var new_zoom: int = clampi(z, ZOOM_MIN, ZOOM_MAX)
	if new_zoom == pixel_per_tile:
		return
	pixel_per_tile = new_zoom
	_recompute_view_tiles()
	_refresh_timer = 0.0  # 立即重绘


func _recompute_view_tiles() -> void:
	# 用 image 实际尺寸算, 不依赖 control.size (layout 滞后一帧)
	view_tiles_x = _image.get_width() / pixel_per_tile
	view_tiles_y = _image.get_height() / pixel_per_tile


func _toggle_fullscreen() -> void:
	_fullscreen = not _fullscreen
	if _fullscreen:
		_enter_fullscreen()
	else:
		_exit_fullscreen()


func _enter_fullscreen() -> void:
	_saved_zoom = pixel_per_tile
	pixel_per_tile = FULLSCREEN_ZOOM
	print("[minimap] enter_fullscreen zoom=", FULLSCREEN_ZOOM, " scale=", FULLSCREEN_SCALE)
	# 大地图固定 60% 屏幕居中 (尺寸不可调)
	var vp: Vector2 = get_viewport_rect().size
	var w: int = int(vp.x * FULLSCREEN_SCALE)
	var h: int = int(vp.y * FULLSCREEN_SCALE)
	var margin_x: int = (int(vp.x) - w) / 2
	var margin_y: int = (int(vp.y) - h) / 2
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 0)
	offset_left = margin_x
	offset_top = margin_y
	offset_right = -margin_x
	offset_bottom = -margin_y
	_rebuild_image_at(w, h)


func _exit_fullscreen() -> void:
	# 恢复到 hud.tscn 配置的右下角 192x128 位置
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 0)
	offset_left = -MAP_PIXEL_WIDTH - 12
	offset_top = -MAP_PIXEL_HEIGHT - 12
	offset_right = -12
	offset_bottom = -12
	pixel_per_tile = _saved_zoom
	custom_minimum_size = Vector2(MAP_PIXEL_WIDTH, MAP_PIXEL_HEIGHT)
	_rebuild_image_at(MAP_PIXEL_WIDTH, MAP_PIXEL_HEIGHT)


# 重建 image / texture 到指定尺寸. 同时更新 view_tiles
func _rebuild_image_at(w: int, h: int) -> void:
	w = max(w, pixel_per_tile)
	h = max(h, pixel_per_tile)
	_image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	_image.fill(_UNEXPLORED_COLOR)
	_texture = ImageTexture.create_from_image(_image)
	texture_rect.texture = _texture
	view_tiles_x = w / pixel_per_tile
	view_tiles_y = h / pixel_per_tile
	_refresh_timer = 0.0


func bind_player(player: Node2D) -> void:
	_player = player
	# 通过 group 找 ChunkManager + MinimapData
	_chunk_manager = get_tree().get_first_node_in_group("chunk_manager")
	_minimap_data = get_tree().get_first_node_in_group("minimap_data")


func _process(delta: float) -> void:
	if _player == null or _chunk_manager == null or _minimap_data == null:
		return
	_refresh_timer -= delta
	if _refresh_timer > 0.0:
		return
	_refresh_timer = REFRESH_INTERVAL
	_redraw()


func _redraw() -> void:
	# 玩家 tile 坐标 (TILE_SIZE = 16)
	var ptx: int = int(floor(_player.global_position.x / float(TILE_SIZE)))
	var pty: int = int(floor(_player.global_position.y / float(TILE_SIZE)))
	var x0: int = ptx - view_tiles_x / 2
	var y0: int = pty - view_tiles_y / 2

	_image.fill(_UNEXPLORED_COLOR)
	# pixel_per_tile >= 4 时画 "3D 边" + 棋盘微噪声让 tile 不像纯色块
	var has_detail: bool = pixel_per_tile >= 4
	for tx in view_tiles_x:
		var world_x: int = x0 + tx
		for ty in view_tiles_y:
			var world_y: int = y0 + ty
			if not _minimap_data.is_explored(world_x, world_y):
				continue
			# 从 minimap_data 取缓存的 tile_id (chunk 卸载也保留), 不能直接问 chunk_manager
			# 因 chunk_manager.get_tile() 对未加载 chunk 返回 AIR → 已探索区会全显示成"洞穴".
			var tid: int = _minimap_data.get_tile_at(world_x, world_y)
			var col: Color = _TILE_COLORS.get(tid, _UNEXPLORED_COLOR)
			var px: int = tx * pixel_per_tile
			var py: int = ty * pixel_per_tile
			if has_detail:
				var hl: Color = col.lightened(0.14)
				var sh: Color = col.darkened(0.22)
				var c2: Color = col.darkened(0.07)  # 棋盘暗格
				for dx in pixel_per_tile:
					for dy in pixel_per_tile:
						var pc: Color = col
						if dx == 0 or dy == 0:
							pc = hl
						elif dx == pixel_per_tile - 1 or dy == pixel_per_tile - 1:
							pc = sh
						else:
							# 棋盘: 每 3 px 一格交替微暗
							if ((dx / 3) + (dy / 3)) % 2 == 1:
								pc = c2
						_image.set_pixel(px + dx, py + dy, pc)
			else:
				for dx in pixel_per_tile:
					for dy in pixel_per_tile:
						_image.set_pixel(px + dx, py + dy, col)

	# 玩家位置标记 (minimap 中心)
	var cx: int = (view_tiles_x / 2) * pixel_per_tile
	var cy: int = (view_tiles_y / 2) * pixel_per_tile
	for dx in range(-1, pixel_per_tile + 1):
		for dy in range(-1, pixel_per_tile + 1):
			var px: int = cx + dx
			var py: int = cy + dy
			if px >= 0 and px < _image.get_width() and py >= 0 and py < _image.get_height():
				_image.set_pixel(px, py, _PLAYER_COLOR)

	_texture.update(_image)
