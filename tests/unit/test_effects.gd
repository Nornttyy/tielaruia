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


func test_spawn_block_break_creates_chips():
	# 建一个临时 root
	var root := Node2D.new()
	root.add_to_group("effects_root")
	add_child_autofree(root)
	Effects.spawn_block_break(Vector2i(5, 5), 1)  # GRASS
	await wait_frames(1)
	assert_eq(root.get_child_count(), 6, "应生成 6 个 chip")


func test_chips_auto_free_after_lifetime():
	var root := Node2D.new()
	root.add_to_group("effects_root")
	add_child_autofree(root)
	Effects.spawn_block_break(Vector2i.ZERO, 1)
	await wait_frames(1)
	assert_eq(root.get_child_count(), 6)
	# 0.5s = 30 帧 @ 60fps; 等 40 帧确保过期
	await wait_frames(40)
	assert_eq(root.get_child_count(), 0, "chips 应自删")


func test_spawn_jump_dust_creates_4():
	var root := Node2D.new()
	root.add_to_group("effects_root")
	add_child_autofree(root)
	Effects.spawn_jump_dust(Vector2(100, 100))
	await wait_frames(1)
	assert_eq(root.get_child_count(), 4)


func test_spawn_walk_puff_creates_1():
	var root := Node2D.new()
	root.add_to_group("effects_root")
	add_child_autofree(root)
	Effects.spawn_walk_puff(Vector2(0, 0))
	await wait_frames(1)
	assert_eq(root.get_child_count(), 1)


func test_dust_auto_frees():
	var root := Node2D.new()
	root.add_to_group("effects_root")
	add_child_autofree(root)
	Effects.spawn_walk_puff(Vector2.ZERO)
	await wait_frames(1)
	assert_eq(root.get_child_count(), 1)
	await wait_frames(30)  # 0.5s
	assert_eq(root.get_child_count(), 0)
