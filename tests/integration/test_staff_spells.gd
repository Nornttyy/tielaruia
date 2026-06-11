# 新机制法杖 (A 波) 验收: 多重魔弹一次 3 发 / 毒液法杖弹带毒 / 闪电法杖弹带连锁.
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


func _setup_staff(staff_id: String) -> Dictionary:
	var main = MainScene.instantiate(); add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(5)
	var world = main.get_node("World")
	var player = world.get_player()
	var inv = player.get_node("PlayerInventory")
	inv.pickup(staff_id, 1)
	inv.hotbar_selected = 0
	player.get_node("PlayerMana").current_mana = 100
	var action = player.get_node("PlayerAction")
	action.mouse_world_override = player.global_position + Vector2(240, -12)
	return {"world": world, "action": action}


func test_multi_staff_fires_3() -> void:
	var s = await _setup_staff("multi_staff")
	var before := _bullets_in(s.world).size()
	s.action._try_cast_staff()
	await wait_frames(1)
	assert_eq(_bullets_in(s.world).size() - before, 3, "多重魔弹法杖一次发 3 发扇形")


func test_poison_staff_bullet_has_dot() -> void:
	var s = await _setup_staff("poison_staff")
	s.action._try_cast_staff()
	await wait_frames(1)
	var bs := _bullets_in(s.world)
	assert_eq(bs.size(), 1, "毒液法杖 1 发")
	assert_gt(bs[0].dot_dps, 0, "毒液弹带毒(dot)")


func test_lightning_staff_bullet_has_chain() -> void:
	var s = await _setup_staff("lightning_staff")
	s.action._try_cast_staff()
	await wait_frames(1)
	var bs := _bullets_in(s.world)
	assert_gt(bs[0].chain, 0, "闪电弹带连锁(chain)")
