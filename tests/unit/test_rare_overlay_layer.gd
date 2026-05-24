extends GutTest

const RareOverlayLayer = preload("res://scripts/world/rare_overlay_layer.gd")


# 模拟 weather 信号源
class MockWeather:
	extends Node
	signal weather_changed(state: String)
	func emit_change(s: String) -> void:
		weather_changed.emit(s)


func test_rainbow_starts_idle():
	var rl: RareOverlayLayer = RareOverlayLayer.new()
	add_child_autofree(rl)
	await wait_frames(1)
	rl.setup_rainbow(null)
	await wait_frames(1)
	assert_false(rl.is_active(), "初始应 idle")


func test_rainbow_triggered_by_rainy_to_clear():
	var w := MockWeather.new()
	add_child_autofree(w)
	var rl: RareOverlayLayer = RareOverlayLayer.new()
	add_child_autofree(rl)
	await wait_frames(1)
	rl.setup_rainbow(w)
	await wait_frames(1)
	# 先 rainy 再 clear → 触发彩虹
	w.emit_change("rainy")
	w.emit_change("clear")
	await wait_frames(2)
	assert_true(rl.is_active(), "rainy→clear 应触发彩虹")


func test_force_activate_makes_active():
	var rl: RareOverlayLayer = RareOverlayLayer.new()
	add_child_autofree(rl)
	await wait_frames(1)
	rl.setup_aurora()
	rl.force_activate()
	await wait_frames(1)
	assert_true(rl.is_active(), "force_activate 应启动")
