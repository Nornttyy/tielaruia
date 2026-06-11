# 对战房模式选择面板: 进对战房后自动弹出, 玩家自己选 经典/魔法/枪械 三种对战。
# 选了 → 清空背包重发对应整套装备 (各人各选各的, 本地决定, 不强制统一)。之后按 M 可重选。
# 注: 组队/混战 + 胜负判定是更大的后续, 这版只做"对战装备类型"选择。
# 非对战房 (生存/起床战争) 永不弹出 → 可一直挂在游戏里无副作用。
extends CanvasLayer

const UIStyle = preload("res://scripts/ui/ui_style.gd")

# 共用装备 (三种模式都给): 石头(搭掩体) + 镐(挖方块) + 血药。盔甲单独 set_armor。
const _COMMON := [["stone", 64], ["iron_pickaxe", 1], ["health_potion", 5]]
# 每种模式的主武器 (放背包最前面, 选中 slot 0)。
const _MODES := {
	"classic": {"name": "经典对战", "weapons": [["iron_sword", 1], ["wood_bow", 1], ["wood_arrow", 99]]},
	"magic":   {"name": "魔法对战", "weapons": [["iron_staff", 1], ["mana_potion", 10]]},
	"gun":     {"name": "枪械对战", "weapons": [["smg", 1], ["bullet", 200]]},
}
const _ORDER := ["classic", "magic", "gun"]

var _panel: Panel = null
var _chosen: bool = false   # 已选过一次 (不再自动弹; 按 M 才重开)


# 某模式的整套物品清单 [[id,count],...] (武器在前 + 共用; 不含盔甲)。纯数据, 供测试 + grant 复用。
static func mode_loadout(key: String) -> Array:
	var out: Array = []
	if _MODES.has(key):
		for w in _MODES[key]["weapons"]:
			out.append(w)
	for c in _COMMON:
		out.append(c)
	return out


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func _build() -> void:
	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", UIStyle.panel())
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(360, 300)
	_panel.size = Vector2(360, 300)
	_panel.position = Vector2(-180, -150)
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 20
	vb.offset_top = 20
	vb.offset_right = -20
	vb.offset_bottom = -20
	vb.add_theme_constant_override("separation", 14)
	_panel.add_child(vb)
	var title := Label.new()
	title.text = "选择对战模式"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.949, 0.761, 0.396))
	vb.add_child(title)
	var hint := Label.new()
	hint.text = "每人各选各的 · 之后按 M 可重选"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.8, 0.78, 0.7))
	vb.add_child(hint)
	for key in _ORDER:
		var b := Button.new()
		b.text = _MODES[key]["name"]
		b.custom_minimum_size = Vector2(0, 50)
		UIStyle.style_button(b)
		b.pressed.connect(_on_mode_pressed.bind(key))
		vb.add_child(b)


# 每帧轻量检查: 在对战房 + 玩家就绪 + 还没选过 → 自动弹出 (只弹一次)。
func _process(_delta: float) -> void:
	if _chosen or visible:
		return
	if NetworkManager == null or not NetworkManager.is_pvp():
		return
	if _local_inventory() != null:
		_open()


func _input(event: InputEvent) -> void:
	# 对战房里按 M 重新选模式 (M 没绑别的 action)
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_M \
			and NetworkManager != null and NetworkManager.is_pvp() \
			and not visible:
		_open()


func _open() -> void:
	visible = true


func _on_mode_pressed(key: String) -> void:
	_grant_loadout(key)
	_chosen = true
	visible = false


# 找本地玩家的 PlayerInventory (没就绪返 null)。
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
func _grant_loadout(key: String, inv_arg: Node = null) -> bool:
	var inv_node: Node = inv_arg if inv_arg != null else _local_inventory()
	if inv_node == null or inv_node.inventory == null:
		return false
	for i in inv_node.inventory.slots.size():
		inv_node.inventory.slots[i] = null   # 清空, 重发干净 (换模式不残留上一套)
	for pair in mode_loadout(key):
		inv_node.pickup(String(pair[0]), int(pair[1]))
	inv_node.set_armor("helmet", {"item_id": "iron_helmet", "count": 1})
	inv_node.set_armor("chest", {"item_id": "iron_chest", "count": 1})
	inv_node.set_armor("pants", {"item_id": "iron_pants", "count": 1})
	if inv_node.has_method("set_hotbar_selection"):
		inv_node.set_hotbar_selection(0)   # 选中 slot 0 = 主武器
	if inv_node.has_signal("inventory_changed"):
		inv_node.inventory_changed.emit()
	return true
