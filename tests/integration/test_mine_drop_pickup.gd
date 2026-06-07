extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_mine_grass_then_pick_up():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	# 空手挖不动, 给个木镐 + 选中
	inv.pickup("wood_pickaxe", 1)
	inv.set_hotbar_selection(0)
	var pt: Vector2i = action.player_tile()
	var target: Vector2i = pt + Vector2i(2, 0)
	terrain.set_cell(target, Tiles.GRASS, Vector2i.ZERO)
	world._set_tile(target.x, target.y, Tiles.GRASS)
	action.aim_override = target
	action.primary_override = true
	# 挖完 (hardness 0.3s, 保留余量)
	await wait_seconds(0.5)
	action.primary_override = false
	# tile 已清
	assert_eq(terrain.get_cell_source_id(target), -1)
	# 等 pickup_delay (0.4s) 完全过期后再接近 drop
	await wait_seconds(0.5)
	# 瞬移玩家到 drop 位置触发 pickup
	player.global_position = Vector2(target.x * 6 + 3, target.y * 6 + 6)
	# 等几帧 area body_entered 信号触发
	await wait_frames(10)
	# inventory 中应有 grass 或 dirt
	var got: int = 0
	for slot in inv.inventory.slots:
		if slot != null and (slot.item_id == "dirt" or slot.item_id == "grass"):
			got += slot.count
	assert_gt(got, 0, "应至少拾到 1 个 dirt/grass")
