# T3 验收: 枪口火光粒子生成; 大威力枪 def 配了合理 gun_shake; 快枪不震 (防晕).
extends GutTest


func test_muzzle_flash_spawns_particles() -> void:
	var root := Node2D.new()
	root.add_to_group("effects_root")
	add_child_autofree(root)
	Effects.spawn_muzzle_flash(Vector2(10, 10), Vector2.RIGHT, Color8(255, 220, 140))
	assert_gt(root.get_child_count(), 0, "枪口火光该生成粒子")


func test_heavy_guns_have_shake() -> void:
	for id in ["sniper", "railgun", "rocket_gun", "shotgun"]:
		var def: Dictionary = ItemDB.get_def(id)
		var s: float = float(def.get("gun_shake", 0.0))
		assert_between(s, 0.5, 4.0, id + " 该配合理的 gun_shake (0.5~4)")


func test_normal_guns_no_shake() -> void:
	for id in ["pistol", "smg", "minigun"]:
		var def: Dictionary = ItemDB.get_def(id)
		assert_false(def.has("gun_shake"), id + " 快枪不该震屏 (会晕)")
