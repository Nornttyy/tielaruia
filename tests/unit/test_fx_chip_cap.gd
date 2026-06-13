# 性能优化验收: 碎片粒子有全局上限, 战斗特效爆发时不会无限生节点 (网页/手机防卡)。
extends GutTest


func test_chip_count_capped() -> void:
	# 狂放爆炸 (每次 30 颗) 远超上限 → 存活碎片数不超过 MAX_CHIPS
	for i in 100:
		Effects.spawn_explosion(Vector2(i * 4, 0), Color8(255, 150, 40))
	await wait_frames(1)
	assert_lte(Effects._chip_count, Effects.MAX_CHIPS, "存活碎片不超全局上限")
	assert_gt(Effects._chip_count, 0, "正常情况下还是有碎片冒出来")


func test_chips_decrement_after_lifetime() -> void:
	# 碎片 0.5s 后自删 → 计数回落 (不泄漏)
	for i in 5:
		Effects.spawn_explosion(Vector2(0, 0), Color8(120, 200, 60))
	await wait_frames(1)
	var peak: int = Effects._chip_count
	assert_gt(peak, 0, "先冒出一批碎片")
	await wait_frames(50)   # 等过寿命 (0.5s @ 60fps ≈ 30 帧)
	assert_lt(Effects._chip_count, peak, "过了寿命碎片数该回落 (tree_exited 减计数)")
