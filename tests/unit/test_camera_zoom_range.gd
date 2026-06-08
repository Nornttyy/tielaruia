# 摄像机缩放范围: 滚轮/滑块都经 GameSettings.camera_zoom 的 setter clamp.
# 用户要求: 最小 1.0 (最缩/看最远, 从 0.8 抬上来 — 嫌拉太远), 最大 2.0 (最放大/看最近).
extends GutTest


func after_each() -> void:
	GameSettings.camera_zoom = 1.0   # 复位, 不污染其他测试的摄像机


func test_zoom_min_clamped_to_1_0() -> void:
	GameSettings.camera_zoom = 0.1   # 想缩更远
	assert_almost_eq(GameSettings.camera_zoom, 1.0, 0.001, "缩放下限夹到 1.0 (不让拉太远)")


func test_zoom_max_clamped_to_2_0() -> void:
	GameSettings.camera_zoom = 9.0   # 想放更大
	assert_almost_eq(GameSettings.camera_zoom, 2.0, 0.001, "缩放上限夹到 2.0")


func test_zoom_in_range_kept() -> void:
	GameSettings.camera_zoom = 1.4
	assert_almost_eq(GameSettings.camera_zoom, 1.4, 0.001, "范围内的值原样保留")
