# 原版群系与建筑的确定性蓝图。先用世界坐标选址，再裁到当前区块，避免接缝和加载顺序影响。
extends RefCounted
const Samples = preload("res://scripts/world/original_structure_samples.gd")
const CC = preload("res://scripts/world/chunk_constants.gd")

static func plan(seed_value: int, centers: Dictionary, surface: Callable, sky: Array, scale: float) -> Dictionary:
	var edge := int(1700 * scale) + 80
	var evil := 5 if seed_value % 2 == 0 else 6
	var evil_x: int = centers[evil]
	var tree_x := -160
	for candidate in [-160, 160, -210, 210, -450, 450]:
		var free := true
		for cx in centers.values():
			if absi(candidate - int(cx)) < 140: free = false
		if free:
			tree_x = candidate
			break
	var dungeon_x: int = (edge - 105) * (-1 if int(centers[3]) > 0 else 1)
	var desert_x: int = centers[1]
	var mush_x := 180 if tree_x < 0 else -180
	var mush_y := clampi(int(surface.call(mush_x)) + 61, 150, 184)
	var cabins: Array = []
	for candidate in [int(centers[2]), int(centers[3]) - 34, tree_x - 95]:
		var x: int = candidate
		# 小世界也要留足空间，不能让蘑菇洞盖掉小屋的入口和家具。
		if absi(x - mush_x) < 85: x = mush_x + (95 if x >= mush_x else -95)
		cabins.append(Vector2i(x, clampi(int(surface.call(x)) + 49, 145, 195)))
	return {
		"evil": evil, "evil_x": evil_x, "edge": edge,
		"living_tree": Vector2i(tree_x, maxi(int(surface.call(tree_x)), 81)),
		"dungeon": Vector2i(dungeon_x, surface.call(dungeon_x)),
		"dungeon_depth": _dungeon_depth(Vector2i(dungeon_x, surface.call(dungeon_x)), surface),
		"pyramid": Vector2i(desert_x, surface.call(desert_x)),
		"mushroom": Vector2i(mush_x, mush_y), "cabins": cabins, "sky": sky,
	}

static func landmarks(p: Dictionary) -> Array:
	var tree: Vector2i = p.living_tree
	var pyramid: Vector2i = p.pyramid
	var dungeon: Vector2i = p.dungeon
	var mushroom: Vector2i = p.mushroom
	var result := [
		{"name": "生命树", "hint": "原始地图样本 · 斜向分枝 · 双树冠", "pos": tree + Vector2i(12, -30), "feet": tree + Vector2i(-2, 3), "zoom": 0.55},
		{"name": "生命树密室", "hint": "生命木墙 · 木制家具 · 宝箱", "pos": tree + Vector2i(19, 48), "feet": tree + Vector2i(17, 52), "zoom": 2.0},
		{"name": "沙漠金字塔", "hint": "原始塔身样本 · 砂岩砖 · 斜向通道 · 地下宝藏室", "pos": pyramid + Vector2i(0, 37), "feet": pyramid + Vector2i(23, 52), "zoom": 0.65},
		{"name": "地下小屋", "hint": "残缺木墙 · 木梁 · 可搜寻的宝箱", "pos": Vector2i(p.cabins[0]) + Vector2i(0, -5), "feet": Vector2i(p.cabins[0]) + Vector2i(-4, -1), "zoom": 2.0},
		{"name": "发光蘑菇洞", "hint": "蘑菇草 · 巨型发光蘑菇 · 泥土洞厅", "pos": mushroom, "feet": mushroom + Vector2i(1, 10), "zoom": 1.8},
		{"name": "地牢入口", "hint": "绿地牢砖 · 原始入口城垛 · 向下延伸的通道", "pos": dungeon + Vector2i(0, -7), "feet": dungeon + Vector2i(-17, -1), "zoom": 1.65},
		{"name": "地牢走廊", "hint": "原始入口下段 · 阶梯平台 · 曲折通道", "pos": dungeon + Vector2i(2, 36), "feet": dungeon + Vector2i(2, 40), "zoom": 1.7},
	]
	for island in p.sky:
		result.append({"name": "空岛小屋", "hint": "日盘块 · 日盘墙 · 云层托起的浮岛", "pos": Vector2i(island) + Vector2i(0, -5), "feet": Vector2i(island) + Vector2i(-4, -2), "zoom": 1.8})
		break
	result.append({"name": "腐化之地" if p.evil == 5 else "猩红之地", "hint": "每个普通种子只生成一种邪恶群系", "pos": Vector2i(p.evil_x, -1), "feet": Vector2i(p.evil_x - 20, -1), "zoom": 1.55})
	result.append({"name": "海滩与海洋", "hint": "沙滩向海床下沉 · 海水延伸到世界远端", "pos": Vector2i(p.edge + 22, 120), "feet": Vector2i(p.edge - 8, 111), "zoom": 1.55})
	return result

