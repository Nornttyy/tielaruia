# 回归: 联机远程玩家不该被染色 (用户要求"多人游戏时玩家不要变颜色").
# 以前远程玩家被染成偏蓝来跟本地区分; 现在靠头顶名字区分, 颜色保持正常.
extends GutTest

const RemotePlayerScene = preload("res://scenes/entities/remote_player.tscn")


func test_remote_player_spawn_not_tinted() -> void:
	var rp = RemotePlayerScene.instantiate()
	add_child_autofree(rp)
	await wait_frames(1)
	var spr = rp.get_node("AnimatedSprite2D")
	assert_eq(spr.modulate, Color.WHITE, "远程玩家出生不该被染色 (正常颜色)")


func test_remote_player_dead_fades_but_no_tint() -> void:
	var rp = RemotePlayerScene.instantiate()
	add_child_autofree(rp)
	await wait_frames(1)
	var spr = rp.get_node("AnimatedSprite2D")
	rp.set_dead(true)
	assert_almost_eq(spr.modulate.a, 0.35, 0.01, "死亡只变淡 (透明度)")
	assert_eq(Color(spr.modulate.r, spr.modulate.g, spr.modulate.b), Color.WHITE, "死亡也不偏色")
	rp.set_dead(false)
	assert_eq(spr.modulate, Color.WHITE, "复活恢复正常颜色")
