# 天空群系色调: set_biome_tint 让天空色被群系色调 multiply (沙漠偏橙等).
extends GutTest
const SkyBg = preload("res://scripts/world/sky_background.gd")

func test_biome_tint_multiplies_sky_color():
	var sky = ColorRect.new()
	sky.set_script(SkyBg)
	add_child_autofree(sky)
	await wait_frames(1)
	sky.set_layer_alpha(1.0)
	# 不染色 → 等于 TimeOfDay 原色
	sky.set_biome_tint(Color(1, 1, 1))
	sky._process(0.0)
	var base: Color = sky.color
	# 染成偏暖 (压蓝) → 蓝通道应变小
	sky.set_biome_tint(Color(1.0, 1.0, 0.5))
	sky._process(0.0)
	assert_lt(sky.color.b, base.b + 0.001, "群系色调 (压蓝) 应让天空蓝通道变小 (偏暖)")
