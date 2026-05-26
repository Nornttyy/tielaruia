# 调试面板 (F3 切换显示, 像 Minecraft 的 F3).
# 左上角 Label, 半透明黑底白字, 实时打印性能/状态数据.
extends Control

const REFRESH_INTERVAL := 0.5  # 0.5s 刷一次 (太频繁字符串拼接也吃帧)
const FPS_SAMPLE := 30         # 用最近 30 帧平均算 FPS (smooth)

@onready var label: Label = $Bg/Label

var _t: float = 0.0
var _frame_times: Array[float] = []   # 最近 N 帧的 frame time (ms)


func _ready() -> void:
	visible = false   # 默认隐藏, F3 才开
	set_process_unhandled_input(true)
	set_process(true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Godot 4: F3 = KEY_F3 = 4194336
		if event.keycode == KEY_F3:
			visible = not visible
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# 记最近帧时间 (即使隐藏也记, 这样切开瞬间就有真实数据)
	_frame_times.append(delta * 1000.0)
	if _frame_times.size() > FPS_SAMPLE:
		_frame_times.pop_front()
	if not visible:
		return
	_t += delta
	if _t < REFRESH_INTERVAL:
		return
	_t = 0.0
	label.text = _build_text()


func _avg_frame_ms() -> float:
	if _frame_times.is_empty():
		return 0.0
	var sum: float = 0.0
	for f in _frame_times:
		sum += f
	return sum / _frame_times.size()


func _build_text() -> String:
	var fps: float = Engine.get_frames_per_second()
	var frame_ms: float = _avg_frame_ms()
	var lines: Array[String] = []
	lines.append("FPS: %d   帧时间: %.1f ms" % [int(fps), frame_ms])
	# 实体计数
	var tree := get_tree()
	var n_slime: int = tree.get_nodes_in_group("slimes").size()
	var n_animal: int = tree.get_nodes_in_group("animals").size()
	var n_drop: int = tree.get_nodes_in_group("item_drops").size()
	lines.append("实体: slime=%d 动物=%d 掉落=%d" % [n_slime, n_animal, n_drop])
	# 世界状态
	var world: Node = tree.get_first_node_in_group("world")
	if world != null:
		var cm = world.get("chunk_manager")
		if cm != null:
			var n_chunks: int = (cm._loaded as Dictionary).size()
			lines.append("已加载 chunk: %d" % n_chunks)
		var ws = world.get("water_sim") if "water_sim" in world else null
		if ws != null and "_dirty" in ws:
			var dirty: int = (ws._dirty as Dictionary).size()
			lines.append("water dirty queue: %d" % dirty)
	# 玩家位置
	var player: Node = tree.get_first_node_in_group("player")
	if player != null and player is Node2D:
		var p: Vector2 = (player as Node2D).global_position
		lines.append("玩家: x=%.0f y=%.0f (tile %d, %d)" % [p.x, p.y, int(p.x / 16.0), int(p.y / 16.0)])
	# 联机状态
	if NetworkManager != null and NetworkManager.connected():
		var role: String = "host" if NetworkManager.is_host else "client"
		lines.append("联机: %s 房间=%s" % [role, NetworkManager.my_room_code])
	# 渲染统计 (Godot Performance)
	var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var prims: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	lines.append("draw_call: %d   顶点: %d" % [draw_calls, prims])
	return "\n".join(lines)
