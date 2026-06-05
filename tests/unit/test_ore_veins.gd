# 矿脉: 矿该成簇成脉 (挖一片), 不是零散单点.
extends GutTest

const WorldGenerator = preload("res://scripts/world/world_generator.gd")


func _max_cluster(w: Dictionary, ore: int) -> int:
	var visited: Dictionary = {}
	var best: int = 0
	for x in range(512):
		for y in range(60, 218):
			if w.tiles[x][y] != ore:
				continue
			var key := Vector2i(x, y)
			if visited.has(key):
				continue
			var stack: Array = [key]
			visited[key] = true
			var size: int = 0
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				size += 1
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var np: Vector2i = p + d
					if np.x < 0 or np.x >= 512 or np.y < 0 or np.y >= 256:
						continue
					if visited.has(np):
						continue
					if w.tiles[np.x][np.y] == ore:
						visited[np] = true
						stack.append(np)
			best = maxi(best, size)
	return best


func test_ore_forms_veins() -> void:
	var w: Dictionary = WorldGenerator.generate(42, 512, 256)
	var coal: int = _max_cluster(w, Tiles.COAL_ORE)
	var iron: int = _max_cluster(w, Tiles.IRON_ORE)
	gut.p("[矿脉] 最大煤矿簇=%d, 最大铁矿簇=%d (越大越成脉)" % [coal, iron])
	assert_gt(coal, 15, "煤矿该成簇成脉 (>15格连通成片), 不是零散单点")
