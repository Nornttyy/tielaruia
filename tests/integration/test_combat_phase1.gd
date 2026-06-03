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


# 用户改: 镐扣血改"怪要碰到镐子"(continuous spin collision).
# 4 方向放 slime 紧贴, 等完整一圈 (0.7s ≈ 45 帧), 每个 slime 应被 tip 扫过 1 次.
# 冻住玩家 (set_physics_process(false)) 防重力+滑动让 slime 飘出 hit_radius.
func test_pickaxe_spin_hits_all_directions() -> void:
	var ctx: Dictionary = await _setup_game()
	_equip_tool(ctx, "wood_pickaxe")
	# 等玩家落地 + 冻住物理 (不然玩家 + slime 都重力下落, 测试 13px 距离不准)
	await wait_frames(10)
	ctx["player"].set_physics_process(false)
	ctx["player"].velocity = Vector2.ZERO
	# tip 绕 hand 转 ~11px 半径, hit_radius=14 → 怪在 player 14px 内能被扫到
	var r: float = 14.0
	var slimes: Array = []
	for offset in [Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
		var s = _spawn_slime_near(ctx, offset)
		s.set_physics_process(false)  # 冻住 slime, 不让它重力掉走
		slimes.append(s)
	var hps_before: Array = []
	for s in slimes:
		hps_before.append(s.current_health)
	ctx["action"].mouse_world_override = slimes[0].global_position
	ctx["action"]._attack_cooldown = 0.0
	ctx["action"].primary_override = true
	# 0.7s 转一圈, 60fps × 0.75s = 45 帧, 等够 tip 扫过 4 个方向
	await wait_frames(50)
	ctx["action"].primary_override = false
	ctx["player"].set_physics_process(true)
	for i in range(slimes.size()):
		assert_lt(slimes[i].current_health, hps_before[i],
			"方向 %d slime 应被 spin 扫到扣血" % i)


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
	# 用户改: 剑判定改成每帧扫剑身, 攻击 0.18s ≈ 11 帧才完成. 等 15 帧覆盖整个挥.
	await wait_frames(15)
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
	# 用户改: 镐 spin 半径 ~11px + hit_radius 14 → slime 要紧贴 (≤ ~14px)
	# 冻物理免重力下落
	ctx["player"].set_physics_process(false)
	ctx["player"].velocity = Vector2.ZERO
	var slime_b = _spawn_slime_near(ctx, Vector2(14, 0))
	slime_b.set_physics_process(false)
	var hp_b = slime_b.current_health
	ctx["action"].mouse_world_override = slime_b.global_position
	ctx["action"]._attack_cooldown = 0.0
	ctx["action"].primary_override = true
	# 转 1/4 圈 tip 到右边 slime 就被扫. 等 15 帧 (~0.25s), 然后松手避免 second spin.
	await wait_frames(15)
	ctx["action"].primary_override = false
	ctx["player"].set_physics_process(true)
	var pickaxe_dmg: int = hp_b - slime_b.current_health
	var expected: int = max(1, int(round(float(sword_dmg) * 0.5)))
	assert_eq(pickaxe_dmg, expected, "镐伤害应 = 剑伤害的一半. sword=%d pickaxe=%d" % [sword_dmg, pickaxe_dmg])


# T8: 拿镐对石头 tile, 优先挖矿. 用户改后: spin 期间紧贴的怪会被扫到 (incidental),
# 所以远离 slime 避开 tip 半径 (HIT_RADIUS=12, tip 半径~11 → 20px 外安全).
func test_pickaxe_prefers_mining_over_attack() -> void:
	var ctx: Dictionary = await _setup_game()
	_equip_tool(ctx, "wood_pickaxe")
	var pt: Vector2i = ctx["action"].player_tile()
	var target: Vector2i = pt + Vector2i(2, 0)
	var terrain: TileMapLayer = ctx["world"].get_node("TerrainLayer")
	terrain.set_cell(target, Tiles.STONE, Vector2i.ZERO)
	ctx["world"]._set_tile(target.x, target.y, Tiles.STONE)
	# slime 远一点, 镐 spin 扫不到 (用户要求"碰到才扣血")
	var slime = _spawn_slime_near(ctx, Vector2(36, 0))
	var slime_hp = slime.current_health
	ctx["action"].aim_override = target
	ctx["action"].mouse_world_override = Vector2(target.x * 12 + 6, target.y * 12 + 6)
	ctx["action"].primary_override = true
	await wait_frames(15)
	ctx["action"].primary_override = false
	assert_eq(slime.current_health, slime_hp, "镐对石头时, 远 slime 不该被扫到")


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


# T7: 挥剑朝前, 身后的 slime 不该扣血 (用户改后 180° 半圆, 后方仍出弧)
# 用 copper_sword (tier 3+, 走 sweep). 老用 wood_sword combo=1 强制 sweep, 用户改后木剑只戳.
func test_sweep_misses_behind() -> void:
	var ctx: Dictionary = await _setup_game()
	_equip_tool(ctx, "copper_sword")
	var front = _spawn_slime_near(ctx, Vector2(24, 0))
	var back = _spawn_slime_near(ctx, Vector2(-24, 0))
	var front_hp = front.current_health
	var back_hp = back.current_health
	ctx["action"].mouse_world_override = front.global_position
	ctx["action"]._attack_cooldown = 0.0
	ctx["action"].primary_override = true
	# 用户改: 剑判定改每帧扫, 等 15 帧让挥完整跑完
	await wait_frames(15)
	ctx["action"].primary_override = false
	assert_lt(front.current_health, front_hp, "正前 slime 应扣血")
	assert_eq(back.current_health, back_hp, "身后 slime 不该扣血 (半圆 180° 仍不含正后)")


# T7: 挥剑弧内 3 只 slime 都扣血 (用户改后 180° 半圆, 弧更大)
func test_sweep_hits_all_in_arc() -> void:
	var ctx: Dictionary = await _setup_game()
	_equip_tool(ctx, "copper_sword")
	var center = _spawn_slime_near(ctx, Vector2(24, 0))
	var up = _spawn_slime_near(ctx, Vector2(20, -12))
	var down = _spawn_slime_near(ctx, Vector2(20, 12))
	var hp0 = center.current_health
	var hp1 = up.current_health
	var hp2 = down.current_health
	ctx["action"].mouse_world_override = center.global_position
	ctx["action"]._attack_cooldown = 0.0
	ctx["action"].primary_override = true
	# 用户改: 剑判定每帧扫, 等 15 帧让挥扫完整 180° (中→上→下都过)
	await wait_frames(15)
	ctx["action"].primary_override = false
	assert_lt(center.current_health, hp0)
	assert_lt(up.current_health, hp1, "弧内上方应扣血")
	assert_lt(down.current_health, hp2, "弧内下方应扣血")


# T6: 戳前方两只 slime 排成线, 只有近的扣血 (戳只命中 1 个)
# 用 wood_dagger (短剑, sword_style=thrust, 永远戳).
func test_thrust_hits_only_nearest() -> void:
	var ctx: Dictionary = await _setup_game()
	_equip_tool(ctx, "wood_dagger")
	var near = _spawn_slime_near(ctx, Vector2(20, 0))
	var far  = _spawn_slime_near(ctx, Vector2(40, 0))
	var near_hp = near.current_health
	var far_hp = far.current_health
	ctx["action"].mouse_world_override = near.global_position
	ctx["action"]._attack_cooldown = 0.0
	ctx["action"].primary_override = true
	# 用户改: 剑判定每帧扫, 戳持续 ~9 帧. 等 15 帧让戳完整 forward + back.
	await wait_frames(15)
	ctx["action"].primary_override = false
	assert_lt(near.current_health, near_hp, "近的 slime 应扣血")
	assert_eq(far.current_health, far_hp, "远的 slime 不应扣血 (戳只命中 1)")


# 剑分家: 攻击方式按 sword_style 定 (短剑永远戳, 阔剑永远扫), 不再看 tier.
func test_dagger_thrusts_not_sweep() -> void:
	var ctx: Dictionary = await _setup_game()
	_equip_tool(ctx, "iron_dagger")   # 短剑 (sword_style=thrust)
	ctx["action"].mouse_world_override = ctx["player"].global_position + Vector2(20, 0)
	ctx["action"]._attack_cooldown = 0.0
	ctx["action"].primary_override = true
	await wait_frames(4)
	ctx["action"].primary_override = false
	assert_true(ctx["action"]._sword_attack_active, "短剑应触发攻击")
	assert_false(ctx["action"]._sword_attack_is_sweep, "短剑应该戳 (不是扫)")


func test_broadsword_sweeps_not_thrust() -> void:
	var ctx: Dictionary = await _setup_game()
	_equip_tool(ctx, "iron_sword")    # 阔剑 (sword_style=sweep), tier 4 跟短剑同 tier
	ctx["action"].mouse_world_override = ctx["player"].global_position + Vector2(20, 0)
	ctx["action"]._attack_cooldown = 0.0
	ctx["action"].primary_override = true
	await wait_frames(4)
	ctx["action"].primary_override = false
	assert_true(ctx["action"]._sword_attack_active, "阔剑应触发攻击")
	assert_true(ctx["action"]._sword_attack_is_sweep, "阔剑应该扫 (不是戳)")


# 防抽搐 1: 短剑冷却必须 > 戳动画时长, 否则戳没收回就重触发 → 发抖.
func test_thrust_cooldown_longer_than_animation() -> void:
	var ctx: Dictionary = await _setup_game()
	var a = ctx["action"]
	assert_gt(a.THRUST_COOLDOWN, a.SWORD_THRUST_DURATION,
		"短剑冷却(%.2f)要 > 戳动画(%.2f), 否则连戳抽搐" % [a.THRUST_COOLDOWN, a.SWORD_THRUST_DURATION])


# 防抽搐 2: 阔剑挥完后手持剑要归位 (rotation≈0), 不能卡在挥末角度 → 否则连挥瞬弹=发抖.
func test_broadsword_held_returns_to_rest_after_swing() -> void:
	var ctx: Dictionary = await _setup_game()
	_equip_tool(ctx, "iron_sword")
	var held = ctx["player"].get_node_or_null("HeldItem")
	assert_not_null(held, "玩家应有 HeldItem 手持节点")
	# 戳一刀就松手 (只触发 1 次)
	ctx["action"].mouse_world_override = ctx["player"].global_position + Vector2(20, 0)
	ctx["action"]._attack_cooldown = 0.0
	ctx["action"].primary_override = true
	await wait_frames(2)
	ctx["action"].primary_override = false
	# 等挥(0.18)+归位(0.126)+余量 全跑完
	await wait_frames(35)
	assert_almost_eq(held.rotation, 0.0, 0.15,
		"阔剑挥完手持剑该归位 rotation≈0, 实际 %.3f (卡在挥末=连挥抽搐根源)" % held.rotation)


# 老 combo 测试 (test_sword_combo_alternates / test_combo_resets_on_hotbar_switch)
# 用户改: 删了戳挥交替, tier 1-2 永远戳, tier 3+ 永远挥. 测试不再适用, 删.


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
