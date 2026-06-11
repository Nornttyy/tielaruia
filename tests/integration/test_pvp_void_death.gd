extends GutTest

# 对战房: 删了竞技场两侧墙, 掉到死亡线以下 = 秒杀 (PlayerHealth._check_pvp_void_death)。
const PlayerHealth = preload("res://scripts/player/player_health.gd")
const PvpArena = preload("res://scripts/world/pvp_arena.gd")


func _make_hp() -> Array:
	var parent := Node2D.new()
	add_child_autofree(parent)
	var hp = PlayerHealth.new()
	parent.add_child(hp)
	return [parent, hp]


func test_void_death_in_pvp_kills():
	var prev_mode = NetworkManager.room_mode
	var pair = _make_hp()
	var parent: Node2D = pair[0]
	var hp = pair[1]
	await wait_frames(1)
	NetworkManager.room_mode = "pvp"
	var died_fired := [false]
	hp.died.connect(func(): died_fired[0] = true)
	parent.global_position.y = PvpArena.death_y_px() + 60.0   # 掉到死亡线下方
	hp._check_pvp_void_death()
	assert_eq(hp.current_health, 0, "对战房掉到死亡线下 → 血归零")
	assert_true(died_fired[0], "触发 died (走 PvP 死亡/复活流程)")
	NetworkManager.room_mode = prev_mode


func test_no_death_above_line_or_outside_pvp():
	var prev_mode = NetworkManager.room_mode
	var pair = _make_hp()
	var parent: Node2D = pair[0]
	var hp = pair[1]
	await wait_frames(1)
	# 死亡线上方: 安全
	NetworkManager.room_mode = "pvp"
	parent.global_position.y = PvpArena.death_y_px() - 120.0
	hp._check_pvp_void_death()
	assert_gt(hp.current_health, 0, "死亡线上方不死")
	# 非对战房 (生存/单机): 掉很低也不死
	NetworkManager.room_mode = "survival"
	parent.global_position.y = PvpArena.death_y_px() + 300.0
	hp._check_pvp_void_death()
	assert_gt(hp.current_health, 0, "非对战房掉落不死 (单机/生存正常)")
	NetworkManager.room_mode = prev_mode
