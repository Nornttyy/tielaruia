# 吃食物行为: 满血时不能吃 (避免误点浪费), 缺血时按住 2s 进度满了吃一口.
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func _setup_game() -> Dictionary:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	var world: Node2D = main.get_node("World")
	var player: Node2D = world.get_player()
	return {
		"main": main, "world": world, "player": player,
		"action": player.get_node("PlayerAction"),
		"inv": player.get_node("PlayerInventory"),
		"hp": player.get_node("PlayerHealth"),
	}


func _equip(ctx: Dictionary, item_id: String, count: int) -> void:
	var inv: Node = ctx["inv"]
	inv.pickup(item_id, count)
	for i in inv.inventory.slots.size():
		var s = inv.inventory.slots[i]
		if s != null and s.item_id == item_id:
			inv.set_hotbar_selection(i)
			return


# 满血时按住右键: 不消耗食物, _eat_item_id 保持空
func test_full_hp_blocks_eat():
	var ctx: Dictionary = await _setup_game()
	var hp: Node = ctx["hp"]
	# 确保满血
	hp.current_health = hp.MAX_HEALTH
	_equip(ctx, "apple", 3)
	var count_before: int = ctx["inv"].inventory.slots[0].count
	ctx["action"].secondary_held_override = true
	# 等远超过 EAT_DURATION_SEC (2s) 的帧数 (200 帧 = ~3.3s)
	await wait_frames(200)
	ctx["action"].secondary_held_override = false
	var slot = ctx["inv"].inventory.slots[0]
	# slot 可能是 null (如果食物消耗光) 或 count 不变
	var count_after: int = 0 if slot == null else slot.count
	assert_eq(count_after, count_before, "满血按住右键 2s 不应消耗食物")
	# eat 状态也不应留着
	assert_eq(ctx["action"]._eat_item_id, "", "满血不进入 eating 状态")


# 半血时按住右键: 2s 后消耗 1 个食物 + 回血
func test_low_hp_allows_eat():
	var ctx: Dictionary = await _setup_game()
	var hp: Node = ctx["hp"]
	hp.current_health = 10   # 远低于 MAX_HEALTH=100
	_equip(ctx, "apple", 3)
	var count_before: int = ctx["inv"].inventory.slots[0].count
	var hp_before: int = hp.current_health
	ctx["action"].secondary_held_override = true
	await wait_frames(200)  # > 2s EAT_DURATION
	ctx["action"].secondary_held_override = false
	var slot = ctx["inv"].inventory.slots[0]
	var count_after: int = 0 if slot == null else slot.count
	assert_lt(count_after, count_before, "缺血按住 2s 应消耗至少 1 个食物")
	assert_gt(hp.current_health, hp_before, "缺血吃苹果应回血")


# 吃到一半被治疗到满血 → 立刻中断 (不消耗本次食物)
func test_heal_to_full_during_eat_cancels():
	var ctx: Dictionary = await _setup_game()
	var hp: Node = ctx["hp"]
	hp.current_health = 50
	_equip(ctx, "apple", 3)
	var count_before: int = ctx["inv"].inventory.slots[0].count
	ctx["action"].secondary_held_override = true
	# 吃几帧 (远小于 EAT_DURATION 的 120 帧)
	await wait_frames(30)
	# 中途把玩家治满
	hp.current_health = hp.MAX_HEALTH
	# 再等远超过 EAT_DURATION 的时间
	await wait_frames(200)
	ctx["action"].secondary_held_override = false
	var slot = ctx["inv"].inventory.slots[0]
	var count_after: int = 0 if slot == null else slot.count
	assert_eq(count_after, count_before, "中途回满血应中断进食, 不消耗食物")
