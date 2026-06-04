# 按设备测速结果算"预加载半径" (出生点两边各几个 chunk). 纯函数, 不碰引擎状态 → 好测.
extends RefCounted

const TARGET_PRELOAD_MS := 2000.0   # 开局愿意花在预生成的预算 (~2s)
const MIN_RADIUS := 2
const MAX_RADIUS_WEB := 5            # 网页保守 (内存 + 单线程)
const MAX_RADIUS_DESKTOP := 16


# per_chunk_ms: 实测一个 chunk 生成多少毫秒; is_web: 是不是网页版; cores: CPU 核数.
# 返回出生点每侧预加载几个 chunk.
static func plan_view_radius(per_chunk_ms: float, is_web: bool, cores: int) -> int:
	var per: float = max(per_chunk_ms, 0.5)          # 防 0/负
	var budget_chunks: float = TARGET_PRELOAD_MS / per
	var radius: int = int(budget_chunks / 2.0)       # 预算两边分
	if cores >= 8:
		radius += 2                                  # 多核略加成
	var cap: int = MAX_RADIUS_WEB if is_web else MAX_RADIUS_DESKTOP
	return clampi(radius, MIN_RADIUS, cap)
