extends GutTest

const BuffsClass = preload("res://scripts/player/player_buffs.gd")
var buffs

func before_each():
	buffs = BuffsClass.new()
	add_child_autofree(buffs)

func test_apply_and_active():
	buffs.apply("speed", 5.0)
	assert_true(buffs.is_active("speed"))
	assert_almost_eq(buffs.speed_mul(), buffs.SPEED_MUL, 0.001)

func test_expire():
	buffs.apply("speed", 1.0)
	buffs._process(1.1)        # 超时
	assert_false(buffs.is_active("speed"))
	assert_almost_eq(buffs.speed_mul(), 1.0, 0.001)

func test_refresh_same_kind():
	buffs.apply("jump", 2.0)
	buffs._process(1.5)
	buffs.apply("jump", 2.0)   # 刷新
	buffs._process(1.0)        # 距刷新才 1s, 仍在
	assert_true(buffs.is_active("jump"))

func test_different_kinds_stack():
	buffs.apply("speed", 5.0)
	buffs.apply("mining", 5.0)
	assert_true(buffs.is_active("speed"))
	assert_true(buffs.is_active("mining"))
	assert_almost_eq(buffs.mining_mul(), buffs.MINING_MUL, 0.001)

func test_muls_default_one():
	assert_almost_eq(buffs.speed_mul(), 1.0, 0.001)
	assert_almost_eq(buffs.jump_mul(), 1.0, 0.001)
	assert_almost_eq(buffs.mining_mul(), 1.0, 0.001)

func test_remaining_frac():
	buffs.apply("speed", 4.0)
	buffs._process(1.0)
	assert_almost_eq(buffs.remaining_frac("speed"), 0.75, 0.02)
