# 对战房模式选择面板 + 常驻"切换模式"按钮 (击杀榜左边)。
# 三种对战: 经典(剑+弓) / 魔法(选 1 种法杖) / 枪械(选 1 种枪)。
# 不同模式 = 不同房间: 经典→公共房 PVP, 魔法→PVP-MAGIC, 枪械→PVP-GUN。选了别的模式会自动
# 断开重连到那个模式的公共房 (竞技场布局固定不变, 只是换成跟同模式的人一起)。同模式里换武器
# 只换装备不换房。非对战房 (生存/起床战争) 永不弹、按钮也不显示。
#
# 注意: CanvasLayer 本身一直 visible (否则常驻按钮也会被一起藏); 只切里面 _panel 的 visible。
# 开面板时暂停游戏 (paused) → 滚轮选枪不会同时缩放镜头 + 进游戏强制先选模式。
extends CanvasLayer

const UIStyle = preload("res://scripts/ui/ui_style.gd")
const MpRooms = preload("res://scripts/net/mp_rooms.gd")

const _MODE_TAG := {"classic": "PVP", "magic": "PVP-MAGIC", "gun": "PVP-GUN"}
const _COMMON := [["stone", 64], ["iron_pickaxe", 1], ["health_potion", 5]]
# 骷髅法杖故意不列 (用户: 对战房太轮椅, 放完小兵摆烂); 召唤动作也在 player_action 里被对战房屏蔽
const _STAFFS := [
	["wood_staff", "木魔草杖"], ["iron_staff", "铁蓝晶杖"],
	["hell_staff", "地狱魔火法杖"],
]
const _GUNS := [
	["pistol", "手枪"], ["smg", "冲锋枪"], ["assault_rifle", "突击步枪"], ["shotgun", "霰弹枪"],
	["sniper", "狙击枪"], ["laser_gun", "激光枪"], ["flamethrower", "火焰喷射器"], ["freeze_ray", "冰冻枪"],
	["arcane_gun", "追踪魔弹枪"], ["poison_gun", "毒液枪"], ["lightning_gun", "闪电链枪"], ["star_gun", "星星炮"],
	["slime_gun", "史莱姆枪"], ["frost_gun", "冰雪枪"], ["leaf_gun", "绿叶枪"],
]

var _panel: Panel = null
var _content: VBoxContainer = null
var _switch_btn: Button = null
var _opened_once: bool = false
var _current_tag: String = "PVP"


# 某模式整套物品 [[id,count],...] (武器在前 + 共用; 不含盔甲)。纯数据, 供测试 + grant 复用。
static func mode_loadout(key: String, weapon_id: String = "") -> Array:
	var out: Array = []
	match key:
		"magic":
			out.append([weapon_id if weapon_id != "" else "iron_staff", 1])
			out.append(["mana_potion", 10])
		"gun":
			out.append([weapon_id if weapon_id != "" else "pistol", 1])
			out.append(["bullet", 200])
		_:
			out.append(["iron_sword", 1])
			out.append(["wood_bow", 1])
			out.append(["wood_arrow", 99])
	for c in _COMMON:
		out.append(c)
	return out


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS   # 暂停时面板仍能点 + 网络仍跑
	_build()
	_panel.visible = false   # 只藏 panel, 不藏整个 CanvasLayer (否则按钮也没了)


func _build() -> void:
	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", UIStyle.panel())
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(380, 440)
	_panel.size = Vector2(380, 440)
	_panel.position = Vector2(-190, -220)
	add_child(_panel)
	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = 18
	outer.offset_top = 18
	outer.offset_right = -18
	outer.offset_bottom = -18
	outer.add_theme_constant_override("separation", 10)
	_panel.add_child(outer)
	var title := Label.new()
	title.text = "选择对战模式"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.949, 0.761, 0.396))
	outer.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)
	# 常驻"切换模式"按钮: 击杀榜在右上 (左边沿距右 636px), 按钮放它左边一点。
	_switch_btn = Button.new()
	_switch_btn.text = "切换模式"
	UIStyle.style_button(_switch_btn)
	_switch_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_switch_btn.offset_right = -642.0
	_switch_btn.offset_left = -762.0
	_switch_btn.offset_top = 12.0
	_switch_btn.offset_bottom = 42.0
	_switch_btn.pressed.connect(_open)
	add_child(_switch_btn)
	_switch_btn.visible = false


