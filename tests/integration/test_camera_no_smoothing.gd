# 用户报: 玩家移动有残影/糊. 根因: 相机 position_smoothing → 每帧亚像素位置 → 整画面重采样。
# 像素游戏必须关相机平滑 (相机锁玩家 = 像素对齐 = 清晰)。
extends GutTest
const WorldScene = preload("res://scenes/world/world.tscn")

func test_camera_smoothing_off():
	var w = WorldScene.instantiate()   # 不加进树, 只读节点属性 (不触发 _ready 生成区块)
	var cam = w.get_node("Camera2D")
	assert_false(cam.position_smoothing_enabled, "相机该关位置平滑 (像素游戏移动不糊/不残影)")
	w.free()
