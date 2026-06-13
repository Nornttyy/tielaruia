# 省带宽: 实体广播距离裁剪 + 没动不重发 (心跳强制全发). 这里验裁剪 helper + 广播不崩。
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func _boot() -> Node:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	return main


func test_cull_far_from_players():
	var main = await _boot()
	var world = main.get_node("World")
	var pp: Vector2 = world.get_player().global_position
	var pps: Array = [pp]
	assert_false(world._too_far_from_players(pp + Vector2(100, 0), pps), "近处实体该广播 (不裁)")
	assert_true(world._too_far_from_players(pp + Vector2(4000, 0), pps), "远处实体该裁掉 (不广播)")
	assert_false(world._too_far_from_players(pp + Vector2(9999, 0), []), "没玩家 → 不裁 (照发)")


func test_all_player_positions_includes_local():
	var main = await _boot()
	var world = main.get_node("World")
	var pps: Array = world._all_player_positions()
	assert_gte(pps.size(), 1, "至少含本地玩家位置")


# 广播跑得通 (心跳全发 + 增量都不崩); 第二次没动应记进 _last_ent_sent
func test_broadcast_runs_and_tracks():
	var main = await _boot()
	var world = main.get_node("World")
	world._mp_broadcast_entities(true)    # 心跳全发
	world._mp_broadcast_entities(false)   # 增量 (没动)
	assert_true(world._last_ent_sent is Dictionary, "有上次发送记录表")
