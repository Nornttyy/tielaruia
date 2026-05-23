extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func _setup_held() -> Sprite2D:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var player = main.get_node("World").get_player()
	var held: Sprite2D = player.get_node("HeldItem")
	var inv: Node = player.get_node("PlayerInventory")
	inv.inventory.add("wood_sword", 1)
	inv.set_hotbar_selection(0)
	await wait_frames(3)
	# 测试用: 强制 visible (有些 CI 环境下贴图加载时序导致 visible 慢半拍)
	held.visible = true
	return held


func test_play_swing_directional_target_right():
	var held: Sprite2D = await _setup_held()
	# 目标朝正右 (target_angle=0). 起手 = base - 45° = (0+PI/2) - PI/4 = PI/4
	held.play_swing_directional(0.0)
	assert_almost_eq(held.rotation, PI / 2.0 - deg_to_rad(45.0), 0.05)


func test_play_swing_directional_target_up():
	var held: Sprite2D = await _setup_held()
	# 目标朝正上 (target_angle=-PI/2). 起手 = (-PI/2 + PI/2) - PI/4 = -PI/4
	held.play_swing_directional(-PI / 2.0)
	assert_almost_eq(held.rotation, 0.0 - deg_to_rad(45.0), 0.05)


func test_play_swing_directional_skips_when_invisible():
	var held: Sprite2D = await _setup_held()
	held.visible = false
	held.rotation = 0.0
	held.play_swing_directional(PI / 4.0)
	# 不可见时不动
	assert_eq(held.rotation, 0.0)
