# 诊断: chunk 加载后水该"已经流完"(settle), 玩家看到的不该还在流.
# 量加载后极短时间内 water_sim._dirty 还剩多少 (剩很多 = settle 没流完, 玩家会看到水在动).
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_water_settled_right_after_load() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game(42)
	await wait_frames(2)   # 出生 chunk 刚加载完 (settle_now 已在 _on_chunk_loaded 里跑过)
	var ws = main.get_node("World").water_sim
	var d2: int = ws._dirty.size() if ws != null else -1
	gut.p("[诊断] 加载后第2帧 _dirty=%d (≈0 = settle 流完了; 很多 = settle 没跑, 玩家看到一片水在流)" % d2)
	# settle_now 在 _on_chunk_loaded 里跑过 → 加载后该基本流完 (只剩零星几格), 不该有几百格在流.
	assert_lt(d2, 60, "加载后水该已 settle 流完 (剩 %d 格, 太多=settle 没生效)" % d2)
	await wait_frames(20)
	var d_late: int = ws._dirty.size() if ws != null else -1
	gut.p("[诊断] 第22帧 _dirty=%d (该 0 = 彻底静)" % d_late)
