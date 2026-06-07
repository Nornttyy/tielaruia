# 大地图: 滚轮缩放 + 拖动平移 + 点击(没拖)关闭 + 退出重置平移.
extends GutTest
const MinimapScene := preload("res://scenes/ui/minimap.tscn")

var _mm: Control

func before_each() -> void:
	_mm = MinimapScene.instantiate()
	add_child_autofree(_mm)
	await get_tree().process_frame

func _wheel(up: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	_mm._gui_input(ev)

func _left(pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	_mm._gui_input(ev)

func _drag(dx: float, dy: float) -> void:
	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(dx, dy)
	_mm._gui_input(ev)

func test_fullscreen_wheel_zooms() -> void:
	_mm._toggle_fullscreen()
	await get_tree().process_frame
	var z0: int = _mm.pixel_per_tile
	_wheel(true)
	assert_gt(_mm.pixel_per_tile, z0, "大地图滚轮上滚应放大")
	var z1: int = _mm.pixel_per_tile
	_wheel(false); _wheel(false)
	assert_lt(_mm.pixel_per_tile, z1, "大地图滚轮下滚应缩小")

func test_fullscreen_zoom_clamped() -> void:
	_mm._toggle_fullscreen()
	await get_tree().process_frame
	for i in 40:
		_wheel(true)
	assert_lte(_mm.pixel_per_tile, _mm.FULLSCREEN_ZOOM_MAX, "不超过放大上限")
	for i in 40:
		_wheel(false)
	assert_gte(_mm.pixel_per_tile, _mm.FULLSCREEN_ZOOM_MIN, "不低于缩小下限")

func test_fullscreen_drag_pans_and_stays_open() -> void:
	_mm._toggle_fullscreen()
	await get_tree().process_frame
	assert_eq(_mm._pan, Vector2.ZERO, "刚开大地图居中 (pan=0)")
	_left(true)
	_drag(60, 0)
	assert_ne(_mm._pan, Vector2.ZERO, "拖动后视野平移")
	assert_true(_mm._fullscreen, "拖动时大地图不关")
	_left(false)
	assert_true(_mm._fullscreen, "拖完松开仍开着 (拖动≠点击)")

func test_fullscreen_click_no_drag_closes() -> void:
	_mm._toggle_fullscreen()
	await get_tree().process_frame
	assert_true(_mm._fullscreen)
	_left(true)
	_left(false)   # 没 motion → 点击 → 关
	assert_false(_mm._fullscreen, "大地图上点一下(没拖)应关闭")

func test_exit_resets_pan() -> void:
	_mm._toggle_fullscreen()
	await get_tree().process_frame
	_mm._pan = Vector2(10, 5)
	_mm._toggle_fullscreen()   # 关
	await get_tree().process_frame
	assert_eq(_mm._pan, Vector2.ZERO, "退出大地图重置平移")

func test_small_map_does_not_pan() -> void:
	# 小地图状态: 左键是"打开大地图", 不进入拖动; _pan 保持 0
	_left(true)
	assert_true(_mm._fullscreen, "小地图点一下打开大地图")
