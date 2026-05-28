# 战斗机制阶段 1 验收: 工具差异化 (剑戳挥 / 镐 AoE / 斧零伤害 / 弧形扫击)
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const SlimeScene = preload("res://scenes/entities/slime.tscn")


# 启动 main + 返回 player/action/inv 等节点引用
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


# 给 inventory 加工具 + 切到那个 slot
func _equip_tool(ctx: Dictionary, item_id: String) -> void:
	var inv: Node = ctx["inv"]
	inv.pickup(item_id, 1)
	for i in inv.inventory.slots.size():
		var s = inv.inventory.slots[i]
		if s != null and s.item_id == item_id:
			inv.set_hotbar_selection(i)
			return


# 在 player 旁边 spawn 一只 slime, 返回 slime
func _spawn_slime_near(ctx: Dictionary, offset: Vector2) -> Node2D:
	var slime = SlimeScene.instantiate()
	ctx["world"].add_child(slime)
	slime.global_position = ctx["player"].global_position + offset
	return slime


func test_axe_zero_damage_on_enemies() -> void:
	var ctx: Dictionary = await _setup_game()
	_equip_tool(ctx, "wood_axe")
	var slime = _spawn_slime_near(ctx, Vector2(12, 0))
	var hp_before: int = slime.current_health
	ctx["action"].mouse_world_override = slime.global_position
	ctx["action"].primary_override = true
	await wait_frames(20)
	ctx["action"].primary_override = false
	assert_eq(slime.current_health, hp_before, "斧打 slime 不应该扣血")


