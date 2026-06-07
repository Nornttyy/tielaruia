# 角色背包跨世界: 给 current 角色放东西 → 进世界 → 角色卡留着这些东西;
# apply_to_player 还原到新 player → 背包是角色的 (跟人走)。
extends GutTest

const CharacterData = preload("res://scripts/save/character_data.gd")

func test_character_inventory_persists_across_apply():
	# 直接用 autoload CharacterManager (集成层)。备份/恢复 current 防污染。
	var saved_current = CharacterManager.current
	CharacterManager.current = CharacterData.new()
	CharacterManager.current.character_name = "测试勇者"
	CharacterManager.current.inventory_slots = [{"item_id": "magic_sword", "count": 1}]
	CharacterManager.current.player_hp = 65.0

	# 模拟「进世界 A」用的最小 player
	var p_a = _stub_player()
	get_tree().root.add_child(p_a)
	CharacterManager.apply_to_player(p_a)
	assert_eq(p_a.get_node("PlayerInventory").inventory.slots[0]["item_id"], "magic_sword",
		"世界 A 玩家拿到角色的剑")
	# 在世界 A 改了背包 (捡到金子) → 存回角色
	p_a.get_node("PlayerInventory").inventory.slots.append({"item_id": "gold", "count": 9})
	CharacterManager.save_current_from_player(p_a)
	p_a.queue_free()

	# 「进世界 B」: 新 player, 还原角色 → 背包带着剑 + 金子
	var p_b = _stub_player()
	get_tree().root.add_child(p_b)
	CharacterManager.apply_to_player(p_b)
	var slots = p_b.get_node("PlayerInventory").inventory.slots
	assert_eq(slots.size(), 2, "世界 B 背包 = 角色的 (剑+金子)")
	assert_eq(slots[1]["item_id"], "gold")
	assert_eq(p_b.get_node("PlayerHealth").current_health, 65, "血量也跟着角色")
	p_b.queue_free()

	CharacterManager.current = saved_current

func _stub_player() -> Node:
	var p = Node.new()
	p.name = "Player"
	var inv = _InvHolder.new()
	inv.name = "PlayerInventory"
	p.add_child(inv)
	var hp = _Health.new()
	hp.name = "PlayerHealth"
	p.add_child(hp)
	return p

class _InvHolder extends Node:
	var inventory = _Inv.new()
	var hotbar_selected: int = 0
	var armor_helmet = null
	var armor_chest = null
	var armor_pants = null
	signal inventory_changed
	signal hotbar_selection_changed(idx)
	func set_armor(_k, _i): pass

class _Inv:
	var slots: Array = []

class _Health extends Node:
	var current_health: int = 100
	var MAX_HEALTH: int = 100
	var BASE_MAX_HEALTH: int = 100
	var MAX_HEALTH_CAP: int = 400
	signal health_changed(c, m)
