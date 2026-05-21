extends GutTest

const PlayerHunger = preload("res://scripts/player/player_hunger.gd")

var hunger: Node

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
    # Skip any initial state tracking
    var old_val = hunger._last_emit_int
    hunger._last_emit_int = 20  # Match current state so no signal on watch_signals
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
    hunger.current = 50.0
    hunger._last_emit_int = 50  # Match current state
    watch_signals(hunger)
    hunger._physics_process(0.01)
    assert_signal_emit_count(hunger, "hunger_changed", 0)
