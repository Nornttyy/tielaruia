# 对战房验收: 法杖/枪的投射物 (bullet) + 元素法杖火球 (fireball) + 地裂 (earth_crack)
# 现在都能打到远程玩家 (之前只有箭 arrow 能 — 枪/法杖在 PvP 不掉血是个洞)。
# 用 flash_hit 是否触发证明"判到命中 + 发了 send_player_damage" (send 本身离线 no-op, 不报错)。
extends GutTest

const BulletScene = preload("res://scenes/entities/bullet.tscn")
const FireballScene = preload("res://scenes/entities/fireball.tscn")
const EarthCrackScene = preload("res://scenes/entities/earth_crack.tscn")


# 假远程玩家: 在 remote_player 组, 有 peer_id + melee_hit_radius + flash_hit (记一下被打没)
class StubRemote:
	extends Node2D
	var peer_id: String = "PEER123"
	var flashed: int = 0
	func _ready() -> void:
		add_to_group("remote_player")
	func melee_hit_radius() -> float:
		return 8.0
	func flash_hit() -> void:
		flashed += 1


func _set_pvp(on: bool) -> void:
	NetworkManager.status = "connected" if on else "idle"
	NetworkManager.room_mode = "pvp" if on else "survival"


func _remote(pos: Vector2) -> StubRemote:
	var r := StubRemote.new()
	add_child_autofree(r)
	r.global_position = pos
	return r


func test_bullet_hits_remote_player_in_pvp() -> void:
	var prev_s = NetworkManager.status
	var prev_m = NetworkManager.room_mode
	_set_pvp(true)
	var rp := _remote(Vector2(24, 0))
	var b = BulletScene.instantiate()
	add_child_autofree(b)
	b.setup(Vector2(0, 0), Vector2(200, 0), 5, null, 60.0, {})
	await wait_frames(40)
	assert_gt(rp.flashed, 0, "对战房: 子弹打到远程玩家 (flash_hit 触发 = 发了伤害)")
	NetworkManager.status = prev_s
	NetworkManager.room_mode = prev_m


func test_bullet_ignores_remote_player_outside_pvp() -> void:
	var prev_s = NetworkManager.status
	var prev_m = NetworkManager.room_mode
	_set_pvp(false)
	var rp := _remote(Vector2(24, 0))
	var b = BulletScene.instantiate()
	add_child_autofree(b)
	b.setup(Vector2(0, 0), Vector2(200, 0), 5, null, 60.0, {})
	await wait_frames(40)
	assert_eq(rp.flashed, 0, "非对战房: 子弹不打玩家 (避免误伤队友)")
	NetworkManager.status = prev_s
	NetworkManager.room_mode = prev_m


func test_fireball_hits_remote_player_in_pvp() -> void:
	var prev_s = NetworkManager.status
	var prev_m = NetworkManager.room_mode
	_set_pvp(true)
	var rp := _remote(Vector2(48, 0))
	var fb = FireballScene.instantiate()
	add_child_autofree(fb)
	fb.setup(Vector2(0, 0), Vector2(200, 0), 6, true, "fire")   # player_cast=true
	await wait_frames(40)
	assert_gt(rp.flashed, 0, "对战房: 火球 (元素法杖) 打到远程玩家")
	NetworkManager.status = prev_s
	NetworkManager.room_mode = prev_m


func test_earth_crack_hits_remote_player_in_pvp() -> void:
	var prev_s = NetworkManager.status
	var prev_m = NetworkManager.room_mode
	_set_pvp(true)
	var rp := _remote(Vector2(10, -4))   # 站在裂缝带内
	var crack = EarthCrackScene.instantiate()
	add_child_autofree(crack)
	crack.global_position = Vector2(0, 0)
	crack.setup(7, null)
	await wait_frames(6)
	assert_gt(rp.flashed, 0, "对战房: 地裂伤到站上面的远程玩家")
	NetworkManager.status = prev_s
	NetworkManager.room_mode = prev_m
