extends GutTest

# 回归守卫: main.gd 启动时必须调 randomize() 给全局 RNG 重新播种。
# 原因: Godot 网页(HTML5)导出后, 全局 RNG 不会自动随机化 → 每次打开网页
# randi()/randi_range() 从同一起点 → 新世界种子永远一样, 地形一模一样。
# 桌面版本来就随机, 所以这个 bug 桌面测不出来; 这里只防这行被误删。
func test_main_calls_randomize_at_startup():
	var src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	var ready_idx: int = src.find("func _ready()")
	assert_gt(ready_idx, -1, "main.gd 应有 _ready()")
	# randomize() 应出现在 _ready 之后不久 (启动即播种)
	var rnd_idx: int = src.find("randomize()", ready_idx)
	assert_gt(rnd_idx, -1, "main.gd _ready() 里应调 randomize() (修网页版种子固定)")
