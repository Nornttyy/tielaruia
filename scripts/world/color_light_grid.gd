# 彩色瓦片光场：各颜色独立衰减，水会更快吸收红光，火把保留暖色。
# 使用定向扫描传播，成本与可见格数成正比，不为每盏灯重新遍历世界。
extends RefCounted

const Legacy = preload("res://scripts/world/tile_light_grid.gd")
const AIR_DECAY := Vector3(0.91, 0.91, 0.91)
const SOLID_DECAY := Vector3(0.56, 0.56, 0.56)
const WATER_DECAY := Vector3(0.88, 0.94, 0.97)
const LEAF_DECAY := Vector3(0.88, 0.91, 0.86)
const DECAY := [AIR_DECAY, SOLID_DECAY, WATER_DECAY, LEAF_DECAY]
const TORCH_COLOR := Vector3(1.0, 0.82, 0.55)

static func sky_color() -> Vector3:
	var f: float = TimeOfDay.day_factor()
	var night := Vector3(0.14, 0.18, 0.30)
	var twilight := Vector3(0.66, 0.44, 0.33)
	return night.lerp(twilight, f * 2.0) if f < 0.5 else twilight.lerp(Vector3.ONE, (f - 0.5) * 2.0)

static func emission(tile: int) -> Vector3:
	if tile == Tiles.TORCH or tile == Tiles.COOKING_POT: return TORCH_COLOR
	if tile == Tiles.SLIME_TORCH: return Vector3(0.35, 1.0, 0.60)
	if tile in [Tiles.LAVA, Tiles.LAVA_L1, Tiles.LAVA_L2, Tiles.LAVA_L3]: return Vector3(1.0, 0.38, 0.08)
	if tile in [143, 145, 146, 147]: return Vector3(0.14, 0.42, 0.88)
	return Vector3.ZERO

static func compute_region(cm: Node, x0: int, y0: int, x1: int, y1: int, extra_sources: Array = []) -> PackedByteArray:
	var w := x1 - x0
	var h := y1 - y0
	var size := w * h
	var result := PackedByteArray()
	result.resize(size * 4)
	if Legacy.force_full_bright:
		result.fill(255)
		return result
	var sky := PackedVector3Array()
	var lamps := PackedVector3Array()
	var masks := PackedByteArray() # 0 空气，1 实心，2 水，3 叶
	sky.resize(size)
	lamps.resize(size)
	masks.resize(size)
	var daylight := sky_color()
	var kinds := {}
	for x in range(x0, x1):
		var transmission := Vector3.ONE
		var column = cm.get_chunk(Chunk.chunk_x_of(x)) if cm.has_method("get_chunk") else null
		var tiles: Array = column.tiles[Chunk.local_x_of(x)] if column != null else []
		var natural_surface: int = column.surfaces[Chunk.local_x_of(x)] if column != null else -1
		var sky_top: int = -SkyLightGrid.depth_from_sky(x, 0) - 1
		# 从真实水面累计到视口顶，镜头往下移动时深水亮度不会突然重置。
		for y in range(0, maxi(0, y0)):
			var above: int = tiles[y] if not tiles.is_empty() and y < tiles.size() else cm.get_tile(x, y)
			if Tiles.is_water(above): transmission *= WATER_DECAY
		for y in range(y0, y1):
			var i := (y - y0) * w + x - x0
			var tile: int = tiles[y] if not tiles.is_empty() and y >= 0 and y < tiles.size() else cm.get_tile(x, y)
			if not kinds.has(tile):
				var mask := 2 if Tiles.is_water(tile) else (3 if tile == Tiles.LIVING_LEAF else (1 if Tiles.is_solid(tile) else 0))
				kinds[tile] = [mask, emission(tile)]
			var kind: Array = kinds[tile]
			masks[i] = kind[0]
			if masks[i] == 2: transmission *= WATER_DECAY
			if y <= sky_top:
				sky[i] = daylight * transmission
			elif y < natural_surface:
				var wall: int = cm.get_wall(x, y) if cm.has_method("get_wall") else Tiles.AIR
				if tile == Tiles.LIVING_WOOD or wall == Tiles.LIVING_WALL:
					sky[i] = daylight * transmission * 0.8
			lamps[i] = kind[1]
	for source in extra_sources:
		var p: Vector2i = source.position
		if p.x >= x0 and p.x < x1 and p.y >= y0 and p.y < y1:
			var i := (p.y - y0) * w + p.x - x0
			lamps[i] = lamps[i].max(source.color)
	_spread(sky, masks, w, h, true)
	_spread(lamps, masks, w, h, false)
	# 天光在土石内部逐层变暗，但不穿过整块屋顶再照亮密室。
	for pass_index in 4:
		var backwards := pass_index % 2 == 1
		for step in size:
			var i := size - 1 - step if backwards else step
			if masks[i] != 1: continue
			var value := sky[i]
			if i % w > 0: value = value.max(sky[i - 1] * SOLID_DECAY)
			if i % w < w - 1: value = value.max(sky[i + 1] * SOLID_DECAY)
			if i >= w: value = value.max(sky[i - w] * SOLID_DECAY)
			if i < size - w: value = value.max(sky[i + w] * SOLID_DECAY)
			sky[i] = value
	for i in size:
		var c := sky[i].max(lamps[i])
		result[i * 4] = clampi(roundi(c.x * 255.0), 0, 255) if c.x >= 0.018 else 0
		result[i * 4 + 1] = clampi(roundi(c.y * 255.0), 0, 255) if c.y >= 0.018 else 0
		result[i * 4 + 2] = clampi(roundi(c.z * 255.0), 0, 255) if c.z >= 0.018 else 0
		result[i * 4 + 3] = 255
	return result

static func _spread(grid: PackedVector3Array, masks: PackedByteArray, w: int, h: int, stop_at_solid: bool) -> void:
	# 两轮扫描让光能绕过拐角。每条扫描线只调用一次函数，避免网页每格的调用开销。
	for iteration in 2:
		for y in h:
			_sweep(grid, masks, y * w, 1, w, stop_at_solid)
			_sweep(grid, masks, (y + 1) * w - 1, -1, w, stop_at_solid)
		for x in w:
			_sweep(grid, masks, x, w, h, stop_at_solid)
			_sweep(grid, masks, (h - 1) * w + x, -w, h, stop_at_solid)

static func _sweep(grid: PackedVector3Array, masks: PackedByteArray, start: int, stride: int, count: int, stop_at_solid: bool) -> void:
	var carry := Vector3.ZERO
	var index := start
	for step in count:
		var mask: int = masks[index]
		var value := grid[index].max(carry * DECAY[mask])
		grid[index] = value
		carry = Vector3.ZERO if stop_at_solid and mask == 1 else value
		index += stride
