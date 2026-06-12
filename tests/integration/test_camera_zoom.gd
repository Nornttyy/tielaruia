# 摄像机缩放: 改 GameSettings.camera_zoom (滚轮/设置滑块) → 真摄像机 Camera2D.zoom 跟着变。
# 起因: 之前 camera_zoom 只被光照层读, 没人应用到摄像机 → 滚轮只动光照不动镜头。
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func _setup() -> Dictionary:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	var world: Node2D = main.get_node("World")
	var player: Node2D = world.get_player()
	return {"main": main, "player": player}


func after_each() -> void:
	if GameSettings != null:
		GameSettings.camera_zoom = 1.0   # 复位到默认, 别污染别的测试/存档


func test_camera_zoom_setting_applies_to_camera() -> void:
	var ctx: Dictionary = await _setup()
	var camera = ctx["player"].get_node_or_null("Camera2D")
	assert_not_null(camera, "玩家应有 Camera2D")
	GameSettings.camera_zoom = 1.6   # 拉近
	await wait_frames(2)
	assert_almost_eq(camera.zoom.x, 1.6, 0.01, "改 camera_zoom → 摄像机 zoom 跟着变 (拉近)")
	GameSettings.camera_zoom = 1.2   # 拉远 (下限后来从 0.8 抬到 1.0, 测试跟着用合法值)
	await wait_frames(2)
	assert_almost_eq(camera.zoom.x, 1.2, 0.01, "改 camera_zoom → 摄像机 zoom 跟着变 (拉远)")
	GameSettings.camera_zoom = 0.8   # 低于下限 → 该被夹回 1.0
	await wait_frames(2)
	assert_almost_eq(camera.zoom.x, 1.0, 0.01, "低于下限的值该被夹到 1.0")
