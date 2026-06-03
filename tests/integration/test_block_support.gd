# 方块支撑规则: 挖掉草下方块 → 草联动消失; 树底正下方那格挖不动 (支撑保护).
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func _boot():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	return main


func test_plant_falls_when_support_mined() -> void:
	var main = await _boot()
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	inv.pickup("wood_pickaxe", 1)
	inv.set_hotbar_selection(0)
	var pt: Vector2i = action.player_tile()
	var bx: int = pt.x + 2
	var by: int = pt.y
	# 支撑块 GRASS, 上面长 PLANT_GRASS (小草)
	world._set_tile(bx, by, Tiles.GRASS)
	world._set_tile(bx, by - 1, Tiles.PLANT_GRASS)
	# 挖掉支撑块
	action.aim_override = Vector2i(bx, by)
	action.primary_override = true
	await wait_seconds(0.6)
	action.primary_override = false
	await wait_frames(1)
	assert_eq(terrain.get_cell_source_id(Vector2i(bx, by)), -1, "支撑块应被挖掉")
	assert_eq(terrain.get_cell_source_id(Vector2i(bx, by - 1)), -1, "小草应联动消失 (不悬空)")


func test_tree_support_block_cannot_be_mined() -> void:
	var main = await _boot()
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	inv.pickup("wood_pickaxe", 1)
	inv.set_hotbar_selection(0)
	var pt: Vector2i = action.player_tile()
	var bx: int = pt.x + 2
	var by: int = pt.y
	# 树底 LOG 在上, 支撑块 DIRT 在下 → DIRT 撑着树, 应挖不动
	world._set_tile(bx, by - 1, Tiles.LOG)   # 树底 (下方 DIRT 非树部件 → 算树底)
	world._set_tile(bx, by, Tiles.DIRT)      # 支撑块
	action.aim_override = Vector2i(bx, by)
	action.primary_override = true
	await wait_seconds(0.8)   # 没保护的话 DIRT 0.3s 就没了
	action.primary_override = false
	await wait_frames(1)
	assert_eq(terrain.get_cell_source_id(Vector2i(bx, by)), Tiles.DIRT, "树的支撑块应挖不动")
	# 对照: 旁边一格普通 DIRT 照样能挖
	var ox: int = pt.x + 3
	world._set_tile(ox, by, Tiles.DIRT)
	action.aim_override = Vector2i(ox, by)
	action.primary_override = true
	await wait_seconds(0.6)
	action.primary_override = false
	await wait_frames(1)
	assert_eq(terrain.get_cell_source_id(Vector2i(ox, by)), -1, "对照: 非支撑的普通块照样能挖")
