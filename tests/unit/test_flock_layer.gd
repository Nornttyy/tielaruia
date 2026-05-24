extends GutTest

const FlockLayer = preload("res://scripts/world/flock_layer.gd")


func test_setup_bird_then_spawn():
	var fl = FlockLayer.new()
	add_child_autofree(fl)
	fl.setup_bird()
	await wait_frames(1)
	fl.modulate.a = 1.0
	fl.spawn_one_for_test()
	await wait_frames(1)
	assert_gt(fl.flock_count(), 0, "spawn 后应有鸟")


func test_setup_bat_then_spawn():
	var fl = FlockLayer.new()
	add_child_autofree(fl)
	fl.setup_bat()
	await wait_frames(1)
	fl.modulate.a = 1.0
	fl.spawn_one_for_test()
	await wait_frames(1)
	assert_gt(fl.flock_count(), 0, "spawn 后应有蝠")


func test_hidden_no_spawn_in_process():
	# alpha=0 时 _process 不应触发 spawn
	var fl = FlockLayer.new()
	add_child_autofree(fl)
	fl.setup_bird()
	fl.modulate.a = 0.0
	await wait_frames(5)
	# 没人触发 force-spawn, alpha=0 应不产生 sprite
	assert_eq(fl.flock_count(), 0, "alpha=0 时不该 spawn")
