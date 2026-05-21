extends GutTest

const PlayerScene = preload("res://scenes/player/player.tscn")

var player: CharacterBody2D
var action: Node
var inv_node: Node
var hunger: Node


func before_each() -> void:
	player = PlayerScene.instantiate()
	add_child_autofree(player)
	action = player.get_node("PlayerAction")
	inv_node = player.get_node("PlayerInventory")
	hunger = player.get_node("PlayerHunger")
	action.aim_override = Vector2i(0, 0)


func _give_food(item_id: String, count: int, slot: int = 0) -> void:
	inv_node.inventory.slots[slot] = {"item_id": item_id, "count": count}
	inv_node.set_hotbar_selection(slot)


func _slot_count(slot: int) -> int:
	var s = inv_node.inventory.slots[slot]
	return 0 if s == null else int(s.count)


func test_eat_slime_jelly_success() -> void:
	_give_food("slime_jelly", 1)
	hunger.current = 50.0
	action.set_secondary_held_for_test(true)
	action._physics_process(1.0)
	assert_eq(int(hunger.current), 90)
	assert_eq(_slot_count(0), 0)


func test_eat_release_before_1s_cancels() -> void:
	_give_food("slime_jelly", 1)
	hunger.current = 50.0
	action.set_secondary_held_for_test(true)
	action._physics_process(0.5)
	action.set_secondary_held_for_test(false)
	action._physics_process(0.01)
	assert_between(int(hunger.current), 49, 50)
	assert_eq(_slot_count(0), 1)


func test_eat_no_op_when_full() -> void:
	_give_food("slime_jelly", 1)
	hunger.current = 100.0
	action.set_secondary_held_for_test(true)
	action._physics_process(1.0)
	assert_eq(_slot_count(0), 1)
	assert_between(int(hunger.current), 99, 100)


func test_eat_does_not_place_block() -> void:
	# food 的 placeable_tile_id == -1，try_place 内部 is_placeable 检查会 return false。
	# 饱食满后按右键不应触发放置 (也不该 crash —— 测试无 terrain)
	_give_food("slime_jelly", 1)
	hunger.current = 100.0
	action.set_secondary_held_for_test(true)
	action._physics_process(0.5)
	assert_eq(_slot_count(0), 1)


# --- T7: 攻击 Debuff ---

func test_hungry_attack_damage_reduced() -> void:
	_give_food("wood_sword", 1)
	hunger.current = 29.0
	# 木剑 base 4 → ×0.8 = 3.2 → max(1, round(3.2)) = 3
	assert_eq(action._effective_sword_damage(), 3)
	hunger.current = 30.0
	assert_eq(action._effective_sword_damage(), 4)
