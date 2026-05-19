extends GutTest

const PlayerHealthClass = preload("res://scripts/player/player_health.gd")
var hp: Node


func before_each():
	hp = PlayerHealthClass.new()
	add_child_autofree(hp)


func test_starts_full_health():
	assert_eq(hp.current_health, hp.MAX_HEALTH, "出生满血")
	assert_true(hp.is_alive())


func test_take_damage_reduces_hp():
	assert_true(hp.take_damage(5))
	assert_eq(hp.current_health, hp.MAX_HEALTH - 5)


func test_iframes_block_consecutive_damage():
	assert_true(hp.take_damage(2))
	# i-frames 内第二下没效
	assert_false(hp.take_damage(2))
	assert_eq(hp.current_health, hp.MAX_HEALTH - 2)


func test_die_emits_signal():
	var died := [false]  # 数组传递让 lambda 能改
	hp.died.connect(func(): died[0] = true)
	hp.take_damage(hp.MAX_HEALTH * 2)
	assert_eq(hp.current_health, 0)
	assert_true(died[0], "died 信号发出")
	assert_false(hp.is_alive())


func test_heal_does_not_exceed_max():
	hp.take_damage(3)
	hp.heal(100)
	assert_eq(hp.current_health, hp.MAX_HEALTH)


func test_dead_cannot_take_more_damage():
	hp.take_damage(hp.MAX_HEALTH * 2)
	var changed_emits := 0
	hp.health_changed.connect(func(_a, _b): changed_emits += 1)
	hp.take_damage(5)
	assert_eq(changed_emits, 0, "死后不再受伤也不再发信号")


func test_revive_full_restores_hp():
	hp.take_damage(hp.MAX_HEALTH * 2)
	hp.revive_full()
	assert_eq(hp.current_health, hp.MAX_HEALTH)
	assert_true(hp.is_alive())