static func apply(c: Chunk, p: Dictionary, surface: Callable, seed_value: int) -> void:
	_evil(c, p, surface)
	_desert(c, p, surface)
	_ocean(c, p, surface)
	var tree: Vector2i = p.living_tree
	if _overlaps(c, tree.x - 34, tree.x + 62): _living_tree(c, tree, surface)
	var pyr: Vector2i = p.pyramid
	if _overlaps(c, pyr.x - 84, pyr.x + 91): _pyramid(c, pyr, surface)
	for cabin in p.cabins:
		if _overlaps(c, cabin.x - 28, cabin.x + 22): _cabin(c, cabin, seed_value)
	var mush: Vector2i = p.mushroom
	if _overlaps(c, mush.x - 45, mush.x + 45): _mushroom(c, mush)
	var dungeon: Vector2i = p.dungeon
	if _overlaps(c, dungeon.x - 38, dungeon.x + 70): _dungeon(c, dungeon, surface)
	for island in p.sky:
		if _overlaps(c, island.x - 12, island.x + 12): _sky_house(c, island)
	# 后盖的建筑可能覆盖原洞穴的箱子；元数据只保留实际存在的宝箱。
	c.treasure_spots = c.treasure_spots.filter(func(pos): return _read_tile(c, pos.x, pos.y) in [Tiles.CHEST, Tiles.GOLD_CHEST, Tiles.SHADOW_CHEST])

static func _overlaps(c: Chunk, left: int, right: int) -> bool:
	return left < (c.chunk_x + 1) * CC.CHUNK_WIDTH and right >= c.chunk_x * CC.CHUNK_WIDTH

static func _put(c: Chunk, x: int, y: int, tile: int, wall: int = -1) -> void:
	var lx := x - c.chunk_x * CC.CHUNK_WIDTH
	if lx < 0 or lx >= CC.CHUNK_WIDTH or y < 1 or y >= c.tiles[0].size() - 2: return
	c.tiles[lx][y] = tile
	if wall >= 0: c.walls[lx][y] = wall

static func _read_tile(c: Chunk, x: int, y: int) -> int:
	var lx := x - c.chunk_x * CC.CHUNK_WIDTH
	if lx < 0 or lx >= CC.CHUNK_WIDTH or y < 0 or y >= c.tiles[0].size(): return Tiles.AIR
	return c.tiles[lx][y]

static func _box(c: Chunk, rect: Rect2i, tile: int, wall: int = -1) -> void:
	for x in range(maxi(rect.position.x, c.chunk_x * CC.CHUNK_WIDTH), mini(rect.end.x, (c.chunk_x + 1) * CC.CHUNK_WIDTH)):
		for y in range(maxi(1, rect.position.y), mini(rect.end.y, c.tiles[0].size() - 2)):
			_put(c, x, y, tile, wall)

static func _room(c: Chunk, rect: Rect2i, block: int, wall: int) -> void:
	_box(c, rect, block, wall)
	_box(c, rect.grow(-1), Tiles.AIR, wall)

static func _chest(c: Chunk, x: int, y: int, tile: int = Tiles.GOLD_CHEST) -> void:
	_put(c, x, y, tile)
	if _overlaps(c, x, x) and not c.treasure_spots.has(Vector2i(x, y)):
		c.treasure_spots.append(Vector2i(x, y))

static func _door(c: Chunk, x: int, floor_y: int) -> void:
	_put(c, x, floor_y - 1, Tiles.DOOR)
	_put(c, x, floor_y - 2, Tiles.DOOR_MID)
	_put(c, x, floor_y - 3, Tiles.DOOR_TOP)

