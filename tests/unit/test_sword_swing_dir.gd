# 挥剑方向: 瞄左该往左挥、瞄右该往右挥. 修"瞄左却往右挥"的 bug.
# bug: play_swing_directional 把角度乘 facing 符号 s, 让左/右瞄算出同一个起手角 → 永远往同一边挥.
extends GutTest

const HeldItem = preload("res://scripts/player/held_item.gd")


func _make_held() -> Node:
	var h = HeldItem.new()
	add_child_autofree(h)
	h.visible = true   # play_swing_directional 在 not visible 时直接 return
	return h


func test_left_and_right_swing_differ():
	var h = _make_held()
	h.play_swing_directional(0.0)      # 瞄右
	var right_start: float = h.rotation
	h.play_swing_directional(PI)       # 瞄左
	var left_start: float = h.rotation
	assert_ne(right_start, left_start, "瞄左和瞄右起手角必须不同 (相等=永远往同一边挥, 就是这个 bug)")


func test_swing_starts_upward_both_sides():
	# 修"瞄左从下往上挑"的 bug: 不管瞄左瞄右, 挥剑起手都该剑尖朝上 (上往下劈)。
	# 剑尖默认 (0,-1), 旋转 rot 后 y 分量 = -cos(rot); <0 = 朝上 → 即 cos(rot) > 0。
	var h = _make_held()
	h.play_swing_directional(0.0)            # 瞄右
	assert_gt(cos(h.rotation), 0.0, "瞄右: 挥剑起手剑尖该朝上 (上往下劈)")
	h.play_swing_directional(PI)             # 瞄左
	assert_gt(cos(h.rotation), 0.0, "瞄左: 挥剑起手剑尖也该朝上 (不是从下往上挑)")
