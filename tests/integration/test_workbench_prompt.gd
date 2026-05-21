extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_prompt_shows_near_workbench():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	var fp: CanvasLayer = get_tree().get_first_node_in_group("floating_prompt")
	# 在玩家旁边放 1 个 workbench
	var foot: Vector2 = player.global_position
	var pt := Vector2i(int(floor(foot.x / 16.0)), int(floor(foot.y / 16.0)))
	terrain.set_cell(pt + Vector2i(1, 0), Tiles.WORKBENCH, Vector2i.ZERO)
	await wait_frames(2)
	assert_true(fp.is_showing(), "靠近工作台应显示提示")


func test_prompt_hides_when_no_workbench():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	# 默认没有工作台 → 不显示
	var fp: CanvasLayer = get_tree().get_first_node_in_group("floating_prompt")
	await wait_frames(2)
	assert_false(fp.is_showing())
