# 方块保留挖掘进度: 松手后进度+裂纹不丢, 回来接着挖 (累加而非清零).
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_mining_progress_retained_across_pauses() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	inv.pickup("wood_pickaxe", 1)
	inv.set_hotbar_selection(0)
	var pt: Vector2i = action.player_tile()
	var target := Vector2i(pt.x + 2, pt.y)
	# STONE 硬度 3.0 (木镐 3s 挖完) → 短按几下不会破, 适合测保留
	world._set_tile(target.x, target.y, Tiles.STONE)
	action.aim_override = target
	# 第一段: 按 0.2s 松手
	action.primary_override = true
	await wait_seconds(0.2)
	action.primary_override = false
	await wait_frames(1)
	assert_true(action._mine_saved.has(target), "松手后应保留该格进度")
	var p1: float = action._mine_saved[target][1]
	assert_gt(p1, 0.0, "第一段应有进度")
	var co = world.get_node("CrackOverlay")
	assert_gt(co.active_count(), 0, "松手后裂纹应保留 (看得出半挖)")
	# 第二段: 再按 0.2s
	action.primary_override = true
	await wait_seconds(0.2)
	action.primary_override = false
	await wait_frames(1)
	var p2: float = action._mine_saved[target][1]
	assert_gt(p2, p1, "第二段应在第一段基础上累加 (而非清零重来)")
	assert_eq(terrain.get_cell_source_id(target), Tiles.STONE, "短按两段还不该破石头")


func test_changed_tile_does_not_inherit_progress() -> void:
	# 那格方块换了 (tid 变) 就不续旧进度 — 防"挖掉重放的新方块自带进度".
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	inv.pickup("wood_pickaxe", 1)
	inv.set_hotbar_selection(0)
	var pt: Vector2i = action.player_tile()
	var target := Vector2i(pt.x + 2, pt.y)
	world._set_tile(target.x, target.y, Tiles.STONE)
	action.aim_override = target
	action.primary_override = true
	await wait_seconds(0.2)
	action.primary_override = false
	await wait_frames(1)
	assert_gt(action._mine_saved[target][1], 0.0, "石头有进度")
	# 把该格换成 COAL_ORE (木镐也能挖, tid 不同 — 模拟那格方块变了), 再挖 → 不继承石头进度
	var terrain2: TileMapLayer = world.get_node("TerrainLayer")
	world._set_tile(target.x, target.y, Tiles.COAL_ORE)
	await wait_frames(1)
	assert_eq(terrain2.get_cell_source_id(target), Tiles.COAL_ORE, "诊断: 应已变 COAL_ORE")
	action.primary_override = true
	await wait_frames(3)   # 刚开挖几帧, 进度应很小
	action.primary_override = false
	await wait_frames(1)
	assert_true(action._mine_saved.has(target), "诊断: 挖了应有存档")
	assert_eq(action._mine_saved[target][0], Tiles.COAL_ORE, "诊断: 存档 tid 应是 COAL_ORE")
	var prog: float = action._mine_saved[target][1] if action._mine_saved.has(target) else 0.0
	assert_lt(prog, 0.2, "换了方块应从头挖, 不继承旧进度 (got %f)" % prog)
