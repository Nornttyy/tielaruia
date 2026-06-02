extends GutTest

const FishingClass = preload("res://scripts/player/player_fishing.gd")
var fish

func before_each():
	fish = FishingClass.new()
	add_child_autofree(fish)

# 对水甩竿 → waiting; 对非水 → 仍 idle
func test_cast_needs_water():
	fish.on_rod_click(Vector2i(5, 5), false)   # 非水
	assert_eq(fish.state(), "idle", "对非水不该开钓")
	fish.on_rod_click(Vector2i(5, 5), true)    # 水
	assert_eq(fish.state(), "waiting", "对水应进入等待")

# waiting → 咬钩 → biting
func test_wait_to_bite():
	fish.on_rod_click(Vector2i(5, 5), true)
	fish._force_bite()
	assert_eq(fish.state(), "biting", "应进入咬钩窗口")

# biting 内收竿 → 钓到 (caught 信号) + 回 idle
func test_reel_success_catches():
	watch_signals(fish)
	fish.on_rod_click(Vector2i(5, 5), true)
	fish._force_bite()
	fish.on_rod_click(Vector2i(5, 5), true)     # 收竿
	assert_signal_emitted(fish, "caught")
	assert_eq(fish.state(), "idle", "收完回 idle")

# biting 超时 → 鱼跑, 无 caught, 回 idle
func test_bite_timeout_escapes():
	watch_signals(fish)
	fish.on_rod_click(Vector2i(5, 5), true)
	fish._force_bite()
	for i in 120:
		fish._process(1.0 / 60.0)               # 模拟 2s > REEL_WINDOW(1.5)
	assert_signal_not_emitted(fish, "caught", "超时不该钓到")
	assert_eq(fish.state(), "idle")

# 收获都在 9 种海鲜里 (权重抽样)
func test_catch_in_valid_set():
	var valid := ["salmon", "tuna", "octopus", "sea_urchin", "lobster", "eel", "sweet_shrimp", "scallop", "seaweed"]
	for i in 50:
		var got: String = fish._roll_catch()
		assert_true(got in valid, "%s 应是 9 种海鲜之一" % got)
