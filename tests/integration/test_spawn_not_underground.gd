# 回归: 玩家出生点必须在地表附近, 绝不钻进地下洞穴/地狱.
# 老 bug: 地表被水淹 (湖/海) 或顶层非草时, _find_spawn_in_loaded 一路下钻到地下洞穴底,
# 把洞穴当出生点 (seed=100→y228 地狱, seed=88888→y251 基岩). 见 world.gd _find_spawn_in_loaded.
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const HELL_Y := 220          # 这往下算地狱
const SURFACE_MAX_Y := 180   # 出生点 y 不该比这更深 (地表带 ~87..143, 留足余量)


# 该列从顶往下第一个实心方块 y = 真地表
func _ground_y(cm, x: int) -> int:
	for y in range(3, 254):
		if Tiles.is_solid(cm.get_tile(x, y)):
			return y
	return -1


func _check_seed(sd: int) -> void:
	var main = MainScene.instantiate()
	add_child(main)
	main.boot_to_game(sd)
	await wait_frames(2)
	var world = main.get_node("World")
	var cm = world.chunk_manager
	var sp = world.spawn_point
	var gy = _ground_y(cm, sp.x)
	# 1) 绝不在地狱
	assert_lt(sp.y, HELL_Y, "seed=%d 出生点 y=%d 掉进地狱区 (>=%d)" % [sd, sp.y, HELL_Y])
	# 2) 在合理地表带内
	assert_lt(sp.y, SURFACE_MAX_Y, "seed=%d 出生点 y=%d 太深 (应 <%d)" % [sd, sp.y, SURFACE_MAX_Y])
	# 3) 出生点正好在真地表上方 (脚下几格内有实心地面接住)
	assert_true(gy >= 0 and gy - sp.y >= 0 and gy - sp.y <= 4,
		"seed=%d 出生 y=%d 离真地表 y=%d 太远 (该站地表正上方)" % [sd, sp.y, gy])
	main.queue_free()
	await wait_frames(2)


func test_flooded_surface_seeds_spawn_on_top() -> void:
	for sd in [100, 88888]:
		await _check_seed(sd)


func test_normal_seeds_still_ok() -> void:
	for sd in [42, 1, 2024]:
		await _check_seed(sd)