# T9: 镐 360° AoE — 玩家四周 4 方向各放 1 只 slime 都扣血
func test_pickaxe_aoe_360() -> void:
	var ctx: Dictionary = await _setup_game()
	_equip_tool(ctx, "wood_pickaxe")
	# SWORD_RANGE_PX = 36, AoE 半径 = 36*1.5 = 54. 用 36*1.4 = 50.4 < 54, 安全在内
	var r: float = 27.0 * 1.4
	var slimes: Array = []
	for offset in [Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
		slimes.append(_spawn_slime_near(ctx, offset))
	var hps_before: Array = []
	for s in slimes:
		hps_before.append(s.current_health)
	ctx["action"].mouse_world_override = slimes[0].global_position
	ctx["action"]._attack_cooldown = 0.0
	ctx["action"].primary_override = true
	await wait_frames(3)
	ctx["action"].primary_override = false
	for i in range(slimes.size()):
		assert_lt(slimes[i].current_health, hps_before[i], "方向 %d slime 应扣血 (360° AoE)" % i)


# T9: 镐伤害 = 同 tier 剑伤害的 50% (向下取整)
func test_pickaxe_damage_is_half_of_sword() -> void:
	var ctx: Dictionary = await _setup_game()
	# 铜剑 (tier 3) 打 slime 一次 = 5 伤害 (tier>=2)
	_equip_tool(ctx, "copper_sword")
	ctx["action"]._attack_combo_step = 1   # 挥 (100%)
	var slime_a = _spawn_slime_near(ctx, Vector2(24, 0))
	var hp_a = slime_a.current_health
	ctx["action"].mouse_world_override = slime_a.global_position
	ctx["action"]._attack_cooldown = 0.0
	ctx["action"].primary_override = true
	await wait_frames(2)
	ctx["action"].primary_override = false
	var sword_dmg: int = hp_a - slime_a.current_health
	# 切到铜镐
	var inv = ctx["inv"]
	inv.pickup("copper_pickaxe", 1)
	for i in inv.inventory.slots.size():
		if inv.inventory.slots[i] != null and inv.inventory.slots[i].item_id == "copper_pickaxe":
			inv.set_hotbar_selection(i)
			break
	await wait_frames(2)
	var slime_b = _spawn_slime_near(ctx, Vector2(36, 0))   # 鼠标 near 范围内, 不挡在 tile 上
	var hp_b = slime_b.current_health
	ctx["action"].mouse_world_override = slime_b.global_position
	ctx["action"]._attack_cooldown = 0.0
	ctx["action"].primary_override = true
	await wait_frames(3)
	ctx["action"].primary_override = false
	var pickaxe_dmg: int = hp_b - slime_b.current_health
	var expected: int = max(1, int(round(float(sword_dmg) * 0.5)))
	assert_eq(pickaxe_dmg, expected, "镐伤害应 = 剑伤害的 50% (round). sword=%d pickaxe=%d" % [sword_dmg, pickaxe_dmg])


# T8: 拿镐对石头 tile, 优先挖矿 (不攻击附近的怪)
func test_pickaxe_prefers_mining_over_attack() -> void:
	var ctx: Dictionary = await _setup_game()
	_equip_tool(ctx, "wood_pickaxe")
	var pt: Vector2i = ctx["action"].player_tile()
	var target: Vector2i = pt + Vector2i(2, 0)
	var terrain: TileMapLayer = ctx["world"].get_node("TerrainLayer")
	terrain.set_cell(target, Tiles.STONE, Vector2i.ZERO)
	ctx["world"]._set_tile(target.x, target.y, Tiles.STONE)
	var slime = _spawn_slime_near(ctx, Vector2(24, 0))
	var slime_hp = slime.current_health
	ctx["action"].aim_override = target
	ctx["action"].mouse_world_override = Vector2(target.x * 12 + 6, target.y * 12 + 6)
	ctx["action"].primary_override = true
	await wait_frames(15)
	ctx["action"].primary_override = false
	assert_eq(slime.current_health, slime_hp, "镐对石头时不该攻击 slime")


# T8: 拿镐对空 (鼠标不在 tile 上) 但附近有怪 → 触发攻击 cooldown
func test_pickaxe_attacks_when_no_block_at_mouse() -> void:
	var ctx: Dictionary = await _setup_game()
	_equip_tool(ctx, "wood_pickaxe")
	var slime = _spawn_slime_near(ctx, Vector2(24, 0))
	ctx["action"].mouse_world_override = slime.global_position
	# 不设 aim_override, 让 aim_tile_coord 走鼠标 → 那里是空气
	ctx["action"]._attack_cooldown = 0.0
	ctx["action"].primary_override = true
	await wait_frames(3)
	ctx["action"].primary_override = false
	assert_gt(ctx["action"]._attack_cooldown, 0.0, "镐对空 + 附近有怪 → 攻击 cooldown 应被设")


# T7: 挥剑朝前, 身后的 slime 不该扣血 (90° 弧)
func test_sweep_misses_behind() -> void:
	var ctx: Dictionary = await _setup_game()
	_equip_tool(ctx, "wood_sword")
	ctx["action"]._attack_combo_step = 1   # 下一击挥
	var front = _spawn_slime_near(ctx, Vector2(24, 0))
	var back = _spawn_slime_near(ctx, Vector2(-24, 0))
	var front_hp = front.current_health
	var back_hp = back.current_health
	ctx["action"].mouse_world_override = front.global_position
	ctx["action"]._attack_cooldown = 0.0
	ctx["action"].primary_override = true
	await wait_frames(2)
	ctx["action"].primary_override = false
	assert_lt(front.current_health, front_hp, "正前 slime 应扣血")
	assert_eq(back.current_health, back_hp, "身后 slime 不该扣血 (弧 90°)")


# T7: 挥剑弧内 (±30° + 正前) 3 只 slime 都扣血
func test_sweep_hits_all_in_arc() -> void:
	var ctx: Dictionary = await _setup_game()
	_equip_tool(ctx, "wood_sword")
	ctx["action"]._attack_combo_step = 1
	var center = _spawn_slime_near(ctx, Vector2(24, 0))
	var up = _spawn_slime_near(ctx, Vector2(20, -12))
	var down = _spawn_slime_near(ctx, Vector2(20, 12))
	var hp0 = center.current_health
	var hp1 = up.current_health
	var hp2 = down.current_health
	ctx["action"].mouse_world_override = center.global_position
	ctx["action"]._attack_cooldown = 0.0
	ctx["action"].primary_override = true
	await wait_frames(2)
	ctx["action"].primary_override = false
	assert_lt(center.current_health, hp0)
	assert_lt(up.current_health, hp1, "弧内上方应扣血")
	assert_lt(down.current_health, hp2, "弧内下方应扣血")


# T6: 戳前方两只 slime 排成线, 只有近的扣血 (戳只命中 1 个)
func test_thrust_hits_only_nearest() -> void:
	var ctx: Dictionary = await _setup_game()
	_equip_tool(ctx, "wood_sword")
	ctx["action"]._attack_combo_step = 0   # 下一击戳
	var near = _spawn_slime_near(ctx, Vector2(20, 0))
	var far  = _spawn_slime_near(ctx, Vector2(40, 0))
	var near_hp = near.current_health
	var far_hp = far.current_health
	ctx["action"].mouse_world_override = near.global_position
	ctx["action"]._attack_cooldown = 0.0
	ctx["action"].primary_override = true
	await wait_frames(2)
	ctx["action"].primary_override = false
	assert_lt(near.current_health, near_hp, "近的 slime 应扣血")
	assert_eq(far.current_health, far_hp, "远的 slime 不应扣血 (戳只命中 1)")


# T5: 连按 3 次左键, combo_step 序列 = 0 → 1 → 0 (戳挥交替)
func test_sword_combo_alternates() -> void:
	var ctx: Dictionary = await _setup_game()
	_equip_tool(ctx, "wood_sword")
	var action = ctx["action"]
	action._attack_combo_step = 0
	var steps: Array = []
	for i in range(3):
		action._attack_cooldown = 0.0
		steps.append(action._attack_combo_step)
		action.primary_override = true
		await wait_frames(2)
		action.primary_override = false
		await wait_frames(1)
	assert_eq(steps, [0, 1, 0], "戳挥应交替")


# T4: 切 hotbar (剑→镐→剑) 后 combo_step 应回 0 (下一击是戳, 不延续上次挥)
func test_combo_resets_on_hotbar_switch() -> void:
	var ctx: Dictionary = await _setup_game()
	_equip_tool(ctx, "wood_sword")
	# 人为设到 "下一击是挥"
	ctx["action"]._attack_combo_step = 1
	# 装木镐 + 切到镐的 slot
	var inv: Node = ctx["inv"]
	inv.pickup("wood_pickaxe", 1)
	for i in inv.inventory.slots.size():
		var s = inv.inventory.slots[i]
		if s != null and s.item_id == "wood_pickaxe":
			inv.set_hotbar_selection(i)
			break
	await wait_frames(2)
	assert_eq(ctx["action"]._attack_combo_step, 0, "切工具后 combo_step 应回 0")


# T3: 斧拿在手对非 LOG tile 不应进入挖矿进度 (避免动画播放)
func test_axe_on_stone_no_mining_anim() -> void:
	var ctx: Dictionary = await _setup_game()
	_equip_tool(ctx, "wood_axe")
	var pt: Vector2i = ctx["action"].player_tile()
	var target: Vector2i = pt + Vector2i(2, 0)
	var terrain: TileMapLayer = ctx["world"].get_node("TerrainLayer")
	terrain.set_cell(target, Tiles.STONE, Vector2i.ZERO)
	ctx["world"]._set_tile(target.x, target.y, Tiles.STONE)
	ctx["action"].aim_override = target
	ctx["action"].primary_override = true
	await wait_frames(20)
	ctx["action"].primary_override = false
	assert_eq(ctx["action"]._mining_progress, 0.0, "斧对非 LOG 不应累计挖矿进度")
