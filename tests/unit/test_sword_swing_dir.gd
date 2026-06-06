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


func test_left_right_differ_by_180():
	# 瞄左瞄右相差 180°, 起手角也该差 ~180° (跟着瞄的方向走). bug 时差 0.
	var h = _make_held()
	h.play_swing_directional(0.0)
	var right_start: float = h.rotation
	h.play_swing_directional(PI)
	var left_start: float = h.rotation
	var d: float = wrapf(right_start - left_start, -PI, PI)
	assert_almost_eq(absf(d), PI, 0.05, "瞄左瞄右起手角应差 ~180° (实测差 %.2f°)" % rad_to_deg(absf(d)))