static func _furniture(c: Chunk, x: int, floor_y: int) -> void:
	_put(c, x, floor_y - 1, Tiles.WORKBENCH)
	_put(c, x + 3, floor_y - 1, 119)
	_put(c, x + 3, floor_y - 2, 120)
	_put(c, x - 1, floor_y - 4, Tiles.TORCH)

static func _living_tree(c: Chunk, a: Vector2i, surface: Callable) -> void:
	Samples.stamp(c, "living_tree", a)

static func _pyramid(c: Chunk, a: Vector2i, surface: Callable) -> void:
	Samples.stamp(c, "pyramid", a)

static func _cabin(c: Chunk, a: Vector2i, seed_value: int) -> void:
	Samples.stamp(c, "cabin", a)

static func _mushroom(c: Chunk, a: Vector2i) -> void:
	for dx in range(-43, 44):
		var curve := sqrt(maxf(0.0, 1.0 - pow(float(dx) / 44.0, 2)))
		var top := a.y - int(curve * 18.0)
		var floor_y := a.y + int(curve * _mushroom_floor(dx))
		_box(c, Rect2i(a.x + dx, top - 3, 1, floor_y - top + 7), Tiles.MUD, Tiles.MUSHROOM_WALL)
		_box(c, Rect2i(a.x + dx, top, 1, floor_y - top), Tiles.AIR, Tiles.MUSHROOM_WALL)
		_put(c, a.x + dx, floor_y, Tiles.MUSHROOM_GRASS)
		_put(c, a.x + dx, top - 1, Tiles.MUSHROOM_GRASS)
		if dx % 5 == 0 and absi(dx) < 36: _put(c, a.x + dx, floor_y - 1, Tiles.GLOW_MUSHROOM)
	for dx in [-29, -17, -4, 11, 25]:
		var floor_y := a.y + int(sqrt(1.0 - pow(float(dx) / 44.0, 2)) * _mushroom_floor(dx))
		var stem_h := 7 + posmod(dx, 5)
		_box(c, Rect2i(a.x + dx, floor_y - stem_h, 1, stem_h), Tiles.MUSHROOM_STEM)
		_put(c, a.x + dx, floor_y - stem_h, Tiles.MUSHROOM_CAP)

static func _dungeon(c: Chunk, a: Vector2i, _surface: Callable) -> void:
	Samples.stamp(c, "dungeon_entrance", a)

static func _sky_house(c: Chunk, a: Vector2i) -> void:
	Samples.stamp(c, "sky_house", a)

static func _desert(c: Chunk, p: Dictionary, surface: Callable) -> void:
	var center: int = p.pyramid.x
	if not _overlaps(c, center - 100, center + 100): return
	for lx in CC.CHUNK_WIDTH:
		var x := c.chunk_x * CC.CHUNK_WIDTH + lx
		if absi(x - center) > 100: continue
		var top: int = surface.call(x)
		for y in range(top + 5, mini(top + 62, c.tiles[lx].size() - 24)):
			if c.tiles[lx][y] in [Tiles.SAND, Tiles.STONE, Tiles.DEEP_STONE, Tiles.DIRT]:
				c.tiles[lx][y] = Tiles.HARDENED_SAND if y < top + 18 else Tiles.DESERT_SANDSTONE
			c.walls[lx][y] = Tiles.DESERT_WALL

static func _ocean(c: Chunk, p: Dictionary, surface: Callable) -> void:
	var sea_y := 116
	for lx in CC.CHUNK_WIDTH:
		var x := c.chunk_x * CC.CHUNK_WIDTH + lx
		var distance: int = absi(x) - p.edge
		if distance < -50: continue
		var depth := clampf(float(distance + 50) / 120.0, 0.0, 1.0)
		var land_y: int = surface.call((p.edge - 50) * (-1 if x < 0 else 1))
		var floor_y := int(lerpf(land_y, sea_y + 25, smoothstep(0.0, 1.0, depth)))
		floor_y += int(sin(x * 0.04) * depth * 2)
		c.surfaces[lx] = floor_y
		for y in range(1, mini(c.tiles[lx].size() - 25, maxi(floor_y, land_y) + 12)):
			var tile := Tiles.AIR
			if y >= floor_y: tile = Tiles.SAND if y < floor_y + 6 else Tiles.HARDENED_SAND
			elif y >= sea_y: tile = Tiles.WATER
			_put(c, x, y, tile, Tiles.AIR if y < floor_y else Tiles.DESERT_WALL)

