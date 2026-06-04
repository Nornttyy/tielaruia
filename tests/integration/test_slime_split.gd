# 史莱姆分裂: 大/中打死裂成 2 只同色小一档; 小不裂.
extends GutTest

const SlimeScene = preload("res://scenes/entities/slime.tscn")


func after_each() -> void:
	# 清场: 分裂出的小史莱姆 (add 到 get_parent, 非 autofree) 别留到下个 test
	for n in get_tree().get_nodes_in_group("slimes"):
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			n.queue_free()
	await wait_frames(1)


func _count_slimes() -> int:
	return get_tree().get_nodes_in_group("slimes").size()


func test_large_splits_into_two_medium():
	var s = SlimeScene.instantiate()
	s.setup(2, 2)   # 红 + 大
	add_child_autofree(s)
	await wait_frames(2)
	var before: int = _count_slimes()
	s.take_damage(99999)   # 一击毙
	await wait_frames(3)    # 等分裂 spawn + 大史莱姆 queue_free
	var after: int = _count_slimes()
	# 大死了(-1) 但裂出 2 中(+2) → 净 +1
	assert_eq(after, before + 1, "大史莱姆裂成 2 只 (净 +1). before=%d after=%d" % [before, after])
	# 裂出的是同色(红) size=1(中)
	for n in get_tree().get_nodes_in_group("slimes"):
		if is_instance_valid(n) and n != s:
			assert_eq(n.color_tier, 2, "裂出的也是红")
			assert_eq(n.size, 1, "裂出的是中")


func test_small_does_not_split():
	var s = SlimeScene.instantiate()
	s.setup(1, 0)   # 蓝 + 小
	add_child_autofree(s)
	await wait_frames(2)
	var before: int = _count_slimes()
	s.take_damage(99999)
	await wait_frames(3)
	assert_eq(_count_slimes(), before - 1, "小史莱姆死了不裂 (净 -1)")
