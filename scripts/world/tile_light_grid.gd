# 瓦片级光照计算 (Terraria 风)。
# 光值 0..7 (0=全黑, 7=满亮)。
# 来源:
#   - 天空暴露 (SkyLightGrid.is_sky_exposed): 7
#   - 玩家位置: 2 tile 半径内, 距离越近越亮 (~3)
#   - 火把 tile: 6 tile 半径内, 距离衰减
# 注意: 简化版不做 BFS 传播 (墙不挡光), 直接按曼哈顿距离取 max。
#       V2 可改 BFS + 衰减以模拟墙挡光。
extends RefCounted

const MAX_LIGHT := 7

const PLAYER_RADIUS := 2
const PLAYER_PEAK := 3

const TORCH_RADIUS := 6
const TORCH_PEAK := 7   # 火把中心满亮


# 算单个 tile 光值。
# 入参:
#   x, y: 世界 tile 坐标
#   player_tile: 玩家所在 tile (Vector2i)
#   torch_tiles: 已放置火把的 tile 坐标 Array (Vector2i)
# 返回 0..MAX_LIGHT。
const SKY_DEPTH_LIT := 5   # 地表往下 5 格内仍有天光衰减


static func compute_light(x: int, y: int, player_tile: Vector2i, torch_tiles: Array) -> int:
	var light: int = 0
	# 1. 天空暴露: 用 TimeOfDay 当前光值 (白天=7, 夜间=2, 黄昏/黎明 lerp)
	#    地表往下 1..SKY_DEPTH_LIT 格 → 在天光值基础上再衰减
	#    SkyLightGrid.is_sky_exposed 只算"地表上方空气", 地表块自己 depth=0 也要算
	var sky_light: int = TimeOfDay.sky_light_level()
	if SkyLightGrid.is_sky_exposed(x, y):
		return sky_light
	var depth: int = SkyLightGrid.depth_from_sky(x, y)
	if depth <= 0:
		return sky_light
	if depth <= SKY_DEPTH_LIT:
		# depth=1 → sky-1, depth=2 → sky-2, ... 夜间深处自然黑
		light = max(light, sky_light - depth)
	# 2. 玩家光圈
	var dp_x: int = abs(x - player_tile.x)
	var dp_y: int = abs(y - player_tile.y)
	var dp: int = dp_x + dp_y  # 曼哈顿距离
	if dp <= PLAYER_RADIUS:
		var pl: int = max(0, PLAYER_PEAK - dp)
		if pl > light:
			light = pl
	# 3. 火把光圈
	for t in torch_tiles:
		var dt_x: int = abs(x - t.x)
		var dt_y: int = abs(y - t.y)
		# 用切比雪夫距离 (max) 让光圈接近圆形而非菱形
		var dt: int = max(dt_x, dt_y)
		if dt <= TORCH_RADIUS:
			var tl: int = max(0, TORCH_PEAK - dt)
			if tl > light:
				light = tl
	return clampi(light, 0, MAX_LIGHT)
