extends GutTest

const Player = preload("res://scenes/player/player.tscn")
const Timing = preload("res://scripts/items/original_use_timing.gd")
var player
var inv
var action

class Target extends Node2D:
	var damage_received := 0
	var hits := 0
	func take_damage(amount: int, _source := Vector2.ZERO, _knockback := 0.0) -> bool:
		damage_received += amount
		hits += 1
		return true

func before_each():
	player = Player.instantiate()
	add_child_autofree(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	inv = player.get_node("PlayerInventory")
	action = player.get_node("PlayerAction")
	action._connect_hotbar_signal()
	action.secondary_held_override = false
	action.mouse_world_override = Vector2(60, -12)
	inv.inventory.slots.fill(null)

func _equip(id: String):
	inv.inventory.slots[0] = {"item_id": id, "count": 1}
	inv.inventory_changed.emit()
	action._on_hotbar_changed(0)

func _target() -> Target:
	var target := Target.new()
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(32, 52)
	shape.position.y = -26
	target.add_child(shape)
	target.position = Vector2(22, 0)
	add_child_autofree(target)
	target.add_to_group("animals")
	return target

func test_starter_weapons_and_tools_deliver_actual_item_damage_once_per_swing():
	var target := _target()
	for entry in [["copper_dagger", 5], ["iron_sword", 12], ["gold_sword", 15], ["copper_pickaxe", 4], ["copper_axe", 3], ["gold_axe", 7], ["wood_hammer", 2], ["gold_hammer", 9]]:
		_equip(entry[0])
		target.hits = 0
		target.damage_received = 0
		action.primary_override = true
		action._physics_process(0.0)
		action.primary_override = false
		for tick in range(Timing.ANIMATION_TICKS[entry[0]]): action._physics_process(1.0 / 60.0)
		assert_eq(target.hits, 1, entry[0] + " 不能因逐帧碰撞重复扣血")
		assert_eq(target.damage_received, entry[1], entry[0])

func test_chopping_swing_can_hit_the_visible_creature():
	_equip("iron_axe")
	var target := _target()
	action._ensure_mining_swing()
	for tick in 26: action._advance_attack_clock(1.0 / 60.0)
	assert_eq(target.damage_received, 5)
	assert_eq(target.hits, 1)

func test_wood_bow_adds_arrow_damage_and_consumes_exactly_one_arrow():
	_equip("wood_bow")
	inv.pickup("wood_arrow", 2)
	var entities := Node2D.new()
	add_child_autofree(entities)
	entities.add_to_group("entities_root")
	action._try_fire_bow()
	assert_eq(entities.get_child_count(), 1)
	assert_eq(entities.get_child(0).damage, 9, "木弓 4 + 木箭 5")
	assert_eq(inv.inventory.slots[1], {"item_id": "wood_arrow", "count": 1})

func test_complete_armor_sets_and_mixed_pieces():
	for entry in [["copper", 6], ["iron", 9], ["silver", 13], ["gold", 16]]:
		for part in ["helmet", "chest", "pants"]:
			inv.set_armor(part, {"item_id": entry[0] + "_" + part, "count": 1})
		assert_eq(inv.total_defense(), entry[1], entry[0])
	inv.set_armor("helmet", {"item_id": "copper_helmet", "count": 1})
	assert_eq(inv.total_defense(), 10, "混穿铜帽和金胸腿：1 + 5 + 4，无套装奖励")
	inv.set_armor("helmet", null)
	assert_eq(inv.total_defense(), 9)

func test_inventory_tooltip_matches_real_base_damage():
	var panel = autofree(preload("res://scripts/ui/crafting_panel.gd").new())
	assert_string_contains(panel._item_tooltip("copper_axe"), "3 近战伤害")
	assert_string_contains(panel._item_tooltip("gold_sword"), "15 近战伤害")
	assert_string_contains(panel._item_tooltip("wood_bow"), "4 远程伤害")
	assert_string_contains(panel._item_tooltip("wood_arrow"), "5 远程伤害")
