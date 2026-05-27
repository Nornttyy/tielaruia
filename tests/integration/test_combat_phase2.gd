# 战斗机制阶段 2 验收: 击退 + 无敌帧
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const SlimeScene = preload("res://scenes/entities/slime.tscn")


func _setup_game() -> Dictionary:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	var world: Node2D = main.get_node("World")
	var player: Node2D = world.get_player()
	return {
		"main": main,
		"world": world,
		"player": player,
		"action": player.get_node("PlayerAction"),
		"inv": player.get_node("PlayerInventory"),
	}


func _equip_tool(ctx: Dictionary, item_id: String) -> void:
	var inv: Node = ctx["inv"]
	inv.pickup(item_id, 1)
	for i in inv.inventory.slots.size():
		var s = inv.inventory.slots[i]
		if s != null and s.item_id == item_id:
			inv.set_hotbar_selection(i)
			return


func _spawn_slime_near(ctx: Dictionary, offset: Vector2) -> Node2D:
	var slime = SlimeScene.instantiate()
	ctx["world"].add_child(slime)
	slime.global_position = ctx["player"].global_position + offset
	return slime


# T2: 0.2s i-frame 内的第 2 次伤害应被拒
func test_enemy_iframe_blocks_multi_hit() -> void:
	var ctx: Dictionary = await _setup_game()
	var slime = _spawn_slime_near(ctx, Vector2(24, 0))
	var hp0: int = slime.current_health
	var src: Vector2 = ctx["player"].global_position
	var ok1: bool = slime.take_damage(5, src)
	var ok2: bool = slime.take_damage(5, src)   # 立刻第 2 次 → iframe 中
	assert_true(ok1, "第 1 次应成功")
	assert_false(ok2, "iframe 期间第 2 次应返回 false")
	assert_eq(slime.current_health, hp0 - 5, "i-frame 内只应扣 1 次 5 血")
