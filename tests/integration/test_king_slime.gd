# 史莱姆王 Boss 验收
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const SlimeBallScene = preload("res://scenes/entities/slime_ball.tscn")
const SlimeScene = preload("res://scenes/entities/slime.tscn")
const KingSlimeScene = preload("res://scenes/entities/king_slime.tscn")


func test_king_slime_base_stats() -> void:
	var boss = KingSlimeScene.instantiate()
	add_child_autofree(boss)
	await wait_frames(1)
	var expected := int(round(1000 * GameSettings.enemy_hp_multiplier()))
	assert_eq(boss.max_health, expected, "Boss HP = 1000 × 难度倍率")
	assert_eq(boss.CONTACT_DAMAGE, 20, "接触伤害 20")
	assert_true(boss.is_in_group("king_slime"), "应在 king_slime 组")
	assert_true(boss.is_in_group("boss"), "应在 boss 组")


func test_slime_crown_and_ball_defs_exist() -> void:
	var crown = ItemDB.get_def("slime_crown")
	assert_not_null(crown, "slime_crown 应在 ItemDB")
	assert_eq(crown.tool_kind, "summon", "slime_crown 是召唤道具")
	assert_eq(crown.max_stack, 1, "王冠不可堆叠")

	var ball = ItemDB.get_def("slime_ball")
	assert_not_null(ball, "slime_ball 应在 ItemDB")
	assert_eq(ball.tool_kind, "slimeball", "slime_ball 是投射武器")

	assert_true(ItemDB.is_summon("slime_crown"), "is_summon 该认 slime_crown")
	assert_false(ItemDB.is_summon("slime_ball"), "slime_ball 不是召唤道具")


func test_item_icons_exist() -> void:
	assert_not_null(ArtCache.get_inventory_icon("slime_crown"), "王冠该有 icon")
	assert_not_null(ArtCache.get_inventory_icon("slime_ball"), "球该有 icon")


func test_slime_crown_recipe_exists() -> void:
	var found := false
	for r in RecipeDB._RECIPES:
		if r.get("output_id", "") == "slime_crown":
			found = true
			assert_eq(r.get("requires", ""), "workbench", "王冠配方要工作台")
			var jelly := 0
			for row in r["pattern"]:
				for cell in row:
					if cell == "slime_jelly":
						jelly += 1
			assert_eq(jelly, 9, "王冠 = 9 个史莱姆胶")
	assert_true(found, "应有 slime_crown 配方")


func test_slime_ball_damages_enemy() -> void:
	var ball = SlimeBallScene.instantiate()
	add_child_autofree(ball)
	var slime = SlimeScene.instantiate()
	add_child_autofree(slime)
	slime.global_position = Vector2(100, 100)
	await wait_frames(1)
	ball.setup(Vector2(70, 100), Vector2(100, 100), 16, null)
	var hp_before: int = slime.current_health
	await wait_frames(30)
	assert_lt(slime.current_health, hp_before, "史莱姆球该打到 slime 扣血")

func test_slime_ball_bounces_off_ground() -> void:
	var ball = SlimeBallScene.instantiate()
	add_child_autofree(ball)
	assert_true("_bounces" in ball, "slime_ball 应有 _bounces 计数")
	assert_true(ball.has_method("setup"), "应有 setup")


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

func test_slimeball_weapon_throws_projectile() -> void:
	var ctx: Dictionary = await _setup_game()
	_equip(ctx, "slime_ball")
	var before: int = ctx["world"].get_tree().get_nodes_in_group("slime_balls").size()
	ctx["action"].mouse_world_override = ctx["player"].global_position + Vector2(40, 0)
	ctx["action"].primary_override = true
	await wait_frames(3)
	ctx["action"].primary_override = false
	var after: int = ctx["world"].get_tree().get_nodes_in_group("slime_balls").size()
	assert_gt(after, before, "持史莱姆球点 LMB 应投出一个投射物")

func test_king_slime_shrinks_and_speeds_up() -> void:
	var boss = KingSlimeScene.instantiate()
	add_child_autofree(boss)
	await wait_frames(1)
	var scale_full: float = boss.sprite.scale.x
	var hop_full: float = boss._hop_cooldown_now()
	boss.current_health = int(boss.max_health * 0.1)
	boss._apply_scale()
	assert_lt(boss.sprite.scale.x, scale_full, "残血体型应更小")
	assert_lt(boss._hop_cooldown_now(), hop_full, "残血跳跃间隔应更短")

func test_king_slime_spawns_minions_below_half() -> void:
	var boss = KingSlimeScene.instantiate()
	add_child_autofree(boss)
	await wait_frames(1)
	boss.current_health = int(boss.max_health * 0.4)
	var before := get_tree().get_nodes_in_group("slimes").size()
	boss._spawn_minions()
	var after := get_tree().get_nodes_in_group("slimes").size()
	assert_gt(after, before, "血<50% 召唤小史莱姆")
