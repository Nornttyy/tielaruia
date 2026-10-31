# 专用美术试走场景；只通过菜单/命令行进入，不向正常存档自动加村庄。
extends RefCounted
const Placer = preload("res://scripts/world/village_placer.gd")
const Prefab = preload("res://scripts/world/village_prefab.gd")

static func apply(world: Node2D) -> void:
	var cm = world.chunk_manager
	var anchor: Vector2i = world.spawn_point + Vector2i(-14, 2)
	# 一小块平地让三栋样屋可对照；外围世界保持原样。
	for cx in range(Chunk.chunk_x_of(anchor.x - 50), Chunk.chunk_x_of(anchor.x + 115) + 1):
		cm.load_one(cx)
	for x in range(anchor.x - 40, anchor.x + 105):
		var chunk = cm.get_chunk(Chunk.chunk_x_of(x))
		chunk.surfaces[Chunk.local_x_of(x)] = anchor.y + 1
		for y in range(0, mini(ChunkConstants.WORLD_HEIGHT - 1, anchor.y + 45)):
			world._set_tile(x, y, Tiles.GRASS if y == anchor.y + 1 else (Tiles.DIRT if y > anchor.y + 1 else Tiles.AIR), true, true)
			world._set_wall(x, y, Tiles.AIR)
	Placer.place(cm, world.terrain_layer, Prefab.load_default(), anchor, world.wall_layer)
	# 用游戏里的整片树冠和树干构成近景，不把背景树拉大冒充可砍树木。
	for entry in [[-21, 14], [-8, 11], [29, 14], [62, 12], [90, 15]]:
		var tx: int = anchor.x + entry[0]
		var height: int = entry[1]
		for y in range(anchor.y - height + 1, anchor.y + 1): world._set_tile(tx, y, Tiles.LOG, true)
		world._set_tile(tx, anchor.y - height, Tiles.LOG_TOP, true)
		world._set_tile(tx - 1, anchor.y, Tiles.LOG_ROOT_L, true)
		world._set_tile(tx + 1, anchor.y, Tiles.LOG_ROOT_R, true)
		world._set_tile(tx - 1, anchor.y - height + 3, Tiles.BRANCH_L, true)
		world._set_tile(tx + 1, anchor.y - height + 5, Tiles.BRANCH_R, true)
	var player = world.get_player()
	player.position = Vector2((anchor.x + 14.5) * 12, anchor.y * 12)
	player.velocity = Vector2.ZERO
	world.bed_spawn_point = Vector2i(anchor.x + 14, anchor.y - 1)
	world.camera.set_meta("art_preview_zoom", 2.0)
	world.camera.zoom = Vector2(2.0, 2.0)
	world._slime_spawn_timer = INF
	world._animal_spawn_timer = INF
	world.camera.reset_smoothing()
	# 预览自己的道具栏，角色存档不参与；拆装能直接比较像素比例。
	var pinv = player.get_node("PlayerInventory")
	pinv.inventory.slots.fill(null)
	var items := ["copper_pickaxe", "planks", "wood_wall", "door", "wood_chair", "wood_table", "glass_wall", "wood_bow", "wood_platform", "torch"]
	for i in items.size(): pinv.inventory.slots[i] = {"item_id": items[i], "count": 1 if items[i] in ["copper_pickaxe", "wood_bow"] else 99}
	for entry in [["copper_dagger", 1], ["copper_axe", 1], ["wood_sword", 1], ["wood_arrow", 999], ["glass", 99], ["gray_brick", 99], ["red_brick", 99], ["clay", 99], ["sand", 99], ["furnace", 1]]:
		pinv.inventory.add(entry[0], entry[1])
	pinv.inventory_changed.emit()
	var layer := CanvasLayer.new()
	layer.layer = 12
	world.add_child(layer)
	var label := Label.new()
	label.text = "建筑美术预览    A/D 移动 · 空格跳跃 · 右键放置 · Esc 背包 · F10 返回菜单"
	label.position = Vector2(22, 684)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.12, 0.18))
	label.add_theme_constant_override("outline_size", 5)
	layer.add_child(label)
