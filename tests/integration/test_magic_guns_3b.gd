# 魔法枪 (3b) 验收: 闪电连锁 / 撞墙反弹 / 史莱姆弹重力下坠.
extends GutTest

const BulletScene = preload("res://scenes/entities/bullet.tscn")


class StubEnemy:
	extends Node2D
	var current_health: int = 100
	var hits: int = 0
	func _ready() -> void:
		add_to_group("slimes")
	func take_damage(d: int, _src: Vector2, _kb: float = 0.0) -> void:
		current_health -= d
		hits += 1


# 假 chunk_manager: x>=wall_tx 的格当实心墙, 其余空气 (给反弹测试用)
class StubCM:
	extends Node
	var wall_tx: int = 3
	func _ready() -> void:
		add_to_group("chunk_manager")
	func get_tile(x: int, _y: int) -> int:
		return Tiles.STONE if x >= wall_tx else Tiles.AIR


func _stub(pos: Vector2) -> StubEnemy:
	var s := StubEnemy.new()
	add_child_autofree(s)
	s.global_position = pos
	return s


# 闪电链: 打中主目标后, 连锁到半径内另外几只 (它们不在子弹飞行线上, 只能靠连锁打到)
func test_chain_hits_nearby_enemies() -> void:
	var primary := _stub(Vector2(20, 0))
	var near1 := _stub(Vector2(40, 22))    # 偏离飞行线 (y=0), 只能被连锁打到
	var near2 := _stub(Vector2(48, -20))
	var bullet = BulletScene.instantiate()
	add_child_autofree(bullet)
	bullet.setup(Vector2(0, 0), Vector2(200, 0), 5, null, 60.0, {"chain": 3, "chain_radius": 64.0})
	await wait_frames(40)
	assert_gt(primary.hits, 0, "主目标被直接打中")
	assert_gt(near1.hits, 0, "连锁电到附近怪 1")
	assert_gt(near2.hits, 0, "连锁电到附近怪 2")


# 撞墙反弹: 星星弹撞到右边墙 → 横速翻向 (变往左), 子弹不消失
func test_star_bounces_off_wall() -> void:
	var cm := StubCM.new()
	add_child_autofree(cm)
	await wait_frames(1)
	var bullet = BulletScene.instantiate()
	add_child_autofree(bullet)
	# 朝右飞撞墙 (tile x>=3 即 px>=36)
	bullet.setup(Vector2(0, 0), Vector2(200, 0), 5, null, 240.0, {"bounce": 3, "lifetime": 5.0})
	await wait_frames(30)
	assert_true(is_instance_valid(bullet) and bullet.is_inside_tree(), "反弹弹撞墙后不该消失")
	assert_lt(bullet.velocity.x, 0.0, "撞右墙后横速该翻成往左")


# 史莱姆弹: 有重力 → 水平射出后会下坠 (velocity.y 变正)
func test_slime_blob_falls_under_gravity() -> void:
	var bullet = BulletScene.instantiate()
	add_child_autofree(bullet)
	bullet.setup(Vector2(0, 0), Vector2(100, 0), 5, null, 200.0, {"gravity": 500.0, "lifetime": 3.0})
	await wait_frames(15)
	assert_gt(bullet.velocity.y, 0.0, "史莱姆弹该受重力下坠 (velocity.y>0)")
