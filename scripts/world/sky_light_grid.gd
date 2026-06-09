# 天光遮蔽: 查询某 tile 是否暴露在天空下 (无方块挡住).
# 列存改 Dictionary 懒填: 第一次查 column x 时算 _light_top[x], 之后缓存.
# 修改 tile 时由 World 调 invalidate_column(x) 清缓存.
extends Node

const ChunkConstants = preload("res://scripts/world/chunk_constants.gd")

# 空岛(浮岛)判定: 高空一薄层实心、下面紧跟空气 = 飘在空中, 阳光该绕过它继续往下找真地面.
# 不然空岛会像把大伞, 把它正下方一路到地面全判成"晒不到太阳"→ 一大块又宽又高的黑.
const FLOATING_MAX_TOP_Y := 50      # 只有顶端 y<50 的高空实心层才可能是浮岛 (真地表/山峰都比这低)
const FLOATING_MAX_THICKNESS := 16  # 浮岛厚度上限 (空岛中心约 9-12 格); 超过这么厚就当成真山不绕

var _light_top: Dictionary = {}  # int x → int top_solid_y (该列最顶的 solid tile 的 y; 找不到返回 WORLD_HEIGHT-1)


# 公开 API: 该 tile 是否在天空下
func is_sky_exposed(x: int, y: int) -> bool:
	# 世界顶之上 (y<0) = 开阔天空, 算"晒到天" → 飞高了头顶是亮天空, 不再是黑天花板。
	# 世界底之下 (y>=WORLD_HEIGHT) = 地底, 无天光。
	if y < 0:
		return true
	if y >= ChunkConstants.WORLD_HEIGHT:
		return false
	if not _light_top.has(x):
		_light_top[x] = _compute_light_top(x)
	return y <= _light_top[x]


# 公开 API: 该 (x, y) 离天光顶有多深 (单位: tile)
# 返回 0 = 自己在/上方就是天光顶 (该列地表层及以上)
# 返回 >0 = 地表下方 N 格
func depth_from_sky(x: int, y: int) -> int:
	if not _light_top.has(x):
		_light_top[x] = _compute_light_top(x)
	# _light_top 存的是"最后一个空气格" → 地表块在 _light_top + 1
	# 即: depth = y - (_light_top[x] + 1) = y - _light_top[x] - 1
	# y 在地表块以下时 depth 为正; y 在地表或以上时 depth <= 0
	return y - _light_top[x] - 1


# 由 World 在 set_tile 后调用
func invalidate_column(x: int, _tiles_unused: Variant = null) -> void:
	_light_top.erase(x)


# 兼容旧 API: 不再预算, 仅清缓存
func recompute_from(_tiles: Array) -> void:
	_light_top.clear()


# 从顶往下找第一个挡住天光的 solid tile, 返回它上方一格的 y. 找不到返回 WORLD_HEIGHT-1.
# 会跳过高空的"浮岛"(空岛): 阳光从两边绕过浮岛照到下方, 不该让浮岛在地面投下整列黑影.
func _compute_light_top(x: int) -> int:
	var cm: Node = get_tree().get_first_node_in_group("chunk_manager")
	if cm == null:
		return ChunkConstants.WORLD_HEIGHT - 1
	var y: int = 0
	while y < ChunkConstants.WORLD_HEIGHT:
		var tid: int = cm.get_tile(x, y)
		if tid != Tiles.AIR and Tiles.is_solid(tid):
			# 只在高空才考虑"这会不会是飘着的空岛"; 低处的山/地表一律当真地面.
			if y < FLOATING_MAX_TOP_Y:
				var float_skip: int = _floating_island_skip(cm, x, y)
				if float_skip > y:
					y = float_skip  # 是浮岛 → 跳过岛体, 从它下面继续找真地面
					continue
			return y - 1
		y += 1
	return ChunkConstants.WORLD_HEIGHT - 1


# 判断 y 处这串实心是不是"飘在地面上方的空岛". 是 → 返回岛体下方第一个空气格的 y
# (调用方从这里继续往下找真地面); 不是 → 返回 y 本身 (表示别跳, 照旧挡光).
# 空岛三条件: ① 够薄 (≤FLOATING_MAX_THICKNESS) ② 下面紧跟空气 ③ 更深处还有真地面.
# 第③条很关键: 空中孤块/玩家随手放的浮块下面一路空到底, 不算空岛, 仍正常挡光 (不破坏老行为).
func _floating_island_skip(cm: Node, x: int, y: int) -> int:
	var run_end: int = y
	while run_end < ChunkConstants.WORLD_HEIGHT:
		var rt: int = cm.get_tile(x, run_end)
		if rt == Tiles.AIR or not Tiles.is_solid(rt):
			break
		run_end += 1
	var run_len: int = run_end - y
	# 太厚 (真山) 或下面不是空气 (真地面顶) → 不是空岛
	if run_len > FLOATING_MAX_THICKNESS:
		return y
	if run_end >= ChunkConstants.WORLD_HEIGHT or cm.get_tile(x, run_end) != Tiles.AIR:
		return y
	# 下面是空气. 再确认更深处有真地面 (空岛飘在地面之上), 才放行阳光.
	for yy in range(run_end, ChunkConstants.WORLD_HEIGHT):
		var dt: int = cm.get_tile(x, yy)
		if dt != Tiles.AIR and Tiles.is_solid(dt):
			return run_end  # 找到下方地面 → 确认是空岛 → 跳到岛体下方继续找
	return y  # 下面一路空到底 → 空中孤块, 不放行
