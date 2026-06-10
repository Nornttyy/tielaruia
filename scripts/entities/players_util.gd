# 联机多人: 统一"找玩家"。同时认本地玩家 ("player" 组) + 加入的玩家 ("remote_player" 组)。
# 怪的追击/刷怪定位用 nearest_player → 怪会追/刷在"最近的人"身边, 不再只盯房主。
# 单机时 remote_player 组为空 → 退化成只认本地玩家, 行为不变。
extends RefCounted


static func all_players(tree: SceneTree) -> Array:
	var out: Array = []
	for grp in ["player", "remote_player"]:
		for p in tree.get_nodes_in_group(grp):
			if is_instance_valid(p):
				out.append(p)
	return out


# 离 from_pos 最近的玩家 (含远程). 没有玩家返回 null。
static func nearest_player(tree: SceneTree, from_pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d: float = INF
	for p in all_players(tree):
		var d: float = from_pos.distance_to((p as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = p as Node2D
	return best
