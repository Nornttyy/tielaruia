# 特殊枪机制验收: 激光穿透 / 冰冻减速. 用桩怪 (不动, 确定性) + 慢速测试弹 (1px/帧, 不会跳过).
extends GutTest

const BulletScene = preload("res://scenes/entities/bullet.tscn")
const SlimeScene = preload("res://scenes/entities/slime.tscn")


# 桩怪: 站着不动, 记命中次数 + 是否被减速. 进 "slimes" 组让 bullet 扫得到.
class StubEnemy:
	extends Node2D
	var current_health: int = 100
	var hits: int = 0
	var slowed_factor: float = 0.0
	func _ready() -> void:
		add_to_group("slimes")
	func take_damage(d: int, _src: Vector2, _kb: float) -> void:
		current_health -= d
		hits += 1
	func apply_slow(factor: float, _dur: float) -> void:
		slowed_factor = factor


func _spawn_stub(pos: Vector2) -> StubEnemy:
	var s := StubEnemy.new()
	add_child_autofree(s)
	s.global_position = pos
	return s


func test_laser_pierces_both_enemies() -> void:
	var a := _spawn_stub(Vector2(20, 0))
	var b := _spawn_stub(Vector2(45, 0))
	var bullet = BulletScene.instantiate()
	add_child_autofree(bullet)
	# 慢速 60px/s = 1px/帧 → 必经过 x20/x45; pierce=true 穿透
	bullet.setup(Vector2(0, 0), Vector2(200, 0), 5, null, 60.0, {"pierce": true})
	await wait_frames(60)
	assert_eq(a.hits, 1, "激光穿透: 第1只被打中 1 次")
	assert_eq(b.hits, 1, "激光穿透: 第2只也被打中 (没被第1只挡住)")


func test_normal_bullet_stops_at_first() -> void:
	# 对照: 不穿透的普通弹打中第1只就消失, 打不到第2只
	var a := _spawn_stub(Vector2(20, 0))
	var b := _spawn_stub(Vector2(45, 0))
	var bullet = BulletScene.instantiate()
	add_child_autofree(bullet)
	bullet.setup(Vector2(0, 0), Vector2(200, 0), 5, null, 60.0)   # opts 空 → 不穿透
	await wait_frames(60)
	assert_eq(a.hits, 1, "普通弹: 第1只被打中")
	assert_eq(b.hits, 0, "普通弹: 第2只打不到 (子弹已消失)")


func test_freeze_bullet_slows_enemy() -> void:
	var a := _spawn_stub(Vector2(20, 0))
	var bullet = BulletScene.instantiate()
	add_child_autofree(bullet)
	bullet.setup(Vector2(0, 0), Vector2(200, 0), 5, null, 60.0, {"slow_factor": 0.4, "slow_dur": 2.0})
	await wait_frames(40)
	assert_almost_eq(a.slowed_factor, 0.4, 0.001, "冰冻枪命中给怪挂减速 0.4")


# 真史莱姆: apply_slow 让它 _slow_mult 变小 (跳得慢)
func test_real_slime_apply_slow() -> void:
	var slime = SlimeScene.instantiate()
	add_child_autofree(slime)
	await wait_frames(1)
	slime.apply_slow(0.3, 2.0)
	assert_almost_eq(slime._slow_mult, 0.3, 0.001, "史莱姆被冻 → _slow_mult=0.3")
	assert_gt(slime._slow_t, 0.0, "减速计时在走")
