# 史莱姆王碰撞: 王身子巨大, 剑碰到大身子就该命中 (不能只认中心一点).
# 回归: 之前近战命中只用怪 global_position 单点, 满血大王身子 ~26px 半宽,
# 中心落在剑命中半径(17.5)外 → 打不中 (用户反馈"碰撞太小"). 修法: 大怪给 melee_hit_radius.
extends GutTest

const PlayerScene = preload("res://scenes/player/player.tscn")
const KingSlimeScene = preload("res://scenes/entities/king_slime.tscn")
const SlimeScene = preload("res://scenes/entities/slime.tscn")


# 朝右戳一剑, 剑刃段在 y=-10 / x∈[17.5,37.5]. 把怪摆在 (28,-32):
# 中心距剑刃 22px (>SWORD_HIT_RADIUS 17.5), 距玩家 42.5px (>POINT_BLANK 22.5) → 单点判定打不中.
func _swing_right_at(pa: Node) -> void:
	pa._start_sword_blade_attack(false, Vector2.RIGHT, 100, 0.0)
	pa._sword_attack_t = 0.1   # dwell 阶段, 剑完全伸出
	pa._check_sword_blade_hits()


func test_sword_hits_kings_big_body():
	var player = PlayerScene.instantiate()
	add_child_autofree(player)
	var king = KingSlimeScene.instantiate()
	add_child_autofree(king)
	await wait_frames(2)   # _ready 跑完 (player 加 "player" 组; king apply_scale 满血=4 → 大身子)
	# 固定位置 (跟 swing 同步设, 不让重力把谁挪走)
	player.global_position = Vector2.ZERO
	king.global_position = Vector2(28, -32)
	var hp0: int = king.current_health
	_swing_right_at(player.get_node("PlayerAction"))
	assert_lt(king.current_health, hp0, "剑碰到王的大身子就该命中 (不只是中心点)")


func test_normal_slime_unchanged_at_same_distance():
	# 对照: 普通小史莱姆同样位置不该被打中 (它没 melee_hit_radius, 行为不变), 防"啥都变好打"
	var player = PlayerScene.instantiate()
	add_child_autofree(player)
	var slime = SlimeScene.instantiate()
	add_child_autofree(slime)
	await wait_frames(2)
	player.global_position = Vector2.ZERO
	slime.global_position = Vector2(28, -32)
	var hp0: int = slime.current_health
	_swing_right_at(player.get_node("PlayerAction"))
	assert_eq(slime.current_health, hp0, "小史莱姆中心在剑外 → 不命中 (行为不变)")
