# 设置: 帧率 (Engine.max_fps) + 画质预设 (控视差/鸟群). 用户要求。
extends GutTest

var _fps0: int
var _q0: int

func before_each():
	_fps0 = GameSettings.max_fps
	_q0 = GameSettings.graphics_quality

func after_each():
	GameSettings.max_fps = _fps0
	GameSettings.graphics_quality = _q0

func test_max_fps_applies_to_engine():
	GameSettings.max_fps = 30
	assert_eq(Engine.max_fps, 30, "帧率设置该应用到 Engine.max_fps")
	GameSettings.max_fps = 0   # 不限
	assert_eq(Engine.max_fps, 0, "不限 = max_fps 0")

func test_quality_low_turns_off_heavy_layers():
	GameSettings.graphics_quality = 0   # 流畅
	assert_false(GameSettings.show_parallax, "流畅: 关视差")
	assert_false(GameSettings.show_flocks, "流畅: 关鸟群")

func test_quality_high_turns_on_all():
	GameSettings.graphics_quality = 2   # 精细
	assert_true(GameSettings.show_parallax, "精细: 开视差")
	assert_true(GameSettings.show_flocks, "精细: 开鸟群")

func test_quality_standard_parallax_only():
	GameSettings.graphics_quality = 1   # 标准
	assert_true(GameSettings.show_parallax, "标准: 视差开")
	assert_false(GameSettings.show_flocks, "标准: 鸟群关")
