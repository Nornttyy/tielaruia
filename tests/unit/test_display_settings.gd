extends GutTest

# 手机分辨率: 守住关键显示设置 (用户报手机有黑边/糊/视野小)。
# aspect=expand → 填满屏不留黑边 + 多露世界; allow_hidpi → 按手机真实像素渲染不发虚。

func test_stretch_aspect_is_expand():
	assert_eq(String(ProjectSettings.get_setting("display/window/stretch/aspect", "keep")), "expand",
		"拉伸 aspect 该是 expand (填满手机屏, 不留黑边, 视野更大)")


func test_stretch_mode_is_canvas_items():
	assert_eq(String(ProjectSettings.get_setting("display/window/stretch/mode", "")), "canvas_items",
		"stretch mode = canvas_items (2D 像素游戏)")


func test_hidpi_allowed():
	assert_true(bool(ProjectSettings.get_setting("display/window/dpi/allow_hidpi", false)),
		"允许 HiDPI → 高清屏按真实像素渲染 (不糊)")
