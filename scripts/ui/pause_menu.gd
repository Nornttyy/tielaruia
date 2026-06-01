# 暂停菜单: ESC 切换, 主面板 3 按钮 (继续 / 多人游戏 / 回主菜单).
# 多人游戏 → 子面板 HostPanel: 自动 host 当前世界, 显示 6 位房间码给朋友.
# CanvasLayer process_mode = ALWAYS, 暂停时仍响应输入.
# 由 main.gd 监听 ui_pause action 调 toggle.
extends CanvasLayer

signal return_to_menu

@onready var _resume_button: Button = $VBox/ResumeButton
@onready var _multiplayer_button: Button = $VBox/MultiplayerButton
@onready var _return_button: Button = $VBox/ReturnToMenuButton
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
	_close_button.pressed.connect(_on_host_close_pressed)
	# NetworkManager 信号 (autoload, 一直在). 用 host 反馈房间码 + 状态.
	if NetworkManager != null:
		if not NetworkManager.status_changed.is_connected(_on_mp_status_changed):
			NetworkManager.status_changed.connect(_on_mp_status_changed)
		if not NetworkManager.room_code_ready.is_connected(_on_mp_room_code_ready):
			NetworkManager.room_code_ready.connect(_on_mp_room_code_ready)
		if not NetworkManager.error_occurred.is_connected(_on_mp_error):
			NetworkManager.error_occurred.connect(_on_mp_error)
	# i18n: 切语言时刷新文字
	if Locale != null:
		if not Locale.language_changed.is_connected(_refresh_texts):
			Locale.language_changed.connect(_refresh_texts)
		_refresh_texts("")


# 静态文字按当前语言刷一遍. 切语言信号也调它.
func _refresh_texts(_new_lang: String) -> void:
	# 标题 + 按钮
	var title_lbl = $VBox/TitleLabel if has_node("VBox/TitleLabel") else null
	if title_lbl != null:
		title_lbl.text = Locale.t("pause_title")
	_resume_button.text = Locale.t("pause_resume")
	_multiplayer_button.text = Locale.t("pause_multiplayer")
	_return_button.text = Locale.t("pause_return_menu")
	_close_button.text = Locale.t("pause_mp_back")
	# Host 面板上的固定提示标签
	var hint = $HostPanel/VBox/HintLabel if has_node("HostPanel/VBox/HintLabel") else null
	if hint != null:
		hint.text = Locale.t("pause_mp_hint")
	var host_title = $HostPanel/VBox/TitleLabel if has_node("HostPanel/VBox/TitleLabel") else null
	if host_title != null:
		host_title.text = Locale.t("pause_mp_title")


func open() -> void:
	# 开暂停前先关箱子面板, 防双面板交互冲突 (老 bug: 同时打开点击穿透)
	var chest_p: CanvasLayer = get_tree().get_first_node_in_group("chest_panel")
	if chest_p == null:
		chest_p = get_tree().root.find_child("ChestPanel", true, false)
	if chest_p != null and chest_p.has_method("is_open") and chest_p.is_open():
		chest_p.close()
	# 关合成面板同理
	var craft_p: CanvasLayer = get_tree().get_first_node_in_group("crafting_panel")
	if craft_p != null and craft_p.has_method("is_open") and craft_p.is_open() and craft_p.has_method("close"):
		craft_p.close()
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


# ----- 多人游戏 (host 模式) -----

func _on_multiplayer_pressed() -> void:
	_vbox.visible = false
	_host_panel.visible = true
	# 已经在 host 状态就不重复 host (玩家可能开关菜单几次)
	if NetworkManager == null:
		_status_label.text = Locale.t("pause_mp_no_network")
		return
	if NetworkManager.is_host and NetworkManager.status in ["hosting", "connected"]:
		# 已经 host 过, 直接显示已有的房间码
		_room_code_label.text = NetworkManager.my_room_code if NetworkManager.my_room_code != "" else "------"
		_status_label.text = Locale.t("pause_mp_already_hosting") if NetworkManager.status == "hosting" else Locale.t("pause_mp_already_connected")
		return
	# 拿当前 world 的 seed 给 host (新 client 用同 seed 重建一致地形)
	var world: Node = get_tree().get_first_node_in_group("world")
	var seed_val: int = 0
	if world != null and "world_seed" in world:
		seed_val = int(world.world_seed)
	_room_code_label.text = Locale.t("pause_mp_room_pending")
	_status_label.text = Locale.t("pause_mp_room_wait")
	NetworkManager.host(seed_val, GameSettings.current_world_size)


func _on_host_close_pressed() -> void:
	_host_panel.visible = false
	_vbox.visible = true


func _on_mp_room_code_ready(code: String) -> void:
	if not _host_panel.visible:
		return
	_room_code_label.text = code
	_status_label.text = Locale.t("pause_mp_wait_for_join")


func _on_mp_status_changed(s: String) -> void:
	if not _host_panel.visible:
		return
	match s:
		"hosting": _status_label.text = Locale.t("pause_mp_hosting")
		"connected": _status_label.text = Locale.t("pause_mp_connected")
		"disconnected": _status_label.text = Locale.t("pause_mp_disconnected")
		"error": _status_label.text = Locale.t("pause_mp_error")
		_: pass


func _on_mp_error(msg: String) -> void:
	if not _host_panel.visible:
		return
	_status_label.text = Locale.t("pause_mp_error_prefix") + msg
