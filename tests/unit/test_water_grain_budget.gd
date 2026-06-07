# 活水颗粒: 水珠贴图 + Effects 上限护栏的纯逻辑测试。
extends GutTest

const ParticlesArt = preload("res://scripts/fx/particles_art.gd")


func test_water_drop_texture_built() -> void:
	var tex = ParticlesArt.get_water_drop()
	assert_not_null(tex, "get_water_drop 该返回贴图")
	assert_eq(tex.get_width(), 3, "水珠贴图 3px 宽")
	assert_eq(tex.get_height(), 3, "水珠贴图 3px 高")


func test_water_drop_texture_cached() -> void:
	# 缓存: 两次调用返回同一个对象 (不重复建图)
	var a = ParticlesArt.get_water_drop()
	var b = ParticlesArt.get_water_drop()
	assert_eq(a, b, "get_water_drop 该缓存复用同一张贴图")
