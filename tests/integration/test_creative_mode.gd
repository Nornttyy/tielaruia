# 创造模式: 不掉血 / 无限放置 / 秒挖 / 飞行(无重力). 测完还原 creative_mode=false 防污染别的测试.
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func _dirt_count(inv: Node) -> int:
	var n: int = 0
	for s in inv.inventory.slots:
		if s != null and s.item_id == "dirt":
			n += s.count
	return n


func test_creative_no_damage_infinite_instant_fly() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	var hp: Node = player.get_node("PlayerHealth")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	# boot 默认生存
	assert_false(GameSettings.creative_mode, "boot 默认生存")
	GameSettings.creative_mode = true
	var pt: Vector2i = action.player_tile()

	# --- 不掉血 ---
	var hp_before: int = hp.current_health
	var took: bool = hp.take_damage(50)
	assert_false(took, "创造: take_damage 应返回 false")
	assert_eq(hp.current_health, hp_before, "创造: 血量不变")

	# --- 无限放置 (放了不掉库存) ---
	inv.pickup("dirt", 5)
	inv.set_hotbar_selection(0)
	assert_eq(_dirt_count(inv), 5, "前置: 有 5 个土")
	var ptarget := Vector2i(pt.x + 2, pt.y)
	world._set_tile(ptarget.x, ptarget.y, Tiles.AIR)   # 空出来 (创造无需支撑)
	action.aim_override = ptarget
	var placed: bool = action.try_place()
	assert_true(placed, "创造: 应能放 (无需支撑)")
	assert_eq(_dirt_count(inv), 5, "创造: 放了还是 5 个 (无限方块)")

	# --- 秒挖 (石头硬度 3s, 创造 2 帧就没) ---
	var mtarget := Vector2i(pt.x + 3, pt.y)
	world._set_tile(mtarget.x, mtarget.y, Tiles.STONE)
	action.aim_override = mtarget
	action.primary_override = true
	await wait_frames(2)
	action.primary_override = false
	assert_eq(terrain.get_cell_source_id(mtarget), -1, "创造: 石头被秒挖")

	# --- 飞行 (无重力: 不按键时 velocity.y 应为 0, 不下坠) ---
	action.aim_override = null
	player.global_position = Vector2(pt.x * 12 + 6, (pt.y - 6) * 12)   # 抬到空中
	player.velocity = Vector2(0, 50)   # 先给个下坠速度
	player._physics_process(0.1)
	assert_eq(player.velocity.y, 0.0, "创造: 飞行无重力 (不按键悬停, vy=0)")

	GameSettings.creative_mode = false   # 还原, 防污染别的集成测试
