# 玩家移动惯性: 起步加速 (1 帧没到顶速) + 松手滑行 (不瞬停)。
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const PC = preload("res://scripts/player/player_controller.gd")


func after_each():
	Input.action_release("move_right")   # 别把按键状态漏给别的测试


func test_inertia_ramp_and_slide():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(10)   # 让玩家落地站稳
	var player: Node2D = main.get_node("World").get_player()

	# 起步: 按右键 1 帧 → 已经动但还没到顶速 (有加速过程 = 惯性)
	# headless 下按键状态不会自动保持, 要每帧重按 (照 test_slope_walk)
	Input.action_press("move_right")
	await wait_frames(1)
	var v_first: float = player.velocity.x
	assert_gt(v_first, 0.0, "按右键开始往右加速")
	assert_lt(v_first, PC.SPEED, "1 帧还没冲到顶速 (惯性加速中)")

	# 再走几帧 → 速度还在往上爬 (没瞬间到顶 = 惯性). 只走 4 帧免得撞到地形被墙挡住归零
	for i in range(4):
		Input.action_press("move_right")
		await wait_frames(1)
	assert_gt(player.velocity.x, v_first, "继续加速, 速度比第 1 帧高")

	# 松手 → 减速滑行, 不瞬停
	Input.action_release("move_right")
	var v_before: float = player.velocity.x
	await wait_frames(1)
	assert_lt(player.velocity.x, v_before, "松手后开始减速")
	assert_gt(player.velocity.x, 0.0, "松手第 1 帧还在滑 (没瞬间停, = 惯性)")
