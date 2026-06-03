# 骷髅王 Boss 验收 (Phase 1: 本体)
extends GutTest

const SkeletonKingScene = preload("res://scenes/entities/skeleton_king.tscn")


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
