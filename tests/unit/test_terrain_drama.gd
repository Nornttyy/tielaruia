# 地形壮观度: 地表该有大山深谷 (泰拉瑞亚味), 不是缓平.
extends GutTest

const WorldGenerator = preload("res://scripts/world/world_generator.gd")


# 找某列真地面 y: 第一个草系 tile 且下面 20 格连续实心 (排除空岛浮草 ~9-12 厚).
func _real_surface_y(w: Dictionary, x: int) -> int:
	for y in range(15, 200):
		var t: int = w.tiles[x][y]
		if t == Tiles.GRASS or t == Tiles.SAND or t == Tiles.SNOW \
				or t == Tiles.JUNGLE_GRASS or t == Tiles.SWAMP_GRASS:
			var solid_run: int = 0
			for yy in range(y + 1, mini(y + 25, 254)):
				var bt: int = w.tiles[x][yy]
				if Tiles.is_solid(bt) and bt != Tiles.CLOUD:
					solid_run += 1
				else:
					break
			if solid_run >= 20:
				return y
	return -1


func test_surface_is_dramatic() -> void:
	var w: Dictionary = WorldGenerator.generate(42, 1024, 256)
	var min_y: int = 9999
	var max_y: int = -1
	for x in range(1024):
		var sy: int = _real_surface_y(w, x)
		if sy < 0:
			continue
		min_y = mini(min_y, sy)
		max_y = maxi(max_y, sy)
	gut.p("[地形] 最高峰 y=%d, 最深谷 y=%d, 起伏跨度=%d (越大越壮观)" % [min_y, max_y, max_y - min_y])
	assert_gt(max_y - min_y, 70, "地表起伏跨度该够大 (大山深谷)")
	assert_lt(min_y, 55, "该有高山 (最高峰 y 够小=够高)")
