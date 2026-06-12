# T3 验收: 枪口招牌形状生成 (纯形状零粒子); 大威力枪 gun_shake 合理; 快枪不震 (防晕).
# 追加: 子弹命中特效 — 打中怪放射爆闪 / 打到方块反弹火星 (所有枪都有).
extends GutTest

const PlayerAction = preload("res://scripts/player/player_action.gd")
const MuzzleFxScript = preload("res://scripts/fx/muzzle_flash_fx.gd")
const BulletScene = preload("res://scenes/entities/bullet.tscn")


class StubMob:
	extends Node2D
	var hits: int = 0
	func _ready() -> void:
		add_to_group("slimes")
	func take_damage(_d: int, _src: Vector2, _kb: float = 0.0) -> void:
		hits += 1


class StubCM:
	extends Node
	func _ready() -> void:
		add_to_group("chunk_manager")
	func get_tile(_x: int, _y: int) -> int:
		return Tiles.STONE   # 处处实心 → 子弹一飞就撞墙


func _fx_with_kind(root: Node, want: String) -> Node:
	for c in root.get_children():
		if c.get_script() == MuzzleFxScript and String(c.kind) == want:
			return c
	return null


func test_muzzle_flash_spawns_shape_only() -> void:
	var root := Node2D.new()
	root.add_to_group("effects_root")
	add_child_autofree(root)
	Effects.spawn_muzzle_flash(Vector2(10, 10), Vector2.RIGHT, Color8(255, 220, 140))
	assert_eq(root.get_child_count(), 1, "枪口该只生成 1 个形状节点 (零粒子)")
	assert_eq(root.get_child(0).get_script(), MuzzleFxScript, "生成的该是招牌形状节点")


# 子弹打中怪 → 放射爆闪 (kind=hit)
func test_bullet_hit_enemy_spawns_burst() -> void:
	var root := Node2D.new()
	root.add_to_group("effects_root")
	add_child_autofree(root)
	var mob := StubMob.new()
	add_child_autofree(mob)
	mob.global_position = Vector2(30, 0)
	var bullet = BulletScene.instantiate()
	add_child_autofree(bullet)
	bullet.setup(Vector2.ZERO, Vector2(200, 0), 5, null, 300.0, {})
	var found: Node = null
	for _f in 30:
		await wait_frames(1)
		found = _fx_with_kind(root, "hit")
		if found != null:
			break
	assert_gt(mob.hits, 0, "子弹该打中怪")
	assert_not_null(found, "打中怪该放放射爆闪 (kind=hit)")


# 子弹打到方块 → 反弹火星 (kind=wallhit)
func test_bullet_hit_wall_spawns_sparks() -> void:
	var root := Node2D.new()
	root.add_to_group("effects_root")
	add_child_autofree(root)
	var cm := StubCM.new()
	add_child_autofree(cm)
	var bullet = BulletScene.instantiate()
	add_child_autofree(bullet)
	bullet.setup(Vector2.ZERO, Vector2(200, 0), 5, null, 300.0, {})
	var found: Node = null
	for _f in 10:
		await wait_frames(1)
		found = _fx_with_kind(root, "wallhit")
		if found != null:
			break
	assert_not_null(found, "打到方块该溅反弹火星 (kind=wallhit)")


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
