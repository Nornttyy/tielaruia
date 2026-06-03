# 诊断: 地下海洋 (y>200) 是否淹了地狱 (y>220 的地狱矩形). 地狱深处该是岩浆/地狱石, 不该全是水.
extends GutTest

const WorldGenerator = preload("res://scripts/world/world_generator.gd")


func _is_lava(t: int) -> bool:
	return t == Tiles.LAVA or t == Tiles.LAVA_L1 or t == Tiles.LAVA_L2 or t == Tiles.LAVA_L3


func test_hell_zone_deep_not_all_water() -> void:
	var w: Dictionary = WorldGenerator.generate(42, 1024, 256)
	# 地狱中心 ~512, 半宽 250 → x 300..720 大致在地狱矩形内; y 222..250 是地狱深处
	var water: int = 0
	var lava: int = 0
	var hellstone: int = 0
	for x in range(330, 690):
		for y in range(222, 250):
			var t: int = w.tiles[x][y]
			if Tiles.is_water(t):
				water += 1
			elif _is_lava(t):
				lava += 1
			elif t == Tiles.HELL_STONE:
				hellstone += 1
	gut.p("[诊断] 地狱深处: 水=%d 岩浆=%d 地狱石=%d" % [water, lava, hellstone])
	# 地狱深处水不该比岩浆还多 (说明被海洋淹了)
	assert_lt(water, lava, "地狱深处水(%d)不该多于岩浆(%d) — 多了=被地下海洋淹了" % [water, lava])
