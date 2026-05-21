extends GutTest

const PlayerHunger = preload("res://scripts/player/player_hunger.gd")

var hunger: Node


class MockHealth:
	extends Node
	const MAX_HEALTH := 20
	var current_health: int = 10
	var _alive: bool = true

	func is_alive() -> bool:
		return _alive

	func heal(amount: int) -> void:
		current_health = min(MAX_HEALTH, current_health + amount)


func before_each() -> void:
	hunger = PlayerHunger.new()
	add_child_autofree(hunger)


func test_initial_full() -> void:
	assert_eq(int(hunger.current), PlayerHunger.MAX)


func test_deplete_one_minute() -> void:
	for _i in 60:
		hunger._physics_process(1.0)
	assert_between(int(hunger.current), 89, 91)


func test_consume_clamps_to_max() -> void:
	hunger.current = 80.0
	hunger.consume(30)
	assert_eq(int(hunger.current), 100)


func test_consume_normal() -> void:
	hunger.current = 50.0
	hunger.consume(30)
	assert_eq(int(hunger.current), 80)


func test_consume_zero_or_negative_noop() -> void:
	hunger.current = 50.0
	hunger.consume(0)
	assert_eq(int(hunger.current), 50)
	hunger.consume(-5)
	assert_eq(int(hunger.current), 50)


func test_attack_multiplier_threshold() -> void:
	hunger.current = 29.0
	assert_eq(hunger.get_attack_multiplier(), 0.8)
	hunger.current = 30.0
	assert_eq(hunger.get_attack_multiplier(), 1.0)
	hunger.current = 100.0
	assert_eq(hunger.get_attack_multiplier(), 1.0)


func test_refill_full_emits_signal() -> void:
	hunger.current = 20.0
	hunger.emit_state()  # 同步到 _last_emit_int = 20
	watch_signals(hunger)
	hunger.refill_full()
	assert_eq(int(hunger.current), 100)
	assert_signal_emitted(hunger, "hunger_changed")


func test_is_hungry() -> void:
	hunger.current = 29.0
	assert_true(hunger.is_hungry())
	hunger.current = 30.0
	assert_false(hunger.is_hungry())


func test_signal_only_on_integer_cross() -> void:
	hunger.current = 50.5
	hunger.emit_state()  # int(50.5)=50; _last_emit_int = 50
	watch_signals(hunger)
	# 0.01s 衰减 ~0.0017，仍在 50.498 附近，int 不变 → 不应 emit
	hunger._physics_process(0.01)
	assert_signal_emit_count(hunger, "hunger_changed", 0)


# --- 回血相关 ---

func test_heal_when_well_fed() -> void:
	var mh := MockHealth.new()
	add_child_autofree(mh)
	hunger.set_health_node_for_test(mh)
	hunger.current = 90.0
	mh.current_health = 10
	hunger._physics_process(5.0)
	assert_eq(mh.current_health, 11)


func test_no_heal_when_hungry() -> void:
	var mh := MockHealth.new()
	add_child_autofree(mh)
	hunger.set_health_node_for_test(mh)
	hunger.current = 70.0
	mh.current_health = 10
	hunger._physics_process(5.0)
	assert_eq(mh.current_health, 10)


func test_no_heal_when_full_hp() -> void:
	var mh := MockHealth.new()
	add_child_autofree(mh)
	hunger.set_health_node_for_test(mh)
	hunger.current = 90.0
	mh.current_health = 20  # 满
	hunger._physics_process(5.0)
	assert_eq(mh.current_health, 20)
