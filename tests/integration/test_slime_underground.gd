# 地下刷史莱姆: 玩家在深处, 周围能刷出对应颜色(红/紫)的史莱姆.
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const TILE_SIZE := 12


func test_underground_slime_spawns_colored_by_depth():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game(2024)
	await wait_frames(15)
	var world = main.get_node("World")
	var player = world.get_player()
	assert_not_null(player)
	# 玩家瞬移到深地下 (surf~115 下方 100 格 ≈ 红区, < 220 非地狱)
	var deep_y := 215
	player.global_position = Vector2(6.0, deep_y * TILE_SIZE)
	# 挖一条横洞给史莱姆站脚: deep_y / deep_y-1 行 AIR, deep_y+1 行实心地板
	for dx in range(-30, 31):
		world._set_tile(dx, deep_y, Tiles.AIR)
		world._set_tile(dx, deep_y - 1, Tiles.AIR)
		if world.chunk_manager.get_tile(dx, deep_y + 1) == Tiles.AIR:
			world._set_tile(dx, deep_y + 1, Tiles.STONE)
	await wait_frames(2)
	# 直接调地下刷怪函数 (绕过 timer), 多试几次提高命中
	for i in 30:
		world._try_spawn_underground_slime()
		await wait_frames(1)
	var spawned_colored := false
	for n in get_tree().get_nodes_in_group("slimes"):
		if is_instance_valid(n) and "color_tier" in n and n.color_tier >= 2:
			spawned_colored = true
	assert_true(spawned_colored, "深地下应刷出红/紫(tier>=2)史莱姆")
