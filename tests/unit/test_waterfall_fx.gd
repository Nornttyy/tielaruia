# 落水溅水花: spawn_splash 造出蓝色水滴粒子 (够明显).
extends GutTest


func test_spawn_splash_exists_and_makes_particles():
	assert_true(Effects.has_method("spawn_splash"), "Effects 该有 spawn_splash")
	# 给粒子一个家 (effects_root) 好数
	var root := Node2D.new()
	root.add_to_group("effects_root")
	add_child_autofree(root)
	await wait_frames(1)
	var before := root.get_child_count()
	Effects.spawn_splash(Vector2(100, 100))
	assert_gt(root.get_child_count(), before, "spawn_splash 该在 effects_root 下加出水滴粒子")