func _add_choice(label: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyle.style_button(b)
	b.pressed.connect(cb)
	_content.add_child(b)


func _clear_content() -> void:
	for c in _content.get_children():
		c.queue_free()


func _show_modes() -> void:
	_clear_content()
	_add_choice("经典对战 (剑 + 弓)", _on_classic)
	_add_choice("魔法对战 (选法杖)", _show_weapons.bind("magic"))
	_add_choice("枪械对战 (选枪)", _show_weapons.bind("gun"))


# 列出该类全部武器 (可滚动)。用 .bind 绑值, 不能用闭包 — 闭包会让所有按钮都指向最后一个武器。
func _show_weapons(category: String) -> void:
	_clear_content()
	_add_choice("← 返回", _show_modes)
	var list: Array = _STAFFS if category == "magic" else _GUNS
	for pair in list:
		_add_choice(String(pair[1]), _pick.bind(category, String(pair[0])))


func _process(_delta: float) -> void:
	var in_pvp: bool = NetworkManager != null and NetworkManager.is_pvp()
	var picking: bool = _panel != null and _panel.visible
	if _switch_btn != null:
		_switch_btn.visible = in_pvp and not picking
	if not _opened_once and not picking and in_pvp and _local_inventory() != null:
		_open()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_M and (_panel == null or not _panel.visible) \
			and NetworkManager != null and NetworkManager.is_pvp():
		_open()


func _set_open(open: bool) -> void:
	if _panel != null:
		_panel.visible = open
	if _switch_btn != null and open:
		_switch_btn.visible = false
	get_tree().paused = open   # 选模式时暂停: 滚轮不缩放镜头 + 强制先选


func _open() -> void:
	_opened_once = true
	_show_modes()
	_set_open(true)


func _on_classic() -> void:
	_pick("classic", "")


func _pick(mode_key: String, weapon_id: String) -> void:
	_grant_loadout(mode_key, weapon_id)
	_set_open(false)
	var new_tag: String = String(_MODE_TAG.get(mode_key, "PVP"))
	if new_tag != _current_tag and NetworkManager != null and NetworkManager.is_public_room():
		_current_tag = new_tag
		_reroute(new_tag)


func _reroute(tag: String) -> void:
	if NetworkManager == null:
		return
	NetworkManager.disconnect_room()
	NetworkManager.enter_public(tag, MpRooms.PUBLIC_SV_SEED, MpRooms.PUBLIC_SV_SIZE, MpRooms.PUBLIC_SV_DIFF)


func _local_inventory() -> Node:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	var inv_node: Node = player.get_node_or_null("PlayerInventory")
	if inv_node == null or inv_node.inventory == null:
		return null
	return inv_node


# 清空背包 + 重发该模式整套装备 (武器在前 → 选中 slot 0) + 铁甲。
# inv_arg 仅供测试注入; 正常传 null 自动找本地玩家。
func _grant_loadout(mode_key: String, weapon_id: String, inv_arg: Node = null) -> bool:
	var inv_node: Node = inv_arg if inv_arg != null else _local_inventory()
	if inv_node == null or inv_node.inventory == null:
		return false
	for i in inv_node.inventory.slots.size():
		inv_node.inventory.slots[i] = null
	for pair in mode_loadout(mode_key, weapon_id):
		inv_node.pickup(String(pair[0]), int(pair[1]))
	inv_node.set_armor("helmet", {"item_id": "iron_helmet", "count": 1})
	inv_node.set_armor("chest", {"item_id": "iron_chest", "count": 1})
	inv_node.set_armor("pants", {"item_id": "iron_pants", "count": 1})
	if inv_node.has_method("set_hotbar_selection"):
		inv_node.set_hotbar_selection(0)
	if inv_node.has_signal("inventory_changed"):
		inv_node.inventory_changed.emit()
	return true
