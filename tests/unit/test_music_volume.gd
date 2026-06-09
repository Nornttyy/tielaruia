# 回归: 主音量(master_volume) 只走 Master 总线, 不该烤进 MusicBank 的 player 音量.
# 老 bug: 调低音量 → 切场景把低值烤进 _bgm_target_db → 再调高也不恢复, 音乐永远偏小.
extends GutTest


func test_bgm_target_independent_of_master_volume() -> void:
	var saved: float = GameSettings.master_volume
	# 先把音量调低再切场景 (老逻辑会把低值烤进 target)
	GameSettings.master_volume = 0.1
	MusicBank.set_context("night")
	var low_target: float = MusicBank._bgm_target_db
	# 再调高音量并切场景
	GameSettings.master_volume = 1.0
	MusicBank.set_context("cave")
	var high_target: float = MusicBank._bgm_target_db
	assert_eq(low_target, high_target, "BGM 目标音量不该随主音量变 (主音量交给 Master 总线实时控制)")
	assert_almost_eq(high_target, MusicBank.BGM_VOLUME_DB, 0.001, "BGM 目标音量 = 常量, 不掺主音量")
	GameSettings.master_volume = saved
