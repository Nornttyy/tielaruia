# 玩家交互：鼠标瞄准、距离检查、挖放进度。
# 本 task 只做瞄准 + 触达。挖/放在 T9/T10 加。
extends Node2D

const TILE_SIZE := 16
const REACH_TILES := 4   # 玩家中心到目标 tile 中心的曼哈顿距离限制
const INVALID_TILE := Vector2i(-1, -1)

# 测试可注入瞄准坐标，绕开实际鼠标
var aim_override: Variant = null


func aim_tile_coord() -> Vector2i:
	if aim_override != null:
		return aim_override as Vector2i
	var terrain := _terrain()
	if terrain == null:
		return INVALID_TILE
	var mouse_world: Vector2 = terrain.get_global_mouse_position()
	return terrain.local_to_map(terrain.to_local(mouse_world))


func _terrain() -> TileMapLayer:
	return get_tree().get_first_node_in_group("terrain_layer") as TileMapLayer


# 玩家所在 tile（脚底参照点）
func player_tile() -> Vector2i:
	var parent: Node2D = get_parent() as Node2D
	var foot: Vector2 = parent.global_position
	return Vector2i(int(floor(foot.x / TILE_SIZE)), int(floor(foot.y / TILE_SIZE)))


func in_reach(tile: Vector2i) -> bool:
	if tile == INVALID_TILE:
		return false
	var pt: Vector2i = player_tile()
	return abs(tile.x - pt.x) <= REACH_TILES and abs(tile.y - pt.y) <= REACH_TILES
