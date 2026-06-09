# 多人公共房纯逻辑 helper. 不碰 JavaScriptBridge → headless 可单测.
# 为什么单独成文件: 把"能不能测"的决策逻辑从 web-only 的 NetworkManager 里抽出来.
extends RefCounted

# 公共生存房固定世界 (每次进都同一张地图, 玩家才有"这就是那个服务器"的感觉)
const PUBLIC_SV_SEED := 20260609
const PUBLIC_SV_SIZE := 1   # 0小/1中/2大
const PUBLIC_SV_DIFF := 1   # 0简/1普/2难

const MAX_PEERS := 8        # 每房最多人数 (含 host 自己)
const MAX_ROOMS := 20       # 公共房顺延上限 (房号 1..MAX_ROOMS)
const HOST_PID := "HOST"    # client 眼里 host 玩家的 peer id

# 固定房号: teilaruia-PUB-<tag>-<index> (生存房 tag="SV")
static func public_peer_id(tag: String, index: int) -> String:
	return "teilaruia-PUB-%s-%d" % [tag, index]

# 玩家个体状态消息 (host 要给它盖来源 pid 再上报/转发)
const _PLAYER_TYPES := {"pos": true, "name": true, "chat": true, "pdead": true, "pres": true}

# host 收到 client 这些类型 → 转发给其它 client (玩家个体 + 世界改动).
# ent_dmg/drop_req 不在内: host 要先权威处理. hello/ent_pos/time 等 host 独有.
const _RELAY_TYPES := {
	"pos": true, "name": true, "chat": true, "pdead": true, "pres": true,
	"tile": true, "tile_batch": true, "chest": true, "drop_pick": true,
}

static func is_player_type(msg_type: String) -> bool:
	return _PLAYER_TYPES.has(msg_type)

static func is_relay_type(msg_type: String) -> bool:
	return _RELAY_TYPES.has(msg_type)

# host 收到来自 from_peer 的 msg_type → 该转发给哪些 peer (除来源外, 防回声)
static func relay_targets(msg_type: String, from_peer: String, all_peers: Array) -> Array:
	if not is_relay_type(msg_type):
		return []
	var out: Array = []
	for p in all_peers:
		if String(p) != from_peer:
			out.append(String(p))
	return out
