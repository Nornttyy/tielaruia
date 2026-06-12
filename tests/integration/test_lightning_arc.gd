# T4 验收: 电弧 Line2D 生成 + 自动释放; 闪电链接力式跳怪 (每跳从上一只出发) + 敌对优先.
extends GutTest

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


func test_arc_spawns_and_frees() -> void:
	var root := Node2D.new()
	root.add_to_group("effects_root")
	add_child_autofree(root)
	Effects.spawn_lightning_arc(Vector2.ZERO, Vector2(60, 0))
	assert_gt(root.get_child_count(), 0, "电弧该生成 Line2D")
	await wait_seconds(0.6)
	assert_eq(root.get_child_count(), 0, "淡出后该自动释放")


# 接力式: A(30,0) B(80,0) C(130,0), 链 2 跳半径 64.
# 旧"发散式"从 A 量距离够不着 C (100>64); 接力式 B→C 只有 50 → C 必须被电到.
func test_chain_relays_beyond_first_radius() -> void:
	var a := _stub("slimes", Vector2(30, 0))
	var b := _stub("slimes", Vector2(80, 0))
	var c := _stub("slimes", Vector2(130, 0))
	var bullet = BulletScene.instantiate()
	add_child_autofree(bullet)
	bullet.setup(Vector2.ZERO, Vector2(200, 0), 5, null, 300.0, {"chain": 2, "chain_radius": 64.0})
	await wait_frames(20)
	assert_gt(a.hits, 0, "直击 A")
	assert_gt(b.hits, 0, "第 1 跳电到 B")
	assert_gt(c.hits, 0, "接力第 2 跳从 B 出发电到 C")


# 敌对优先: 第一跳该跳敌对怪, 哪怕动物更近
func test_chain_prefers_hostile_over_closer_animal() -> void:
	var first := _stub("slimes", Vector2(30, 0))
	var pig := _stub("animals", Vector2(45, 0))
	var skel := _stub("slimes", Vector2(70, 0))
	var bullet = BulletScene.instantiate()
	add_child_autofree(bullet)
	bullet.setup(Vector2.ZERO, Vector2(200, 0), 5, null, 300.0, {"chain": 1, "chain_radius": 64.0})
	await wait_frames(20)
	assert_gt(first.hits, 0)
	assert_gt(skel.hits, 0, "链 1 跳该电敌对怪")
	assert_eq(pig.hits, 0, "动物更近也不该被电 (还有敌对怪在)")
