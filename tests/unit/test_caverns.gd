# 大洞厅: 深层该有大块开阔洞 (能在里面跑), 不只是细 worm 隧道.
extends GutTest

const WorldGenerator = preload("res://scripts/world/world_generator.gd")


func test_big_caverns_exist() -> void:
	var w: Dictionary = WorldGenerator.generate(42, 512, 256)
	# 扫深层 (y 130..210, 在 cavern 带内、地狱之上), 找最宽横向连续 AIR + 数深层 AIR 总量
	var widest: int = 0
	var deep_air: int = 0
	var deep_total: int = 0
	for y in range(130, 210):
		var run: int = 0
		for x in range(512):
			deep_total += 1
			if w.tiles[x][y] == Tiles.AIR:
				run += 1
				deep_air += 1
				if run > widest:
					widest = run
			else:
				run = 0
	var pct: float = 100.0 * float(deep_air) / float(deep_total)
	gut.p("[洞厅] 深层最宽横向空洞=%d 格, 深层AIR占比=%.1f%%" % [widest, pct])
	assert_gt(widest, 14, "深层该有 >14 格宽的大洞厅 (能在里面跑, 不只是细隧道)")
	assert_lt(pct, 55.0, "深层别挖太空 (留出石头/矿, 别变纯空洞)")
