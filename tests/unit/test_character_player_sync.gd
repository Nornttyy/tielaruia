extends GutTest

const CharacterData = preload("res://scripts/save/character_data.gd")
const CharacterManager = preload("res://scripts/save/character_manager.gd")

var cm

func before_each():
	cm = CharacterManager.new()

func after_each():
	cm.free()

# --- 最小 stub player: 一个 Node 带 PlayerInventory/PlayerHealth/PlayerMana 子节点 ---
class StubInventoryHolder extends Node:
	var inventory = StubInv.new()
	var hotbar_selected: int = 0
	var armor_helmet = null
	var armor_chest = null
	var armor_pants = null
	signal inventory_changed
	signal hotbar_selection_changed(idx)
	func set_armor(kind: String, item: Dictionary) -> void:
		if kind == "helmet": armor_helmet = item
		elif kind == "chest": armor_chest = item
		elif kind == "pants": armor_pants = item
	func pickup(_id: String, _n: int) -> void:
		pass

class StubInv:
	var slots: Array = []

class StubHealth extends Node:
	var current_health: int = 100
	var MAX_HEALTH: int = 100
	var BASE_MAX_HEALTH: int = 100
	var MAX_HEALTH_CAP: int = 400
	signal health_changed(cur, mx)

class StubMana extends Node:
	var current_mana: int = 100
	var MAX_MANA: int = 100
	signal mana_changed(cur, mx)

func _make_player() -> Node:
	var p = Node.new()
	p.name = "Player"
	var inv = StubInventoryHolder.new()
	inv.name = "PlayerInventory"
	p.add_child(inv)
	var hp = StubHealth.new()
	hp.name = "PlayerHealth"
	p.add_child(hp)
	var mn = StubMana.new()
	mn.name = "PlayerMana"
	p.add_child(mn)
	return p

func test_save_current_collects_player_state():
	cm.current = CharacterData.new()
	var p = _make_player()
	p.get_node("PlayerInventory").inventory.slots = [{"item_id": "gold", "count": 5}, null]
	p.get_node("PlayerInventory").hotbar_selected = 3
	p.get_node("PlayerInventory").armor_chest = {"item_id": "iron_chestplate", "count": 1}
	p.get_node("PlayerHealth").current_health = 42
	p.get_node("PlayerHealth").MAX_HEALTH = 180
	p.get_node("PlayerMana").current_mana = 33
	p.get_node("PlayerMana").MAX_MANA = 150
	assert_true(cm.save_current_from_player(p), "收集成功")
	assert_eq(cm.current.inventory_slots.size(), 2)
	assert_eq(cm.current.inventory_slots[0]["item_id"], "gold")
	assert_eq(cm.current.hotbar_selection, 3)
	assert_eq(cm.current.armor_chest_id, "iron_chestplate")
	assert_eq(cm.current.player_hp, 42.0)
	assert_eq(cm.current.player_max_hp, 180)
	assert_eq(cm.current.player_mana, 33)
	assert_eq(cm.current.player_max_mana, 150)
	p.free()

func test_save_current_returns_false_when_no_current():
	cm.current = null
	var p = _make_player()
	assert_false(cm.save_current_from_player(p), "没 current 不收集")
	p.free()

func test_save_current_returns_false_when_inventory_not_ready():
	# 加载窗口期护栏: inventory 为 null 不写 (防丢三件套)。
	cm.current = CharacterData.new()
	var p = _make_player()
	p.get_node("PlayerInventory").inventory = null
	assert_false(cm.save_current_from_player(p), "inventory 未就绪不收集")
	p.free()

func test_apply_to_player_restores_state():
	cm.current = CharacterData.new()
	cm.current.inventory_slots = [{"item_id": "wood", "count": 10}]
	cm.current.hotbar_selection = 2
	cm.current.armor_helmet_id = "iron_helmet"
	cm.current.player_hp = 55.0
	cm.current.player_max_hp = 200
	cm.current.player_mana = 60
	cm.current.player_max_mana = 140
	var p = _make_player()
	cm.apply_to_player(p)
	var inv = p.get_node("PlayerInventory")
	assert_eq(inv.inventory.slots.size(), 1)
	assert_eq(inv.inventory.slots[0]["item_id"], "wood")
	assert_eq(inv.hotbar_selected, 2)
	assert_eq(inv.armor_helmet["item_id"], "iron_helmet")
	assert_eq(p.get_node("PlayerHealth").current_health, 55)
	assert_eq(p.get_node("PlayerHealth").MAX_HEALTH, 200)
	assert_eq(p.get_node("PlayerMana").current_mana, 60)
	assert_eq(p.get_node("PlayerMana").MAX_MANA, 140)
	p.free()

func test_round_trip_player_to_character_to_player():
	cm.current = CharacterData.new()
	var p1 = _make_player()
	p1.get_node("PlayerInventory").inventory.slots = [{"item_id": "diamond", "count": 7}]
	p1.get_node("PlayerHealth").current_health = 88
	cm.save_current_from_player(p1)
	p1.free()
	var p2 = _make_player()
	cm.apply_to_player(p2)
	assert_eq(p2.get_node("PlayerInventory").inventory.slots[0]["item_id"], "diamond")
	assert_eq(p2.get_node("PlayerHealth").current_health, 88)
	p2.free()


# 修 bug: 空角色卡 (全新角色/没存过) 不该抹掉玩家已有背包 (读档丢三件套/拿不了方块)
func test_apply_empty_card_keeps_existing_inventory():
	cm.current = CharacterData.new()
	cm.current.inventory_slots = []   # 空卡
	var p = _make_player()
	p.get_node("PlayerInventory").inventory.slots = [{"item_id": "stone", "count": 9}, null]
	cm.apply_to_player(p)
	var slots = p.get_node("PlayerInventory").inventory.slots
	assert_eq(slots.size(), 2, "空卡不该清空背包")
	assert_eq(slots[0]["item_id"], "stone", "玩家原有物品该保留")
	p.free()

func test_apply_card_with_items_still_overwrites():
	cm.current = CharacterData.new()
	cm.current.inventory_slots = [{"item_id": "gold", "count": 3}]
	var p = _make_player()
	p.get_node("PlayerInventory").inventory.slots = [{"item_id": "stone", "count": 9}]
	cm.apply_to_player(p)
	assert_eq(p.get_node("PlayerInventory").inventory.slots[0]["item_id"], "gold", "有东西的卡正常覆盖")
	p.free()
