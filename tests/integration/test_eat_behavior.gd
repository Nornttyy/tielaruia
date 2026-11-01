# 消耗品短动作、食物增益与治疗冷却；不启动大地图，不触碰存档。
extends GutTest
const PlayerScene = preload("res://scenes/player/player.tscn")
var player: CharacterBody2D
var action: Node
var inventory: Node
var health: Node
var buffs: Node
func before_each():
	player = PlayerScene.instantiate()
	add_child_autofree(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	action = player.get_node("PlayerAction")
	inventory = player.get_node("PlayerInventory")
	health = player.get_node("PlayerHealth")
	buffs = player.get_node("PlayerBuffs")
	action.secondary_held_override = false
	action.primary_override = false
	inventory.inventory.slots.fill(null)
func equip(id: String):
	inventory.inventory.slots[0] = {"item_id": id, "count": 3}
	inventory.set_hotbar_selection(0)
	inventory.inventory_changed.emit()
func tick(n: int):
	for i in n: action._physics_process(1.0 / 60.0)
func test_single_click_finishes_food_use_after_release_without_healing():
	equip("apple")
	health.current_health = 40
	action.primary_override = true
	tick(1)
	action.primary_override = false
	tick(15)
	assert_eq(inventory.inventory.slots[0].count, 3)
	tick(1)
	assert_eq(inventory.inventory.slots[0].count, 2)
	assert_eq(health.current_health, 40, "水果提供饱食增益，不直接回血")
	assert_true(buffs.is_active("well_fed"))
	assert_almost_eq(buffs.remaining("well_fed"), 300.0, 0.01)
func test_full_health_can_eat_once_but_holding_does_not_repeat():
	equip("apple")
	health.current_health = health.MAX_HEALTH
	action.primary_override = true
	tick(180)
	assert_eq(inventory.inventory.slots[0].count, 2)
	assert_true(buffs.is_active("well_fed"))
func test_mushroom_heals_fifteen_and_blocks_next_healing_use():
	equip("mushroom")
	health.current_health = 20
	action.primary_override = true
	tick(17)
	assert_eq(health.current_health, 35)
	assert_true(buffs.is_active("potion_sickness"))
	action.primary_override = false
	tick(1)
	action.primary_override = true
	tick(17)
	assert_eq(inventory.inventory.slots[0].count, 2)
	assert_eq(health.current_health, 35)
func test_latest_food_replaces_previous_food_tier():
	buffs.apply("well_fed", 300.0)
	buffs.apply("exquisitely_stuffed", 900.0)
	assert_false(buffs.is_active("well_fed"))
	assert_eq(buffs.defense_bonus(), 4)
	assert_almost_eq(buffs.speed_mul(), 1.4, 0.0001)
	buffs.apply("plenty_satisfied", 480.0)
	assert_false(buffs.is_active("exquisitely_stuffed"))
	assert_eq(buffs.defense_bonus(), 3)
func test_raw_fish_are_ingredients_and_full_mana_does_not_waste_potion():
	assert_false(ItemDB.is_food("salmon"))
	assert_false(ItemDB.is_food("tuna"))
	equip("mana_potion")
	var mana = player.get_node("PlayerMana")
	mana.current_mana = mana.MAX_MANA
	action.primary_override = true
	tick(17)
	assert_eq(inventory.inventory.slots[0].count, 3)
