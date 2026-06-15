# 房主侧"接班顺序"纯逻辑. 维护客户端按加入顺序的列表, 算每个 pid 的 rank (第几个进的) +
# 掉线后该等多久再重进 (错峰). 不碰 JavaScriptBridge → headless 可单测.
# 用途: 房主一掉, 各客户端按自己的 rank * STAGGER 错峰重进原房号, rank 小的先抢到当新房主.
extends RefCounted

var _order: Array[String] = []   # 客户端 peer_id, 按加入先后

# 新客户端进房 (host 收到 __peer_join 时调). 已在表里则忽略 (幂等).
func on_join(pid: String) -> void:
	if pid != "" and not _order.has(pid):
		_order.append(pid)

# 客户端离开 (host 收到 __peer_leave 时调).
func on_leave(pid: String) -> void:
	_order.erase(pid)

# 当前加入顺序的副本.
func ordered() -> Array:
	return _order.duplicate()

# 某 pid 是第几个进的 (0 起); 不在表里返回 -1.
func rank_of(pid: String) -> int:
	return _order.find(pid)

# 该 pid 掉线后该等多久再重进 (秒). 在表里 = rank*stagger; 不在表里 = 排到所有人之后 ((size+1)*stagger),
# 防"还没分到接班号的新客户端"0 秒就抢着当房主.
func wait_for(pid: String, stagger: float) -> float:
	var r: int = rank_of(pid)
	if r < 0:
		return float(_order.size() + 1) * stagger
	return float(r) * stagger

func clear() -> void:
	_order.clear()
