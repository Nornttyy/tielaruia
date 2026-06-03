# 骷髅王 Boss 验收 (Phase 1: 本体)
extends GutTest

const SkeletonKingScene = preload("res://scenes/entities/skeleton_king.tscn")
const MainScene = preload("res://scenes/main.tscn")


func _setup_game() -> Dictionary:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	var world: Node2D = main.get_node("World")
	var player: Node2D = world.get_player()
	return {"main": main, "world": world, "player": player,
		"action": player.get_node("PlayerAction"), "inv": player.get_node("PlayerInventory")}


func _equip(ctx: Dictionary, item_id: String) -> void:
	var inv: Node = ctx["inv"]
	inv.pickup(item_id, 1)
	for i in inv.inventory.slots.size():
		var s = inv.inventory.slots[i]
		if s != null and s.item_id == item_id:
			inv.set_hotbar_selection(i)
			return


func test_base_stats() -> void:
	var boss = SkeletonKingScene.instantiate()
	add_child_autofree(boss)
	await wait_frames(1)
	var expected := int(round(1200 * GameSettings.enemy_hp_multiplier()))
	assert_eq(boss.max_health, expected, "Boss HP = 1200 × 难度倍率")
	assert_eq(boss.CONTACT_DAMAGE, 15, "接触伤害 15")
	assert_true(boss.is_in_group("skeleton_king"), "应在 skeleton_king 组")
	assert_true(boss.is_in_group("boss"), "应在 boss 组 (顶部血条靠这个)")
	assert_eq(boss.boss_display_name(), "骷髅王", "血条名 = 骷髅王")


func test_drops_bone_and_bone_sword_on_death() -> void:
	var boss = SkeletonKingScene.instantiate()
	add_child_autofree(boss)
	await wait_frames(1)
	var before := get_tree().get_nodes_in_group("item_drops").size()
	boss.take_damage(boss.max_health, boss.global_position, 0.0)
	await wait_frames(2)
	var drops := get_tree().get_nodes_in_group("item_drops")
	assert_gt(drops.size(), before, "Boss 死该掉东西")
	var has_sword := false
	var bone_count := 0
	for d in drops:
		if "item_id" in d:
			if d.item_id == "bone_sword":
				has_sword = true
			elif d.item_id == "bone":
				bone_count += 1
	assert_true(has_sword, "Boss 该掉 bone_sword (骨剑, 必掉奖励)")
	assert_gt(bone_count, 0, "Boss 该掉一堆骨头")


func test_takes_damage() -> void:
	var boss = SkeletonKingScene.instantiate()
	add_child_autofree(boss)
	await wait_frames(1)
	var before: int = boss.current_health
	var ok: bool = boss.take_damage(100, boss.global_position + Vector2(20, 0), 0.0)
	assert_true(ok, "能被打到")
	assert_eq(boss.current_health, before - 100, "扣 100 血")


func test_despawns_when_player_far() -> void:
	var boss = SkeletonKingScene.instantiate()
	add_child_autofree(boss)
	boss.global_position = Vector2(0, 0)
	await wait_frames(1)
	boss._far_timer = boss.DESPAWN_AFTER_SEC + 1.0
	boss._check_despawn(0.1)
	await wait_frames(2)
	assert_false(is_instance_valid(boss) and not boss._is_dying, "远离超时该消失 (不掉落)")


# T4: 头骨召唤 — 右键骷髅头骨 → 真召唤出骷髅王 (不是史莱姆王) + 消耗 1
func test_skull_summon_spawns_skeleton_king_and_consumes() -> void:
	var ctx: Dictionary = await _setup_game()
	_equip(ctx, "skull_summon")
	var before := get_tree().get_nodes_in_group("skeleton_king").size()
	var ok: bool = ctx["action"].try_use_summon_item()
	await wait_frames(2)
	assert_true(ok, "骷髅头骨召唤应成功")
	assert_eq(get_tree().get_nodes_in_group("skeleton_king").size(), before + 1, "应出现 1 个骷髅王")
	# 不能错召唤成史莱姆王
	assert_eq(get_tree().get_nodes_in_group("king_slime").size(), 0, "召的是骷髅王, 不是史莱姆王")
	var slot = ctx["inv"].current_hotbar_slot()
	assert_true(slot == null or slot.item_id != "skull_summon", "头骨应被消耗")


func test_no_double_skeleton_king() -> void:
	var ctx: Dictionary = await _setup_game()
	_equip(ctx, "skull_summon")
	ctx["action"].try_use_summon_item()
	await wait_frames(2)
	_equip(ctx, "skull_summon")
	var ok2: bool = ctx["action"].try_use_summon_item()
	assert_false(ok2, "已有骷髅王时不该再召唤")
	assert_eq(get_tree().get_nodes_in_group("skeleton_king").size(), 1, "场上只 1 个骷髅王")
