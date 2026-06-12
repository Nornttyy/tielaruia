# T3 验收: 枪口火光粒子生成; 大威力枪 def 配了合理 gun_shake; 快枪不震 (防晕).
# 追加: 枪口招牌形状 — 每个枪系开火形状不同 (用户: 不要全是粒子).
extends GutTest

const PlayerAction = preload("res://scripts/player/player_action.gd")
const MuzzleFxScript = preload("res://scripts/fx/muzzle_flash_fx.gd")


func test_muzzle_flash_spawns_particles() -> void:
	var root := Node2D.new()
	root.add_to_group("effects_root")
	add_child_autofree(root)
	Effects.spawn_muzzle_flash(Vector2(10, 10), Vector2.RIGHT, Color8(255, 220, 140))
	assert_gt(root.get_child_count(), 0, "枪口火光该生成粒子")


# 枪口招牌形状: 节点真的生成 + kind 传进去了
func test_muzzle_flash_spawns_signature_shape() -> void:
	var root := Node2D.new()
	root.add_to_group("effects_root")
	add_child_autofree(root)
	Effects.spawn_muzzle_flash(Vector2(10, 10), Vector2.RIGHT, Color8(255, 90, 80), "beam", 1.5)
	var found: Node = null
	for c in root.get_children():
		if c.get_script() == MuzzleFxScript:
			found = c
	assert_not_null(found, "该生成枪口招牌形状节点")
	assert_eq(String(found.kind), "beam", "kind 该传进去 (激光=光束)")


# 每个枪系映射到自己的招牌形状 (不再全是同一种)
func test_muzzle_fx_kind_per_gun_family() -> void:
	var pa = PlayerAction.new()
	autofree(pa)
	var expect := {
		"pistol": "star", "minigun": "star", "shotgun": "fan",
		"laser_gun": "beam", "railgun": "beam",
		"flamethrower": "flame", "rocket_gun": "flame",
		"freeze_ray": "frost", "cryo_gun": "frost",
		"lightning_gun": "arc", "tesla_gun": "arc",
		"arcane_gun": "rune", "twin_magic_gun": "rune",
		"poison_gun": "drip", "venom_gun": "drip",
		"slime_gun": "splat", "leaf_gun": "leaves",
		"star_gun": "star", "ricochet_gun": "star",
	}
	for id in expect:
		assert_eq(pa._muzzle_fx_kind(ItemDB.get_def(id)), expect[id], id + " 的枪口形状")


func test_heavy_guns_have_shake() -> void:
	for id in ["sniper", "railgun", "rocket_gun", "shotgun"]:
		var def: Dictionary = ItemDB.get_def(id)
		var s: float = float(def.get("gun_shake", 0.0))
		assert_between(s, 0.5, 4.0, id + " 该配合理的 gun_shake (0.5~4)")


func test_normal_guns_no_shake() -> void:
	for id in ["pistol", "smg", "minigun"]:
		var def: Dictionary = ItemDB.get_def(id)
		assert_false(def.has("gun_shake"), id + " 快枪不该震屏 (会晕)")
