# 骷髅法杖 (Phase 3): 召唤友方小骷髅帮打怪。
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const FriendlySkelScene = preload("res://scenes/entities/friendly_skeleton.tscn")
const SlimeScene = preload("res://scenes/entities/slime.tscn")


func _setup() -> Dictionary:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	var world: Node2D = main.get_node("World")
	var player: Node2D = world.get_player()
	return {"main": main, "world": world, "player": player,
		"action": player.get_node("PlayerAction"), "inv": player.get_node("PlayerInventory")}


func _equip(ctx: Dictionary, id: String) -> void:
	var inv: Node = ctx["inv"]
	inv.pickup(id, 1)
	for i in inv.inventory.slots.size():
		var s = inv.inventory.slots[i]
		if s != null and s.item_id == id:
			inv.set_hotbar_selection(i)
			return


func test_skull_staff_def() -> void:
	var def = ItemDB.get_def("skull_staff")
	assert_not_null(def, "骷髅法杖应存在")
	assert_eq(def.tool_kind, "staff", "是法杖类")
	assert_true(def.get("summons_minion", false), "骷髅法杖召唤小兵 (不发火球)")
	assert_not_null(ArtCache.get_inventory_icon("skull_staff"), "骷髅法杖应有图标")


func test_skull_staff_summons_friendly() -> void:
	var ctx: Dictionary = await _setup()
	_equip(ctx, "skull_staff")
	var before := get_tree().get_nodes_in_group("friendly_minions").size()
	ctx["action"]._attack_cooldown = 0.0
	ctx["action"].primary_override = true
	await wait_frames(3)
	ctx["action"].primary_override = false
	assert_gt(get_tree().get_nodes_in_group("friendly_minions").size(), before, "骷髅法杖该召唤出友方骷髅")


func test_friendly_skeleton_damages_enemy_not_player() -> void:
	var ctx: Dictionary = await _setup()
	var slime = SlimeScene.instantiate()
	ctx["world"].add_child(slime)
	slime.global_position = ctx["player"].global_position + Vector2(40, 0)
	await wait_frames(1)
	var fs = FriendlySkelScene.instantiate()
	ctx["world"].add_child(fs)
	fs.global_position = slime.global_position + Vector2(-6, 0)   # 贴着 slime
	await wait_frames(1)
	var slime_before: int = slime.current_health
	var player_hp: Node = ctx["player"].get_node("PlayerHealth")
	var player_before: int = player_hp.current_health
	await wait_frames(10)
	assert_lt(slime.current_health, slime_before, "友方骷髅该打敌怪 (slime) 扣血")
	assert_eq(player_hp.current_health, player_before, "友方骷髅不该打玩家")
