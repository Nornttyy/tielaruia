# 回归: 对战房不刷怪 — 连 chunk 加载触发的 (哈比鸟/木乃伊/矿井蜘蛛) 也要拦.
# 用户报: 战斗房还会生成生物.
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func _boot() -> Node:
	var main = MainScene.instantiate(); add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(5)
	return main.get_node("World")


func after_each() -> void:
	NetworkManager.status = "idle"
	NetworkManager.room_mode = "survival"


func test_harpy_not_spawned_in_pvp() -> void:
	var world = await _boot()
	var er = world.entities_root
	NetworkManager.status = "connected"
	NetworkManager.room_mode = "pvp"
	var before: int = er.get_child_count()
	world.spawn_harpies_for_chunk(12345, [Vector2i(5, 5), Vector2i(8, 5)])
	assert_eq(er.get_child_count(), before, "对战房 chunk 加载不该刷哈比鸟")


func test_harpy_spawns_in_normal_world() -> void:
	# 对照: 单机(非对战房)照常刷
	var world = await _boot()
	var er = world.entities_root
	NetworkManager.status = "idle"
	NetworkManager.room_mode = "survival"
	var before: int = er.get_child_count()
	world.spawn_harpies_for_chunk(54321, [Vector2i(5, 5)])
	assert_gt(er.get_child_count(), before, "普通世界该正常刷哈比鸟")
