# 暂停菜单: ESC 切换, 主面板 4 按钮 (继续 / 多人游戏 / 回主菜单 / 退出).
# 多人游戏 → 子面板 HostPanel: 自动 host 当前世界, 显示 6 位房间码给朋友.
# CanvasLayer process_mode = ALWAYS, 暂停时仍响应输入.
# 由 main.gd 监听 ui_pause action 调 toggle.
extends CanvasLayer

signal return_to_menu

@onready var _resume_button: Button = $VBox/ResumeButton
@onready var _multiplayer_button: Button = $VBox/MultiplayerButton
@onready var _return_button: Button = $VBox/ReturnToMenuButton
@onready var _quit_button: Button = $VBox/QuitButton
@onready var _vbox: VBoxContainer = $VBox
@onready var _host_panel: Panel = $HostPanel
@onready var _room_code_label: Label = $HostPanel/VBox/RoomCodeLabel
@onready var _status_label: Label = $HostPanel/VBox/StatusLabel
@onready var _close_button: Button = $HostPanel/VBox/CloseButton


func _ready() -> void:
	visible = false
	_resume_button.pressed.connect(_on_resume_pressed)
	_multiplayer_button.pressed.connect(_on_multiplayer_pressed)
	_return_button.pressed.connect(_on_return_to_menu_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_close_button.pressed.connect(_on_host_close_pressed)
	# NetworkManager 信号 (autoload, 一直在). 用 host 反馈房间码 + 状态.
	if NetworkManager != null:
		if not NetworkManager.status_changed.is_connected(_on_mp_status_changed):
			NetworkManager.status_changed.connect(_on_mp_status_changed)
		if not NetworkManager.room_code_ready.is_connected(_on_mp_room_code_ready):
			NetworkManager.room_code_ready.connect(_on_mp_room_code_ready)
		if not NetworkManager.error_occurred.is_connected(_on_mp_error):
			NetworkManager.error_occurred.connect(_on_mp_error)


func open() -> void:
	visible = true
	get_tree().paused = true
	# 每次开都回到主面板 (要看房间码再点一下 多人游戏 即可)
	_vbox.visible = true
	_host_panel.visible = false


func close() -> void:
	visible = false
	get_tree().paused = false


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _on_resume_pressed() -> void:
	close()


func _on_return_to_menu_pressed() -> void:
	# 回主菜单同时断联机 (不能带着 host 状态回去, 状态会乱)
	if NetworkManager != null and NetworkManager.status != "idle":
		NetworkManager.disconnect_room()
	return_to_menu.emit()


func _on_quit_pressed() -> void:
	get_tree().quit()


# ----- 多人游戏 (host 模式) -----

func _on_multiplayer_pressed() -> void:
	_vbox.visible = false
	_host_panel.visible = true
	# 已经在 host 状态就不重复 host (玩家可能开关菜单几次)
	if NetworkManager == null:
		_status_label.text = "NetworkManager 不在 (非 Web 平台?)"
		return
	if NetworkManager.is_host and NetworkManager.status in ["hosting", "connected"]:
		# 已经 host 过, 直接显示已有的房间码
		_room_code_label.text = NetworkManager.my_room_code if NetworkManager.my_room_code != "" else "------"
		_status_label.text = "已开放, 等朋友加入" if NetworkManager.status == "hosting" else "朋友已加入"
		return
	# 拿当前 world 的 seed 给 host (新 client 用同 seed 重建一致地形)
	var world: Node = get_tree().get_first_node_in_group("world")
	var seed_val: int = 0
	if world != null and "world_seed" in world:
		seed_val = int(world.world_seed)
	_room_code_label.text = "生成中..."
	_status_label.text = "请稍候"
	NetworkManager.host(seed_val)


func _on_host_close_pressed() -> void:
	_host_panel.visible = false
	_vbox.visible = true


func _on_mp_room_code_ready(code: String) -> void:
	if not _host_panel.visible:
		return
	_room_code_label.text = code
	_status_label.text = "等朋友输入此码加入"


func _on_mp_status_changed(s: String) -> void:
	if not _host_panel.visible:
		return
	match s:
		"hosting": _status_label.text = "已开放, 等朋友加入"
		"connected": _status_label.text = "朋友已加入, 联机中"
		"disconnected": _status_label.text = "已断开"
		"error": _status_label.text = "出错"
		_: pass


func _on_mp_error(msg: String) -> void:
	if not _host_panel.visible:
		return
	_status_label.text = "出错: " + msg