# 建筑基础向下接到原地形，外围缓坡接回山坡，避免在斜坡上出现悬空土台。
static func _ground_pad(c: Chunk, a: Vector2i, half_width: int, flat_width: int, surface: Callable) -> void:
	for dx in range(-half_width, half_width + 1):
		var old_ground: int = surface.call(a.x + dx)
		var blend := smoothstep(float(flat_width), float(half_width), float(absi(dx)))
		var ground := int(lerpf(float(a.y), float(old_ground), blend))
		for y in range(maxi(1, mini(ground, old_ground) - 22), maxi(old_ground, ground) + 10):
			_put(c, a.x + dx, y, Tiles.AIR if y < ground else (Tiles.GRASS if y == ground else Tiles.DIRT), Tiles.AIR if y < ground else Tiles.DIRT_WALL)
		var lx := a.x + dx - c.chunk_x * CC.CHUNK_WIDTH
		if lx >= 0 and lx < CC.CHUNK_WIDTH: c.surfaces[lx] = ground

static func _dungeon_depth(a: Vector2i, surface: Callable) -> int:
	# 地牢入口可能立在山顶；按所有地下房间上方的地表选深度，不能让房间露在山坡外。
	var deepest := a.y
	for dx in range(8, 71): deepest = maxi(deepest, int(surface.call(a.x + dx)))
	return clampi(deepest - a.y + 16, 28, 210 - a.y - 35)

static func _mushroom_floor(dx: int) -> int:
	return 11 + int(sin(dx * 0.16) * 2.0)

static func _evil(c: Chunk, p: Dictionary, surface: Callable) -> void:
	var center: int = p.evil_x
	if not _overlaps(c, center - 100, center + 100): return
	var rock: int = Tiles.EBONSTONE if p.evil == 5 else Tiles.CRIMSTONE
	var grass: int = Tiles.CORRUPT_GRASS if p.evil == 5 else Tiles.CRIMSON_GRASS
	var wall: int = Tiles.EBON_WALL if p.evil == 5 else Tiles.CRIM_WALL
	for lx in CC.CHUNK_WIDTH:
		var x := c.chunk_x * CC.CHUNK_WIDTH + lx
		if absi(x - center) > 100: continue
		var top: int = surface.call(x)
		for y in range(top, mini(top + 68, c.tiles[lx].size() - 24)):
			if c.tiles[lx][y] in [Tiles.STONE, Tiles.DEEP_STONE, Tiles.DIRT]: c.tiles[lx][y] = rock
			if c.tiles[lx][y] in [Tiles.GRASS, Tiles.GRASS_SLOPE_L, Tiles.GRASS_SLOPE_R]: c.tiles[lx][y] = grass
			c.walls[lx][y] = wall
	# 腐化是狭长裂谷；猩红是倾斜入口接圆形内室，二者有不同轮廓。
	if p.evil == 5:
		for offset in [-44, 0, 43]:
			var start_y: int = surface.call(center + offset)
			for dy in range(49):
				var x: int = center + offset + int(sin(dy * 0.14) * 3)
				_box(c, Rect2i(x - 2, start_y + dy - 2, 5, 1), Tiles.AIR, wall)
			_box(c, Rect2i(center + offset - 9, start_y + 45, 19, 5), Tiles.AIR, wall)
	else:
		var start_y: int = surface.call(center - 30)
		for step in range(45): _box(c, Rect2i(center - 30 + step, start_y + step / 2 - 3, 4, 5), Tiles.AIR, wall)
		for dx in range(-20, 21):
			var radius := int(sqrt(maxf(0, 1.0 - pow(dx / 21.0, 2))) * 12)
			_box(c, Rect2i(center + 15 + dx, start_y + 27 - radius, 1, radius * 2), Tiles.AIR, wall)
