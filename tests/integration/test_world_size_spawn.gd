# 诊断: 大/小世界 玩家是否埋地里 + 是否拿到起步三件套 (用户反馈小地图显示玩家在地里).
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const TILE_SIZE := 12


func _boot_world(world_size: int, seed_v: int):
	GameSettings.current_world_size = world_size
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game(seed_v)
	await wait_frames(20)   # 等世界加载 + spawn
	return main


func _check(world_size: int, label: String) -> void:
	var main = await _boot_world(world_size, 12345)
	var world = main.get_node("World")
	var player = world.get_player()
	assert_not_null(player, "%s 应有玩家" % label)
	if player == null:
		return
	for i in 150:
		if player.is_on_floor():
			break
		await wait_frames(1)
	var ptx: int = int(floor(player.global_position.x / TILE_SIZE))
	var pty: int = int(floor(player.global_position.y / TILE_SIZE))
	var cm = world.chunk_manager
	var at_feet: int = cm.get_tile(ptx, pty)
	var at_head: int = cm.get_tile(ptx, pty - 1)
	var on_floor: bool = player.is_on_floor()
	gut.p("[%s] tile=(%d,%d) feet_tile=%d head_tile=%d on_floor=%s" % [label, ptx, pty, at_feet, at_head, str(on_floor)])
	# 玩家应落在地表 (头顶空气, 站得住), 不能埋石头里 → 小地图才不会显示"玩家在地里".
	# (注: 起步三件套走 _start_game 异步路径发, boot_to_game/_start_game_sync 故意不发, 这里不验.)
	assert_eq(at_head, Tiles.AIR, "%s 玩家头顶应是空气(没埋地里), 实际 %d" % [label, at_head])
	assert_true(on_floor, "%s 玩家应站在地表 (on_floor)" % label)


func test_big_world_spawn():
	await _check(2, "大世界")
	GameSettings.current_world_size = 1


func test_small_world_spawn():
	await _check(0, "小世界")
	GameSettings.current_world_size = 1
