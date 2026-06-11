extends GutTest

# 对战房积分胜利: 击杀+1, 到 20 胜利, 胜利后重置. 随机出生点 (不重叠)。
const PvpScoreboard = preload("res://scripts/ui/pvp_scoreboard.gd")
const PvpArena = preload("res://scripts/world/pvp_arena.gd")


func test_random_spawn_within_platform():
	for i in 30:
		var sp: Vector2 = PvpArena.random_spawn()
		var x_tile: float = sp.x / 12.0
		assert_true(x_tile >= float(PvpArena.CENTER_X - PvpArena.HALF) \
				and x_tile <= float(PvpArena.CENTER_X + PvpArena.HALF), "出生 x 在平台内: %f" % x_tile)


func test_kill_adds_one_point():
	var sb = PvpScoreboard.new()
	add_child_autofree(sb)
	await wait_frames(1)
	sb._on_kill_scored("p1", "p2")
	sb._on_kill_scored("p1", "p2")
	assert_eq(int(sb._kills.get("p1", 0)), 2, "击杀 2 次 = 2 分")


func test_win_at_20():
	var sb = PvpScoreboard.new()
	add_child_autofree(sb)
	await wait_frames(1)
	for i in 19:
		sb._on_kill_scored("p1", "p2")
	assert_false(sb._match_over, "19 分还没赢")
	sb._on_kill_scored("p1", "p2")   # 第 20 分
	assert_true(sb._match_over, "到 20 分 → 比赛结束 (胜利)")
	assert_true(sb._banner.visible, "显示胜利横幅")
	assert_true(sb._banner.text.find("胜利") >= 0, "横幅含'胜利'")


func test_reset_clears_scores():
	var sb = PvpScoreboard.new()
	add_child_autofree(sb)
	await wait_frames(1)
	for i in 20:
		sb._on_kill_scored("p1", "p2")
	assert_true(sb._match_over)
	sb._reset_match()   # 直接触发重置 (跳过 4s 计时)
	assert_false(sb._match_over, "重置后比赛重新开始")
	assert_eq(sb._kills.size(), 0, "积分清零")
	assert_false(sb._banner.visible, "横幅收起")
