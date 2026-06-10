# 多枪验收: 每把枪从 item def 读自己的参数 (一次几颗/弹速/冷却), 真的不一样.
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
	inv.pickup("bullet", 20)
	inv.hotbar_selected = 0
	var action = player.get_node("PlayerAction")
	action.mouse_world_override = player.global_position + Vector2(240, -12)
	return {"world": world, "action": action, "inv": inv}


# 霰弹枪: 一次扣 1 发, 但喷出 5 颗弹丸
func test_shotgun_fires_five_pellets() -> void:
	var s = await _setup_gun("shotgun")
	var before := _bullets_in(s.world).size()
	s.action._try_fire_gun()
	await wait_frames(1)
	assert_eq(_bullets_in(s.world).size() - before, 5, "霰弹枪一次该喷 5 颗弹丸")


# 狙击枪: 弹速应是 def 里的 1000 (远高于手枪 560)
func test_sniper_bullet_is_fast() -> void:
	var s = await _setup_gun("sniper")
	s.action._try_fire_gun()
	await wait_frames(1)
	var bs := _bullets_in(s.world)
	assert_eq(bs.size(), 1, "狙击枪一次 1 颗")
	assert_almost_eq(bs[0].velocity.length(), 1000.0, 30.0, "狙击子弹弹速≈1000 (按 def)")


# 冲锋枪: 冷却应是 def 里的 0.08 (远短于手枪 0.22)
func test_smg_has_short_cooldown() -> void:
	var s = await _setup_gun("smg")
	s.action._try_fire_gun()
	assert_almost_eq(s.action._attack_cooldown, 0.08, 0.001, "冲锋枪冷却≈0.08 (按 def, 比手枪快)")


# 手枪 (回归): 重构后仍是 1 颗 + 弹速 560
func test_pistol_unchanged() -> void:
	var s = await _setup_gun("pistol")
	s.action._try_fire_gun()
	await wait_frames(1)
	var bs := _bullets_in(s.world)
	assert_eq(bs.size(), 1, "手枪一次 1 颗")
	assert_almost_eq(bs[0].velocity.length(), 560.0, 20.0, "手枪弹速≈560 (没被重构改坏)")
