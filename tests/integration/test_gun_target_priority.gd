# T1 验收: 追踪弹优先追敌对怪 (slimes), 没有敌对怪才追动物;
# 魔法枪魔力享受法杖同款折扣 (staff_mana_cost: 正常局半价).
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const BulletScene = preload("res://scenes/entities/bullet.tscn")


class StubMob:
	extends Node2D
	var hits: int = 0
	var grp: String = "slimes"
	func _init(g: String = "slimes") -> void:
		grp = g
	func _ready() -> void:
		add_to_group(grp)
	func take_damage(_d: int, _src: Vector2, _kb: float = 0.0) -> void:
		hits += 1


func _stub(g: String, pos: Vector2) -> StubMob:
	var s := StubMob.new(g)
	add_child_autofree(s)
	s.global_position = pos
	return s


# 动物更近, 但有敌对怪在 → 追踪目标必须是敌对怪
func test_homing_prefers_hostile_over_closer_animal() -> void:
	var pig := _stub("animals", Vector2(40, 20))
	var zombie := _stub("slimes", Vector2(90, -30))
	var bullet = BulletScene.instantiate()
	add_child_autofree(bullet)
	bullet.setup(Vector2.ZERO, Vector2(120, 0), 5, null, 200.0, {"homing": 6.0})
	assert_eq(bullet._nearest_enemy(), zombie, "有敌对怪时该优先追敌对怪, 哪怕小猪更近")
	assert_eq(pig.hits, 0)


# 场上只有动物 → 退回追动物 (主动打猎仍可用)
func test_homing_falls_back_to_animal_when_no_hostile() -> void:
	var pig := _stub("animals", Vector2(40, 20))
	var bullet = BulletScene.instantiate()
	add_child_autofree(bullet)
	bullet.setup(Vector2.ZERO, Vector2(120, 0), 5, null, 200.0, {"homing": 6.0})
	assert_eq(bullet._nearest_enemy(), pig, "没敌对怪时退回追动物")


# 魔法枪魔力 = staff_mana_cost(base, false) (正常局半价, 至少 1)
func test_magic_gun_mana_discounted() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(5)
	var world = main.get_node("World")
	var player = world.get_player()
	var inv = player.get_node("PlayerInventory")
	inv.pickup("lightning_gun", 1)   # mana_cost=5 → 折后 round(5*0.5)=3 (能区分全价路径)
	inv.hotbar_selected = 0
	var mana = player.get_node("PlayerMana")
	mana.current_mana = 100
	var action = player.get_node("PlayerAction")
	action.mouse_world_override = player.global_position + Vector2(240, -12)
	action._try_fire_gun()
	await wait_frames(1)
	assert_eq(mana.current_mana, 97, "lightning_gun mana_cost=5, 折后该扣 3 (全价会扣 5)")
