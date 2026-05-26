# 加载层: 暮色背景 + 玩家像素小人跑步 + 真实进度条 + 可点击切换小贴士.
# 由 main.gd 在 _start_game 中 instantiate, 加载过程一步一步调 set_progress 推进.
extends CanvasLayer

signal finished     # 淡出动画结束 → main.gd queue_free 它


func _ready() -> void:
	pass
