# 魔法枪 (3c) 验收: 冰雪枪 (扇形4颗雪花+减速) / 绿叶枪 (扇形3颗穿透树叶).
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const BulletScript = preload("res://scripts/entities/bullet.gd")


func _bullets_in(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		if c.get_script() == BulletScript:
			out.append(c)
		out.append_array(_bullets_in(c))
	return out


func _setup_gun(gun_id: String) -> Dictionary:
	var main = MainScene.instantiate(); add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(5)
	var world = main.get_node("World")
	var player = world.get_player()
	var inv = player.get_node("PlayerInventory")
	inv.pickup(gun_id, 1)
	inv.hotbar_selected = 0
	player.get_node("PlayerMana").current_mana = 100
	var action = player.get_node("PlayerAction")
	action.mouse_world_override = player.global_position + Vector2(240, -12)
	return {"world": world, "action": action}


# 冰雪枪: 一次喷 4 颗雪花, 每颗带减速
func test_frost_gun_fan_and_slow() -> void:
	var s = await _setup_gun("frost_gun")
	var before := _bullets_in(s.world).size()
	s.action._try_fire_gun()
	await wait_frames(1)
	var fresh := _bullets_in(s.world)
	assert_eq(fresh.size() - before, 4, "冰雪枪一次喷 4 颗雪花")
	assert_gt(fresh[0].slow_factor, 0.0, "雪花带减速效果")


# 绿叶枪: 一次喷 3 片叶子, 每片穿透
func test_leaf_gun_fan_and_pierce() -> void:
	var s = await _setup_gun("leaf_gun")
	var before := _bullets_in(s.world).size()
	s.action._try_fire_gun()
	await wait_frames(1)
	var fresh := _bullets_in(s.world)
	assert_eq(fresh.size() - before, 3, "绿叶枪一次喷 3 片叶子")
	assert_true(fresh[0].pierce, "叶子能穿透")
