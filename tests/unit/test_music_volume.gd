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

func test_all_tracks_use_audible_base_volume_and_no_midfade_hole():
	for track in MusicBank.TRACK_NAMES:
		MusicBank.set_context(track)
		MusicBank._process(MusicBank.BGM_FADE_SEC)
		assert_almost_eq(MusicBank._active_bgm.volume_db, -14.0, 0.01, track)
	MusicBank.set_context("day")
	MusicBank._process(MusicBank.BGM_FADE_SEC * 0.5)
	var outgoing = MusicBank._bgm_b if MusicBank._active_bgm == MusicBank._bgm_a else MusicBank._bgm_a
	var amplitude: float = db_to_linear(outgoing.volume_db) + db_to_linear(MusicBank._active_bgm.volume_db)
	assert_almost_eq(amplitude, db_to_linear(-14.0), 0.001, "切歌中点不能掉到 -50 dB 左右")
	MusicBank._process(MusicBank.BGM_FADE_SEC)
	MusicBank.set_context("title")
