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
	var slime = _spawn_slime_near(ctx, Vector2(16, 0))
	var hp_before: int = slime.current_health
	ctx["action"].mouse_world_override = slime.global_position
	ctx["action"].primary_override = true
	await wait_frames(20)
	ctx["action"].primary_override = false
	assert_eq(slime.current_health, hp_before, "斧打 slime 不应该扣血")


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
