# 暂停菜单: ESC 切换, 主面板 3 按钮 (继续 / 多人游戏 / 回主菜单).
# 多人游戏 → 子面板 HostPanel: 自动 host 当前世界, 显示 6 位房间码给朋友.
# CanvasLayer process_mode = ALWAYS, 暂停时仍响应输入.
# 由 main.gd 监听 ui_pause action 调 toggle.
extends CanvasLayer

const UIStyle = preload("res://scripts/ui/ui_style.gd")

signal return_to_menu

@onready var _resume_button: Button = $VBox/ResumeButton
@onready var _multiplayer_button: Button = $VBox/MultiplayerButton
@onready var _return_button: Button = $VBox/ReturnToMenuButton
@onready var _creative_button: Button = $VBox/CreativeButton
@onready var _vbox: VBoxContainer = $VBox
@onready var _host_panel: Panel = $HostPanel
@onready var _room_code_label: Label = $HostPanel/VBox/RoomCodeLabel
@onready var _status_label: Label = $HostPanel/VBox/StatusLabel
@onready var _close_button: Button = $HostPanel/VBox/CloseButton


func _ready() -> void:
	visible = false
	# 蓝色按钮 + 蓝色子面板 (统一风格)
	for b in [_resume_button, _multiplayer_button, _return_button, _creative_button, _close_button]:
		UIStyle.style_button(b)
	_host_panel.add_theme_stylebox_override("panel", UIStyle.panel())
	_resume_button.pressed.connect(_on_resume_pressed)
	_multiplayer_button.pressed.connect(_on_multiplayer_pressed)
	_return_button.pressed.connect(_on_return_to_menu_pressed)
	_creative_button.pressed.connect(_on_creative_pressed)
	_close_button.pressed.connect(_on_host_close_pressed)
	_build_kick_ui()
	_build_mp_settings()
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
	if _kick_button != null:
		_kick_button.text = Locale.t("pause_kick")
	# Host 面板上的固定提示标签
	var hint = $HostPanel/VBox/HintLabel if has_node("HostPanel/VBox/HintLabel") else null
	if hint != null:
		hint.text = Locale.t("pause_mp_hint")
	var host_title = $HostPanel/VBox/TitleLabel if has_node("HostPanel/VBox/TitleLabel") else null
	if host_title != null:
		host_title.text = Locale.t("pause_mp_title")


# ===== 踢人 (房主) =====
var _kick_button: Button = null
var _kick_panel: Panel = null
var _kick_list: VBoxContainer = null
var _close_mp_button: Button = null   # 房主"关闭联机"按钮: 停房间但留在当前世界继续玩


func _build_kick_ui() -> void:
	# 踢人按钮: 加到主面板按钮列里 (放"多人游戏"按钮下面). 只房主+联机时显示。
	_kick_button = Button.new()
	_kick_button.text = "踢人"
	UIStyle.style_button(_kick_button)
	_kick_button.pressed.connect(_on_kick_pressed)
	_vbox.add_child(_kick_button)
	_vbox.move_child(_kick_button, _multiplayer_button.get_index() + 1)
	_kick_button.visible = false
	# 关闭联机按钮: 房主点了停止房间 (断开所有人), 自己留在当前世界继续单机玩, 不退回主菜单。
	# 放在"多人游戏"按钮正下方 (= 开/关联机挨着). 只房主 + 联机时显示 (跟踢人同条件)。
	_close_mp_button = Button.new()
	_close_mp_button.text = "关闭联机"
	UIStyle.style_button(_close_mp_button)
	_close_mp_button.pressed.connect(_on_close_mp_pressed)
	_vbox.add_child(_close_mp_button)
	_vbox.move_child(_close_mp_button, _multiplayer_button.get_index() + 1)
	_close_mp_button.visible = false
	# 踢人面板 (列玩家 + 踢按钮), 代码建, 默认隐藏
	_kick_panel = Panel.new()
	_kick_panel.add_theme_stylebox_override("panel", UIStyle.panel())
	_kick_panel.set_anchors_preset(Control.PRESET_CENTER)
	_kick_panel.custom_minimum_size = Vector2(320, 360)
	_kick_panel.size = Vector2(320, 360)
	_kick_panel.position = Vector2(-160, -180)
	_kick_panel.visible = false
	add_child(_kick_panel)
	var vb := VBoxContainer.new()
	vb.position = Vector2(16, 16)
	vb.custom_minimum_size = Vector2(288, 0)
	vb.add_theme_constant_override("separation", 8)
	_kick_panel.add_child(vb)
	var title := Label.new()
	title.text = "踢出玩家"
	title.add_theme_font_size_override("font_size", 20)
	vb.add_child(title)
	_kick_list = VBoxContainer.new()
	_kick_list.add_theme_constant_override("separation", 6)
	vb.add_child(_kick_list)
	var back := Button.new()
	back.text = "返回"
	UIStyle.style_button(back)
	back.pressed.connect(func(): _kick_panel.visible = false; _vbox.visible = true)
	vb.add_child(back)


