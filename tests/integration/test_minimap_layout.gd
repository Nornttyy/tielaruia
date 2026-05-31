extends GutTest
## 小地图布局测试 test_minimap_layout
##
## 挡住这个 bug: 点开小地图(大地图) → 再退出, 小地图会从右上角跳到右下角.
## 修好后: 退出大地图应原样回到进游戏时的位置 (这里模拟 hud.tscn 的右上角)。

const MinimapScene := preload("res://scenes/ui/minimap.tscn")

var _root: Control = null
var _minimap: Control = null

func before_each() -> void:
	# 造一个固定大小的父容器当"屏幕"
	_root = Control.new()
	_root.size = Vector2(1152, 648)
	add_child_autofree(_root)
	_minimap = MinimapScene.instantiate()
	# 模拟 hud.tscn: 把小地图摆在右上角 (anchor 右上, 顶部偏移 12)
	_minimap.anchor_left = 1.0
	_minimap.anchor_top = 0.0
	_minimap.anchor_right = 1.0
	_minimap.anchor_bottom = 0.0
	_minimap.offset_left = -448.0
	_minimap.offset_top = 12.0
	_minimap.offset_right = -256.0
	_minimap.offset_bottom = 140.0
	_root.add_child(_minimap)   # add_child 会触发 _ready, 在里面记下"老家"

func test_exit_fullscreen_returns_to_home() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var home_rect := _minimap.get_rect()

	# 点一下打开大地图
	_minimap._toggle_fullscreen()
	await get_tree().process_frame
	await get_tree().process_frame
	var big_rect := _minimap.get_rect()
	assert_true(big_rect.size.x > home_rect.size.x, "大地图应明显变大")

	# 再点一下退出大地图
	_minimap._toggle_fullscreen()
	await get_tree().process_frame
	await get_tree().process_frame
	var back_rect := _minimap.get_rect()

	# 退出后必须回到右上角的老家, 不能跑到右下角
	assert_almost_eq(back_rect.position.x, home_rect.position.x, 1.0, "退出后 X 应回原位")
	assert_almost_eq(back_rect.position.y, home_rect.position.y, 1.0, "退出后 Y 应回原位 (右上, 不是右下)")
	assert_almost_eq(back_rect.size.x, home_rect.size.x, 1.0, "退出后宽应回原位")
	assert_almost_eq(back_rect.size.y, home_rect.size.y, 1.0, "退出后高应回原位")
	# 额外明确: 顶部应贴近屏幕上方 (y≈12), 不是屏幕下方
	assert_lt(back_rect.position.y, 100.0, "小地图应在屏幕上方, 不是下方")
