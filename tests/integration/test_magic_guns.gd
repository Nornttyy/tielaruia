# 魔法枪 (3a) 验收: 耗魔力不耗子弹 / 追踪弹会拐弯追怪 / 毒弹给怪上毒持续掉血.
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const BulletScene = preload("res://scenes/entities/bullet.tscn")
const SlimeScene = preload("res://scenes/entities/slime.tscn")
const BulletScript = preload("res://scripts/entities/bullet.gd")


class StubEnemy:
	extends Node2D
	var current_health: int = 100
	var hits: int = 0
	var poisoned_dps: int = 0
	func _ready() -> void:
		add_to_group("slimes")
	func take_damage(d: int, _src: Vector2, _kb: float = 0.0) -> void:
		current_health -= d
		hits += 1
	func apply_poison(dps: int, _dur: float) -> void:
		poisoned_dps = dps


func _spawn_stub(pos: Vector2) -> StubEnemy:
	var s := StubEnemy.new()
	add_child_autofree(s)
	s.global_position = pos
	return s


func _count_bullets(node: Node) -> int:
	var n := 0
	for c in node.get_children():
		if c.get_script() == BulletScript:
			n += 1
		n += _count_bullets(c)
	return n


# 魔法枪用魔力发射, 不需要子弹
func test_magic_gun_uses_mana_not_bullet() -> void:
	var main = MainScene.instantiate(); add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(5)
	var world = main.get_node("World")
	var player = world.get_player()
	var inv = player.get_node("PlayerInventory")
	inv.pickup("arcane_gun", 1)          # 只有枪, 没子弹
	inv.hotbar_selected = 0
	var mana = player.get_node("PlayerMana")
	mana.current_mana = 100
	var action = player.get_node("PlayerAction")
	action.mouse_world_override = player.global_position + Vector2(240, -12)
	var before := _count_bullets(world)
	action._try_fire_gun()
	await wait_frames(1)
	assert_eq(_count_bullets(world) - before, 1, "魔法枪没子弹也能发 (耗魔力)")
	assert_eq(mana.current_mana, 92, "应扣 8 魔力 (arcane_gun mana_cost=8)")


# 魔力不够 → 不发
func test_magic_gun_no_mana_no_fire() -> void:
	var main = MainScene.instantiate(); add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(5)
	var world = main.get_node("World")
	var player = world.get_player()
	var inv = player.get_node("PlayerInventory")
	inv.pickup("arcane_gun", 1)
	inv.hotbar_selected = 0
	var mana = player.get_node("PlayerMana")
	mana.current_mana = 2                 # 不够 8
	var action = player.get_node("PlayerAction")
	action.mouse_world_override = player.global_position + Vector2(240, 0)
	action._try_fire_gun()
	await wait_frames(1)
	assert_eq(_count_bullets(world), 0, "魔力不够不该发")


# 追踪弹: 朝水平射, 但怪在斜下方 → 拐弯追上去打中 (不追踪会直直飞过, 打不到)
func test_homing_bullet_curves_to_enemy() -> void:
	var enemy := _spawn_stub(Vector2(55, 32))
	var bullet = BulletScene.instantiate()
	add_child_autofree(bullet)
	bullet.setup(Vector2(0, 0), Vector2(120, 0), 5, null, 200.0, {"homing": 6.0})
	await wait_frames(60)
	assert_gt(enemy.hits, 0, "追踪弹该拐弯追上斜下方的怪")


# 毒弹: 命中给怪挂毒
func test_poison_bullet_applies_poison() -> void:
	var enemy := _spawn_stub(Vector2(20, 0))
	var bullet = BulletScene.instantiate()
	add_child_autofree(bullet)
	bullet.setup(Vector2(0, 0), Vector2(200, 0), 4, null, 60.0, {"dot_dps": 6, "dot_dur": 4.0})
	await wait_frames(40)
	assert_eq(enemy.poisoned_dps, 6, "毒弹命中该给怪上毒 dps=6")


# 真史莱姆中毒 → 持续掉血
func test_real_slime_poison_ticks_damage() -> void:
	var slime = SlimeScene.instantiate()
	add_child_autofree(slime)
	await wait_frames(1)
	var hp_before: int = slime.current_health
	slime.apply_poison(6, 3.0)
	await wait_frames(45)   # 跨过至少 1 个 0.5s tick
	assert_lt(slime.current_health, hp_before, "中毒后史莱姆该持续掉血")
