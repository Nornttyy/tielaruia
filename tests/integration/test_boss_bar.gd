# Boss 专属血条: 有 boss 活着 → 顶部血条显示并绑定它; boss 没了 → 隐藏.
# (UI 走 _process 每帧刷; 测试里手动 pump _process 验证 show/hide 逻辑, 游戏内引擎自动每帧调.)
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const KingSlimeScene = preload("res://scenes/entities/king_slime.tscn")


func test_boss_bar_shows_then_hides() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var boss_bar = main.find_child("BossBar", true, false)
	assert_not_null(boss_bar, "HUD 应有 BossBar 节点")
	boss_bar._process(0.1)
	assert_false(boss_bar.visible, "没 boss 时血条应隐藏")
	# 召一只史莱姆王 (进 group boss)
	var king = KingSlimeScene.instantiate()
	add_child_autofree(king)
	await wait_frames(2)   # 等 king _ready 入组 boss
	assert_true(king.is_in_group("boss"), "king 应在 group boss")
	boss_bar._process(0.1)
	assert_true(boss_bar.visible, "有 boss 时血条应显示")
	assert_eq(boss_bar._boss, king, "血条应绑定到该 boss")
	# boss 用专属大条 → 头顶不该再挂小血条
	assert_null(king.get_node_or_null("HealthBar"), "boss 不该有头顶小血条")
	# boss 消失 → 隐藏
	king.queue_free()
	await wait_frames(2)
	boss_bar._process(0.1)
	assert_false(boss_bar.visible, "boss 消失后血条应隐藏")
