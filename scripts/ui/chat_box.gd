# 联机聊天框 (CanvasLayer)。只在联机 (NetworkManager.connected()) 时起作用。
# - 按【回车】弹出输入框打字 → 再【回车】发送 / 【Esc】取消。
#   打字时加入 "chat_typing" 组 → player_controller / player_action 检测到就不让玩家走动/挖砍。
# - 左下角显示最近几条消息, 每条几秒后自动淡掉 (像 Minecraft 聊天栏)。
# - 发/收消息时, 在对应玩家 (本地 / 对方) 头顶冒文字气泡 (Effects.spawn_speech_bubble)。
extends CanvasLayer

const MAX_LOG := 5            # 聊天栏最多同时显示几条
const LINE_LIFETIME := 8.0    # 每条消息多久后淡掉
const HEAD_OFFSET := Vector2(0, -20)   # 玩家位置 → 头顶气泡锚点

var _log_vbox: VBoxContainer
var _input_field: LineEdit       # 注: 不能叫 _input — 跟 Godot 虚函数 _input() 同名会解析报错
var _typing: bool = false


func _ready() -> void:
	layer = 45   # 世界之上、HUD(50) 之下
	add_to_group("chat_box")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	if NetworkManager != null and NetworkManager.has_signal("chat_received"):
		NetworkManager.chat_received.connect(_on_chat_received)


func _build_ui() -> void:
	# 左下聊天栏 (从底往上堆)
	_log_vbox = VBoxContainer.new()
	_log_vbox.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_log_vbox.offset_left = 12.0
	_log_vbox.offset_bottom = -44.0   # 给底部输入框留位置
	_log_vbox.grow_vertical = Control.GROW_DIRECTION_BEGIN   # 往上长
	_log_vbox.add_theme_constant_override("separation", 2)
	_log_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_log_vbox)
	# 底部输入框 (平时隐藏)
	_input_field = LineEdit.new()
	_input_field.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_input_field.offset_left = 12.0
	_input_field.offset_right = -12.0
	_input_field.offset_top = -36.0
	_input_field.offset_bottom = -10.0
	_input_field.placeholder_text = "说点什么…  (回车发送 · Esc 取消)"
	_input_field.max_length = 120
	_input_field.visible = false
	_input_field.text_submitted.connect(_on_submit)
	add_child(_input_field)


func is_typing() -> bool:
	return _typing


func _input(event: InputEvent) -> void:
	# 只在联机时响应
	if NetworkManager == null or not NetworkManager.connected():
		return
	# 设置里关了聊天 → 不响应按键 (打字中也收起)
	if GameSettings != null and not GameSettings.mp_chat_enabled:
		if _typing:
			_close_input()
		return
	var ke := event as InputEventKey
	if ke == null or not ke.pressed or ke.echo:
		return
	var kc: int = ke.keycode
	if not _typing and kc == KEY_T:
		# 像 Minecraft: 按 T 开聊天框 (发送还是回车). 别人面板 (背包/箱子) 开着时不抢键
		if _other_panel_open():
			return
		_open_input()
		get_viewport().set_input_as_handled()
	elif _typing and kc == KEY_ESCAPE:
		_close_input()
		get_viewport().set_input_as_handled()


func _other_panel_open() -> bool:
	for grp in ["crafting_panel", "chest_panel"]:
		var p: Node = get_tree().get_first_node_in_group(grp)
		if p != null and p.has_method("is_open") and p.is_open():
			return true
	return false


func _open_input() -> void:
	_typing = true
	add_to_group("chat_typing")   # 玩家移动/动作据此暂停
	_input_field.text = ""
	_input_field.visible = true
	_input_field.grab_focus()


func _close_input() -> void:
	_typing = false
	remove_from_group("chat_typing")
	_input_field.visible = false
	_input_field.release_focus()


func _on_submit(text: String) -> void:
	var t: String = text.strip_edges()
	if t != "" and NetworkManager != null:
		NetworkManager.send_chat(t)
		_bubble_over("player", t)               # 自己头顶冒
		_add_log(_local_name() + ": " + t)
	_close_input()


func _on_chat_received(peer_id: String, text: String) -> void:
	if text == "":
		return
	# 设置里关了聊天 → 不显示别人发来的消息
	if GameSettings != null and not GameSettings.mp_chat_enabled:
		return
	# 气泡冒在发话那个 peer 的远程玩家头顶 (多人: 不同人冒不同头顶)
	var rp: Node2D = _remote_player_node(peer_id)
	if rp != null and Effects != null:
		Effects.spawn_speech_bubble(rp.global_position + HEAD_OFFSET, text)
	_add_log(_remote_name(peer_id) + ": " + text)


# 自己头顶冒气泡 (本地玩家在 "player" 组)
func _bubble_over(group_name: String, text: String) -> void:
	var node: Node2D = get_tree().get_first_node_in_group(group_name) as Node2D
	if node != null and Effects != null:
		Effects.spawn_speech_bubble(node.global_position + HEAD_OFFSET, text)


# 找某 peer 的远程玩家节点 (world 按 peer_id 管理). peer_id 空 → 退回任意一个远程玩家.
func _remote_player_node(peer_id: String) -> Node2D:
	var world: Node = get_tree().get_first_node_in_group("world")
	if world != null and world.has_method("get_remote_player") and peer_id != "":
		var rp = world.get_remote_player(peer_id)
		if rp != null and is_instance_valid(rp):
			return rp as Node2D
	return get_tree().get_first_node_in_group("remote_player") as Node2D


func _add_log(line: String) -> void:
	var lbl := Label.new()
	lbl.text = line
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_vbox.add_child(lbl)
	# 超过上限删最老的 (最上面那条)
	while _log_vbox.get_child_count() > MAX_LOG:
		_log_vbox.get_child(0).queue_free()
	# 几秒后淡掉自删
	var tw := lbl.create_tween()
	tw.tween_interval(LINE_LIFETIME)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.0)
	tw.tween_callback(lbl.queue_free)


func _local_name() -> String:
	if GameSettings != null and GameSettings.player_name != "":
		return GameSettings.player_name
	return "我"


func _remote_name(peer_id: String = "") -> String:
	if NetworkManager != null:
		# 多人: 按 peer 取各自名字 (防串台); 退回最近收到的对方名, 再退 "对方"
		var by_peer: String = NetworkManager.name_for_peer(peer_id) if peer_id != "" else ""
		if by_peer != "":
			return by_peer
		if NetworkManager.remote_player_name != "":
			return NetworkManager.remote_player_name
	return "对方"
