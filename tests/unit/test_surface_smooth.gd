# 诊断: 地表列与列的高度跳变 (太大=锯齿尖刺=歪七扭八).
extends GutTest

const WorldGenerator = preload("res://scripts/world/world_generator.gd")


func _real_surface_y(w: Dictionary, x: int) -> int:
	for y in range(15, 220):
		var t: int = w.tiles[x][y]
		if t == Tiles.GRASS or t == Tiles.SAND or t == Tiles.SNOW \
				or t == Tiles.JUNGLE_GRASS or t == Tiles.SWAMP_GRASS \
				or t == Tiles.DIRT or t == Tiles.STONE:
			return y
	return -1


func test_surface_jaggedness() -> void:
	var w: Dictionary = WorldGenerator.generate(42, 512, 256)
	var prev: int = _real_surface_y(w, 0)
	var total_delta: int = 0
	var max_delta: int = 0
	var n: int = 0
	var spikes: int = 0   # 相邻列跳变 >= 4 格 = 尖刺
	for x in range(1, 512):
		var sy: int = _real_surface_y(w, x)
		if sy < 0 or prev < 0:
			prev = sy
			continue
		var d: int = absi(sy - prev)
		total_delta += d
		max_delta = maxi(max_delta, d)
		if d >= 4:
			spikes += 1
		n += 1
		prev = sy
	var avg: float = float(total_delta) / float(maxi(1, n))
	gut.p("[地表平滑] 平均跳变=%.2f 格, 最大跳变=%d, 尖刺列(跳≥4)=%d (越小越平滑)" % [avg, max_delta, spikes])
	assert_lt(avg, 1.05, "地表该平滑 (平均跳变 < 1.05 格, 否则歪七扭八)")
