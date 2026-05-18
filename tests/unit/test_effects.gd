extends GutTest


func test_effects_autoload_exists():
	assert_not_null(Effects)


func test_spawn_methods_do_not_crash():
	# 即使 effects_root 不存在也不应崩
	Effects.spawn_block_break(Vector2i.ZERO, 0)
	Effects.spawn_place_bounce(Vector2i.ZERO)
	Effects.spawn_jump_dust(Vector2.ZERO)
	Effects.spawn_land_dust(Vector2.ZERO)
	Effects.spawn_walk_puff(Vector2.ZERO)
	# 无 assert 失败即 PASS
	pass_test("spawn 不崩")


func test_root_falls_back_to_current_scene_when_no_group():
	# Effects._root() 应不为 null
	var root = Effects._root()
	assert_not_null(root)