# 多人设置 (用户要求: 从主菜单挪到游戏里的"多人游戏"面板). 建在 HostPanel/VBox, 关闭按钮上方.
func _build_mp_settings() -> void:
	var vb: VBoxContainer = $HostPanel/VBox if has_node("HostPanel/VBox") else null
	if vb == null:
		return
	var sec := Label.new()
	sec.text = "多人设置"
	sec.add_theme_font_size_override("font_size", 14)
	sec.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	vb.add_child(sec)
	# 显示玩家名字 / 允许聊天 (随时可改)
	vb.add_child(_mp_checkbox_row("显示玩家名字", GameSettings.mp_show_names,
		func(p: bool): GameSettings.mp_show_names = p))
	vb.add_child(_mp_checkbox_row("允许聊天", GameSettings.mp_chat_enabled,
		func(p: bool): GameSettings.mp_chat_enabled = p))
	# 房间最多人数 (开公共房用; 存下来下次进房生效)
	var max_row := HBoxContainer.new()
	var max_lbl := Label.new(); max_lbl.text = "房间最多人数"; max_lbl.custom_minimum_size = Vector2(120, 0)
	max_row.add_child(max_lbl)
	var sld := HSlider.new()
	sld.min_value = 2; sld.max_value = 8; sld.step = 1; sld.value = GameSettings.mp_max_players
	sld.custom_minimum_size = Vector2(100, 0); sld.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyle.style_slider(sld)
	var val := Label.new(); val.text = str(GameSettings.mp_max_players); val.custom_minimum_size = Vector2(22, 0)
	sld.value_changed.connect(func(v: float):
		GameSettings.mp_max_players = int(v)
		val.text = str(int(v)))
	max_row.add_child(sld); max_row.add_child(val)
	vb.add_child(max_row)
	# 联机难度 (开房用)
	var diff_row := HBoxContainer.new()
	var diff_lbl := Label.new(); diff_lbl.text = "联机难度"; diff_lbl.custom_minimum_size = Vector2(120, 0)
	diff_row.add_child(diff_lbl)
	var opt := OptionButton.new()
	opt.add_item("简单"); opt.add_item("普通"); opt.add_item("困难")
	opt.selected = clampi(GameSettings.mp_host_difficulty, 0, 2)
	opt.item_selected.connect(func(i: int): GameSettings.mp_host_difficulty = i)
	diff_row.add_child(opt)
	vb.add_child(diff_row)
	# "关闭"按钮挪到最底 (设置显示在它上面)
	if _close_button != null:
		vb.move_child(_close_button, -1)


func _mp_checkbox_row(text: String, initial: bool, on_toggle: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var lbl := Label.new(); lbl.text = text; lbl.custom_minimum_size = Vector2(120, 0)
	row.add_child(lbl)
	var cb := CheckBox.new(); cb.button_pressed = initial
	cb.toggled.connect(on_toggle)
	row.add_child(cb)
	return row


func _on_kick_pressed() -> void:
	_vbox.visible = false
	_kick_panel.visible = true
	_refresh_kick_list()


func _refresh_kick_list() -> void:
	for c in _kick_list.get_children():
		c.free()
	var world: Node = get_tree().get_first_node_in_group("world")
	var players: Array = []
	if world != null and world.has_method("get_remote_player_list"):
		players = world.get_remote_player_list()
	if players.is_empty():
		var empty := Label.new()
		empty.text = "房间里暂时没别人"
		_kick_list.add_child(empty)
		return
	for p in players:
		var row := HBoxContainer.new()
		var nm := Label.new()
		nm.text = String(p.get("name", "玩家"))
		nm.custom_minimum_size = Vector2(200, 0)
		row.add_child(nm)
		var kbtn := Button.new()
		kbtn.text = "踢"
		UIStyle.style_button(kbtn)
		var pid: String = String(p.get("id", ""))
		kbtn.pressed.connect(func():
			if NetworkManager != null:
				NetworkManager.kick_peer(pid)
			_refresh_kick_list())
		row.add_child(kbtn)
		_kick_list.add_child(row)


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
	# 公共房本来就是多人游戏 → 不显示"多人游戏/踢人/关闭联机" (这些是用来开/管自己私人房的).
	var in_public: bool = NetworkManager != null and NetworkManager.is_public_room()
	_multiplayer_button.visible = not in_public
	# 踢人 + 关闭联机: 只"私人房房主"显示 (公共房不显示)
	var host_online: bool = NetworkManager != null and NetworkManager.connected() and NetworkManager.is_host and not in_public
	if _kick_button != null:
		_kick_button.visible = host_online
	if _close_mp_button != null:
		_close_mp_button.visible = host_online
	if _kick_panel != null:
		_kick_panel.visible = false
	_host_panel.visible = false
	_refresh_creative_text()
	_update_creative_availability()


# 联机房 (生存房/对战房) 不让改游戏模式 — 大家得统一是生存, 不然有人创造飞天秒挖不公平.
# 联机时直接把"创造模式"按钮藏掉.
func _update_creative_availability() -> void:
	if _creative_button == null:
		return
	var mp: bool = NetworkManager != null and NetworkManager.connected()
	_creative_button.visible = not mp


func _on_creative_pressed() -> void:
	# 联机时禁止切游戏模式 (按钮本已藏, 这里再兜底防止信号被别处触发)
	if NetworkManager != null and NetworkManager.connected():
		return
	if GameSettings != null:
		GameSettings.creative_mode = not GameSettings.creative_mode
	_refresh_creative_text()


func _refresh_creative_text() -> void:
	if _creative_button != null and GameSettings != null:
		_creative_button.text = "创造模式: 开" if GameSettings.creative_mode else "创造模式: 关"


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


func _on_close_mp_pressed() -> void:
	# 关闭联机: 停掉房间 (断开所有人), 但不回主菜单 — 房主留在当前世界继续单机玩。
	if NetworkManager != null and NetworkManager.status != "idle":
		NetworkManager.disconnect_room()
	close()   # 收起暂停菜单, 恢复游戏 (留在世界里)


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
	NetworkManager.host(seed_val, GameSettings.current_world_size, GameSettings.current_difficulty)


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
