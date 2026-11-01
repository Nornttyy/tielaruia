extends GutTest
const PlayerScene = preload("res://scenes/player/player.tscn")
var p: CharacterBody2D
var hp: Node
var old_creative: bool
var old_difficulty: int

class OpenInventory extends Node:
	func is_open(): return true

class FallMap extends Node:
	var water := false
	var cloud := false
	var rope := false
	func get_tile(x: int, y: int) -> int:
		if rope and x == 0 and y >= 18 and y <= 25: return Tiles.ROPE
		if water and y >= 46 and y < 50: return Tiles.WATER
		return (Tiles.CLOUD if cloud else Tiles.STONE) if y >= 50 else Tiles.AIR
	func get_chunk(_x: int): return null

func before_each():
	old_creative = GameSettings.creative_mode
	old_difficulty = GameSettings.current_difficulty
	GameSettings.creative_mode = false
	GameSettings.current_difficulty = 1
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(2000, 12)
	body.add_child(shape)
	body.position = Vector2(0, 606)
	add_child_autofree(body)
	p = PlayerScene.instantiate()
	p.position = Vector2(0, 600 - 32 * 12)
	add_child_autofree(p)
	# 停自动脚本更新，但保留物理空间；PROCESS_MODE_DISABLED 会把碰撞体移除。
	p.set_physics_process(false)
	p.set_process(false)
	for child in p.get_children():
		child.set_physics_process(false)
		child.set_process(false)
	hp = p.get_node("PlayerHealth")
	p._was_on_floor = false
	p.get_node("PlayerInventory").inventory.slots.fill(null)
	var map := FallMap.new()
	add_child_autofree(map)
	p._cached_chunk_manager = map
	await get_tree().physics_frame

func after_each():
	Input.action_release("jump")
	GameSettings.creative_mode = old_creative
	GameSettings.current_difficulty = old_difficulty

func _land():
	for tick in 400:
		p._physics_process(1.0 / 60.0)
		if p.is_on_floor(): break
	assert_true(p.is_on_floor(), "必须经过真实碰撞落地，而不是仅测试公式")

func test_real_twenty_five_and_twenty_six_tile_edges():
	for entry in [[25, 100], [26, 90]]:
		p.position = Vector2(0, 600 - entry[0] * 12)
		p.velocity = Vector2.ZERO
		p._hurt_timer = 0.0
		p._was_on_floor = false
		p.reset_fall_distance()
		hp.revive_full()
		await get_tree().physics_frame
		_land()
		assert_eq(hp.current_health, entry[1])

func test_thirty_two_tiles_hurt_once_without_launching_player():
	_land()
	assert_eq(hp.current_health, 30)
	assert_almost_eq(p.velocity.x, 0.0, 0.01)
	assert_almost_eq(p.velocity.y, 0.0, 0.01, "落地受伤不应该把角色弹起来")
	for tick in 5: p._physics_process(1.0 / 60.0)
	assert_eq(hp.current_health, 30)

func test_opening_inventory_does_not_cancel_falling():
	var ui := OpenInventory.new()
	add_child_autofree(ui)
	ui.add_to_group("crafting_panel")
	_land()
	assert_eq(hp.current_health, 30)

func test_missed_hook_does_not_clear_accumulated_distance():
	p.position.y = 510
	p.velocity.y = 450
	p._hook_flying = true
	p._hook_origin = p.position
	p._hook_tip = p.position
	p._hook_dir = Vector2.RIGHT
	_land()
	assert_eq(hp.current_health, 30)

func test_latched_hook_restarts_the_fall():
	p.position.y = 390
	p._hook_active = true
	p._hook_anchor = p.position + Vector2(30, -10)
	p._physics_process(1.0 / 60.0)
	p._release_hook()
	_land()
	assert_eq(hp.current_health, 100)

func test_water_and_cloud_protect_the_landing():
	for kind in ["water", "cloud"]:
		p._cached_chunk_manager.water = kind == "water"
		p._cached_chunk_manager.cloud = kind == "cloud"
		p.position = Vector2(0, 216)
		p.velocity = Vector2.ZERO
		p._was_on_floor = false
		p.reset_fall_distance()
		await get_tree().physics_frame
		_land()
		assert_eq(hp.current_health, 100, kind)

func test_rope_clears_old_distance_before_releasing():
	p.position.y = 300
	p._cached_chunk_manager.rope = true
	p._physics_process(1.0 / 60.0)
	assert_eq(p._fall_peak_y, p.position.y)
	p.position.x = 100
	_land()
	assert_eq(hp.current_health, 100)

func test_air_jump_restarts_distance_from_new_apex():
	p.position.y = 450
	# 退役的云靴仅保留旧存档行为，直接恢复一个旧存档槽位。
	p.get_node("PlayerInventory").inventory.slots[0] = {"item_id": "cloud_boots", "count": 1}
	assert_true(p.can_double_jump())
	p.set_physics_process(true)
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	p.set_physics_process(false)
	Input.action_release("jump")
	assert_lt(p.velocity.y, 0.0, "实际二段跳必须已经开始")
	_land()
	assert_eq(hp.current_health, 100)

func test_fall_has_defense_but_not_legacy_difficulty_multiplier():
	var inv = p.get_node("PlayerInventory")
	inv.set_armor("helmet", {"item_id": "copper_helmet", "count": 1})
	for difficulty in [0, 1, 2]:
		GameSettings.current_difficulty = difficulty
		hp.revive_full()
		hp.take_fall_damage(70)
		assert_eq(hp.current_health, 31, "1 防御抵消 0.5 后向下取最终伤害，70→69")
