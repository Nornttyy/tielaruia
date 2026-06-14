# 用户报: 没子弹的枪开火"完全没反应" (以为枪坏). 修: 没子弹时哔一声 + 飘提示 + 进短冷却 (不静默)。
extends GutTest
const MainScene = preload("res://scenes/main.tscn")

func _setup():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(5)
	var world = main.get_node("World")
	var player = world.get_player()
	return {"world": world, "player": player,
		"inv": player.get_node("PlayerInventory"), "pa": player.get_node("PlayerAction")}

func test_no_ammo_gives_feedback_not_silence():
	var c = await _setup()
	var inv = c.inv; var pa = c.pa
	# 清子弹库存
	for i in inv.inventory.slots.size():
		var s = inv.inventory.slots[i]
		if s != null and s.item_id == "bullet": inv.inventory.slots[i] = null
	inv.inventory.slots[0] = {"item_id": "minigun", "count": 1}
	inv.hotbar_selected = 0
	pa._attack_cooldown = 0.0
	var before = c.world.entities_root.get_child_count()
	pa._try_fire_gun()
	await wait_frames(1)
	assert_eq(c.world.entities_root.get_child_count(), before, "没子弹: 不该出子弹")
	assert_gt(pa._attack_cooldown, 0.0, "没子弹: 该走反馈(进冷却), 不再静默")

func test_with_ammo_still_fires():
	var c = await _setup()
	var inv = c.inv; var pa = c.pa
	inv.inventory.slots[0] = {"item_id": "minigun", "count": 1}
	inv.hotbar_selected = 0
	inv.pickup("bullet", 50)
	pa._attack_cooldown = 0.0
	var before = c.world.entities_root.get_child_count()
	pa._try_fire_gun()
	await wait_frames(1)
	assert_gt(c.world.entities_root.get_child_count(), before, "有子弹: 正常开火出弹")

func test_gun_empty_sound_exists():
	assert_true(SfxBank.has_sound("gun_empty"), "空枪哔音效该存在")
