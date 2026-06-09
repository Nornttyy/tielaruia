# 枪开火验收: 装手枪 + 有子弹 → 射出 1 颗子弹并消耗 1 发; 没子弹 → 不射不消耗.
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const BulletScript = preload("res://scripts/entities/bullet.gd")


# 数场上活着的子弹节点 (递归扫 world 整棵子树, 不假设落在哪个父节点下)
func _count_bullets(world) -> int:
	return _count_script_in(world, BulletScript)


func _count_script_in(node: Node, script) -> int:
	var n := 0
	for c in node.get_children():
		if c.get_script() == script:
			n += 1
		n += _count_script_in(c, script)
	return n


# 背包里还有几发子弹
func _ammo(inv) -> int:
	var t := 0
	for s in inv.inventory.slots:
		if s != null and s.item_id == "bullet":
			t += s.count
	return t


func test_gun_with_ammo_fires_and_consumes_one() -> void:
	var main = MainScene.instantiate(); add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(5)
	var world = main.get_node("World")
	var player = world.get_player()
	var inv = player.get_node("PlayerInventory")
	inv.pickup("pistol", 1)
	inv.pickup("bullet", 3)
	inv.hotbar_selected = 0          # 手枪在第 0 格 (boot 背包空)
	var action = player.get_node("PlayerAction")
	action.mouse_world_override = player.global_position + Vector2(240, -12)
	var bullets_before := _count_bullets(world)
	var ammo_before := _ammo(inv)
	action._try_fire_gun()
	await wait_frames(1)
	assert_eq(_count_bullets(world), bullets_before + 1, "开枪应生成 1 颗子弹投射物")
	assert_eq(_ammo(inv), ammo_before - 1, "应消耗 1 发子弹 (3→2)")


func test_gun_without_ammo_does_not_fire() -> void:
	var main = MainScene.instantiate(); add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(5)
	var world = main.get_node("World")
	var player = world.get_player()
	var inv = player.get_node("PlayerInventory")
	inv.pickup("pistol", 1)          # 只有枪, 没子弹
	inv.hotbar_selected = 0
	var action = player.get_node("PlayerAction")
	action.mouse_world_override = player.global_position + Vector2(240, -12)
	action._try_fire_gun()
	await wait_frames(1)
	assert_eq(_count_bullets(world), 0, "没子弹时不该射出任何东西")
