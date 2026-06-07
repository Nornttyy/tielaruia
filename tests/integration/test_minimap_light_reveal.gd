# 小地图按光照露图: 天光照到的 + 玩家旁边一圈 才露; 黑暗深处(没走近)不露.
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const TILE := 6


func test_minimap_reveals_lit_and_adjacent_not_dark_far():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game(2024)
	await wait_frames(15)
	var world = main.get_node("World")
	var player = world.get_player()
	var md = world.minimap_data
	var ptx: int = int(floor(player.global_position.x / TILE))
	var pty: int = int(floor(player.global_position.y / TILE))
	world._mark_explored_around_player()
	# 1) 玩家脚下 (旁边一圈) → 一定露
	assert_true(md.is_explored(ptx, pty), "玩家脚下该露")
	# 2) 地下深处: 没天光 + 离玩家远(>旁边一圈) → 不该露 (老逻辑会整片矩形露出, 这是要修的)
	var deep_y: int = pty + 18   # 在 MINIMAP_VIEW_Y/2 内, 但远超 REVEAL_ADJ
	if not SkyLightGrid.is_sky_exposed(ptx, deep_y):
		assert_false(md.is_explored(ptx, deep_y), "地下深处(黑暗+没走近)不该露")
	else:
		gut.p("(deep_y 恰好天光可达, 跳过该断言)")
		assert_true(true)
