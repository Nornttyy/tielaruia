# 合成面板: 显示背包 (36 槽只读) + 配方列表 (一键合成)。
# 旧的 _cells/_cursor_item 内部网格保留, 仅供集成测试调用 (place_in_cell / simulate_take_output)。
extends CanvasLayer

const RecipeMatcher = preload("res://scripts/crafting/recipe_matcher.gd")
const InventoryCursor = preload("res://scripts/items/inventory_cursor.gd")

const CELL_SIZE := 40
const SLOT_SIZE := 36
const RECIPE_SIZE := 48
# 蓝色圆角槽 (跟热键栏/菜单统一)
const BLUE_SLOT_BG := Color(0.07, 0.125, 0.227, 0.8)
const BLUE_SLOT_BORDER := Color(0.275, 0.47, 0.706, 1.0)
const CELL_NORMAL_COLOR := Color(0.07, 0.125, 0.227, 0.8)


# 给按钮 (配方卡/创造格) 套蓝色圆角 (normal/hover/pressed/disabled)
func _style_item_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _blue_slot_style())
	btn.add_theme_stylebox_override("hover", _blue_slot_style(Color(0.14, 0.25, 0.42, 0.92), Color(0.42, 0.62, 0.86, 1.0)))
	btn.add_theme_stylebox_override("pressed", _blue_slot_style(Color(0.05, 0.09, 0.16, 0.92), BLUE_SLOT_BORDER))
	btn.add_theme_stylebox_override("focus", _blue_slot_style(Color(0.14, 0.25, 0.42, 0.92), Color(0.42, 0.62, 0.86, 1.0)))
	btn.add_theme_stylebox_override("disabled", _blue_slot_style(Color(0.05, 0.07, 0.12, 0.7), Color(0.25, 0.32, 0.42, 1.0)))


# 蓝色圆角槽样式 (统一: 背包槽/盔甲槽/创造格都用)
func _blue_slot_style(bg: Color = BLUE_SLOT_BG, border: Color = BLUE_SLOT_BORDER) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 2
	s.corner_radius_top_left = 7
	s.corner_radius_top_right = 7
	s.corner_radius_bottom_left = 7
	s.corner_radius_bottom_right = 7
	return s

signal opened
signal closed

@onready var grid: GridContainer = $RecipeAnchor/RecipePanel/RecipeVBox/Row/InputGrid
@onready var output_slot: PanelContainer = $RecipeAnchor/RecipePanel/RecipeVBox/Row/OutputSlot
@onready var cursor: PanelContainer = $Cursor
@onready var inv_vbox: VBoxContainer = $InvAnchor/InvPanel/InvVBox
@onready var recipe_vbox: VBoxContainer = $RecipeAnchor/RecipePanel/RecipeVBox
@onready var row_old: HBoxContainer = $RecipeAnchor/RecipePanel/RecipeVBox/Row

var _player_inv: Node = null
var _mode: int = 0
var _cells: Array = []
var _cell_nodes: Array = []
var _output_preview: Variant = null
var _cursor_item: Variant = null

# 新 UI 节点 (由 _ready 程序化构建)
var _wb_label: Label
var _recipe_title: Label              # "合成" 标题 (创造模式隐藏)
var _recipe_scroll: ScrollContainer   # 配方列表滚动容器 (创造模式隐藏)
var _recipe_container: VBoxContainer
var _recipe_buttons: Array = []  # [{recipe_dict, button, cost_label}]
var _inv_grid: GridContainer
var _inv_slot_nodes: Array = []  # 36 个 PanelContainer
var _armor_slot_nodes: Array = []  # 3 个盔甲槽 PanelContainer (helmet/chest/pants 顺序)
var _creative_section: VBoxContainer = null  # 创造模式"物品大全"区 (只创造模式显示)

# 内部 _cells 初始化用
func _ready() -> void:
	add_to_group("crafting_panel")   # 让别处 (箱子面板互斥 / 暂停菜单) 用 group 找得到
	_cells.resize(3)
	_cell_nodes.resize(3)
	for r in 3:
		var row_d: Array = []; row_d.resize(3); row_d.fill(null)
		var row_n: Array = []; row_n.resize(3); row_n.fill(null)
		_cells[r] = row_d
		_cell_nodes[r] = row_n
	# 旧的 cells/arrow/output 隐藏 (仅留作测试用)
	row_old.visible = false
	_build_ui()
	visible = false


func _build_ui() -> void:
	# ===== 背包面板 (左上) =====
	var inv_title := Label.new()
	inv_title.text = "背包"
	inv_title.add_theme_font_size_override("font_size", 16)
	inv_title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	inv_vbox.add_child(inv_title)

	# 盔甲槽 (3 个): 头盔 / 胸甲 / 裤子. 右键背包物品 → 装备到匹配槽
	var armor_label := Label.new()
	armor_label.text = "盔甲 (右键背包装备)"
	armor_label.add_theme_font_size_override("font_size", 11)
	armor_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	inv_vbox.add_child(armor_label)
	var armor_row := HBoxContainer.new()
	armor_row.add_theme_constant_override("separation", 4)
	inv_vbox.add_child(armor_row)
	_armor_slot_nodes = [
		_make_armor_slot("helmet", "头"),
		_make_armor_slot("chest",  "胸"),
		_make_armor_slot("pants",  "腿"),
	]
	for n in _armor_slot_nodes:
		armor_row.add_child(n)

	_inv_grid = GridContainer.new()
	_inv_grid.columns = 9
	_inv_grid.add_theme_constant_override("h_separation", 3)
	_inv_grid.add_theme_constant_override("v_separation", 3)
	inv_vbox.add_child(_inv_grid)
	_build_inv_slots()

	# ===== 配方面板 (左下) =====
	_recipe_title = Label.new()
	_recipe_title.text = "合成"
	_recipe_title.add_theme_font_size_override("font_size", 16)
	_recipe_title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	recipe_vbox.add_child(_recipe_title)
	recipe_vbox.move_child(_recipe_title, 0)

	_wb_label = Label.new()
	_wb_label.add_theme_font_size_override("font_size", 12)
	recipe_vbox.add_child(_wb_label)
	recipe_vbox.move_child(_wb_label, 1)

	# 配方列表用 ScrollContainer 包起来 (现在配方数 > 6 时会溢出, 加滚动条解决)
	_recipe_scroll = ScrollContainer.new()
	_recipe_scroll.custom_minimum_size = Vector2(200, 320)  # 窄宽不撑面板, 高 320 自动垂直滚
	_recipe_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_recipe_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	recipe_vbox.add_child(_recipe_scroll)
	recipe_vbox.move_child(_recipe_scroll, 2)

	_recipe_container = VBoxContainer.new()
	_recipe_container.add_theme_constant_override("separation", 4)
	_recipe_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipe_scroll.add_child(_recipe_container)
	_build_recipe_buttons()

	# 创造模式"物品大全"区 (点任何物品免费拿一组), 只创造模式显示
	_build_creative_section()

	# Row (旧 input grid, 测试用) 放在最末尾且隐藏
	row_old.visible = false

	var hint := Label.new()
	hint.text = "按 E 关闭"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recipe_vbox.add_child(hint)


func _build_recipe_buttons() -> void:
	for r in RecipeDB.all_recipes():
		var entry := _make_recipe_row(r)
		_recipe_buttons.append(entry)
		_recipe_container.add_child(entry.button)


# 创造模式"物品大全": 一个可滚动网格, 每个物品一个图标按钮, 点一下免费拿一整组。
# 只创造模式显示 (生存模式整块隐藏)。
func _build_creative_section() -> void:
	_creative_section = VBoxContainer.new()
	_creative_section.add_theme_constant_override("separation", 3)
	recipe_vbox.add_child(_creative_section)

	var title := Label.new()
	title.text = "物品大全 (创造·点了免费拿)"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	_creative_section.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(200, 220)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_creative_section.add_child(scroll)

	var grid_c := GridContainer.new()
	grid_c.columns = 6
	grid_c.add_theme_constant_override("h_separation", 2)
	grid_c.add_theme_constant_override("v_separation", 2)
	scroll.add_child(grid_c)

	for item_id in ItemDB.all_item_ids():
		var tex: Texture2D = ArtCache.get_inventory_icon(item_id)
		if tex == null:
			continue   # 没图标的跳过 (不该有, 但保险)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(30, 30)
		_style_item_button(btn)
		btn.tooltip_text = _zh_name(item_id)
		var icon := TextureRect.new()
		icon.texture = tex
		icon.custom_minimum_size = Vector2(26, 26)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.add_child(icon)
		btn.pressed.connect(_on_creative_grab.bind(item_id))
		grid_c.add_child(btn)


# 点了"物品大全"里的物品: 免费拿一整组进背包
func _on_creative_grab(item_id: String) -> void:
	# 兜底: 面板若没绑定背包 (玩家加载时序 / 旧 bug 致 bind 没跑) 就现找一个, 否则点了没反应。
	if _player_inv == null:
		var p = get_tree().get_first_node_in_group("player")
		if p != null:
			_player_inv = p.get_node_or_null("PlayerInventory")
	if _player_inv == null or not _player_inv.has_method("pickup"):
		return
	var n: int = ItemDB.max_stack(item_id)
	if n <= 0:
		n = 1
	_player_inv.pickup(item_id, n)
	_refresh_inv()
	_refresh_recipes()   # 拿了料, 可合成的配方可能变了


func _refresh_creative_section() -> void:
	var creative: bool = GameSettings != null and GameSettings.creative_mode
	if _creative_section != null:
		_creative_section.visible = creative
	# 创造模式不需要合成 (方块直接从"物品大全"免费拿) → 隐藏整个合成配方区.
	# 既满足"创造不要合成", 又把物品大全顶上来 — 否则它被 320 高的配方列表挤到屏幕外 = 看不到/拿不到方块.
	if _recipe_title != null:
		_recipe_title.visible = not creative
	if _wb_label != null:
		_wb_label.visible = not creative
	if _recipe_scroll != null:
		_recipe_scroll.visible = not creative


func _make_recipe_row(recipe: Dictionary) -> Dictionary:
	# 2 行高布局 (窄, 不撑面板宽度):
	#   上行: [输出图标 24×24] [输出名字 expand]
	#   下行: [配料图标 14×14 ×N] [配料图标 ×M] ...  (左缩进 ~28px 与输出图标对齐)
	# 细节 (工作台需求) 仍在 hover tooltip.
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(180, 54)  # 高度 54 = 上 24 + 下 16 + padding
	_style_item_button(btn)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.tooltip_text = _recipe_tooltip(recipe)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 6.0
	vb.offset_right = -6.0
	vb.offset_top = 4.0
	vb.offset_bottom = -4.0
	btn.add_child(vb)

	# 上行: 输出图标 + 名
	var top_hb := HBoxContainer.new()
	top_hb.add_theme_constant_override("separation", 6)
	top_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(top_hb)

	var icon := TextureRect.new()
	icon.texture = ArtCache.get_inventory_icon(recipe.output_id)
	icon.custom_minimum_size = Vector2(24, 24)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_hb.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = _zh_name(recipe.output_id)
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_hb.add_child(name_lbl)

	# 下行: 配料图标 (左缩进与上行图标对齐)
	var bot_hb := HBoxContainer.new()
	bot_hb.add_theme_constant_override("separation", 4)
	bot_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(bot_hb)

	var indent := Control.new()
	indent.custom_minimum_size = Vector2(2, 0)
	indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot_hb.add_child(indent)

	var req: Dictionary = _required_inputs(recipe)
	for item_id in req:
		var ing_hb := HBoxContainer.new()
		ing_hb.add_theme_constant_override("separation", 1)
		ing_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var ing_icon := TextureRect.new()
		ing_icon.texture = ArtCache.get_inventory_icon(item_id)
		ing_icon.custom_minimum_size = Vector2(14, 14)
		ing_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		ing_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ing_hb.add_child(ing_icon)

		var cnt_lbl := Label.new()
		cnt_lbl.text = "×%d" % req[item_id]
		cnt_lbl.add_theme_font_size_override("font_size", 10)
		cnt_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		cnt_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cnt_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ing_hb.add_child(cnt_lbl)

		bot_hb.add_child(ing_hb)

	btn.pressed.connect(_on_recipe_pressed.bind(recipe.id))
	return {"recipe": recipe, "button": btn}


func _build_inv_slots() -> void:
	for i in 36:
		var slot := _make_inv_slot(i)
		_inv_grid.add_child(slot)
		_inv_slot_nodes.append(slot)


# 盔甲槽 panel: 显示当前装备, 鼠标 hover 显示 tooltip (item name + 防御),
# 左键卸下到背包第一个空槽.
func _make_armor_slot(slot_kind: String, label_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_armor_slot_input.bind(slot_kind))
	# 盔甲槽: 更深的蓝 (跟普通背包槽区分)
	var style := _blue_slot_style(Color(0.05, 0.08, 0.15, 0.85), Color(0.32, 0.52, 0.74, 1.0))
	panel.add_theme_stylebox_override("panel", style)
	var layout := Control.new()
	layout.name = "Layout"
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	panel.add_child(layout)
	# 空槽时显示中文字 (头/胸/腿)
	var hint := Label.new()
	hint.name = "Hint"
	hint.text = label_text
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.add_child(hint)
	# 装备 icon (有装备时显示)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.add_child(icon)
	panel.set_meta("slot_kind", slot_kind)
	return panel


func _on_armor_slot_input(event: InputEvent, slot_kind: String) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if _player_inv == null:
		return
	# 右键: 卸下到背包第一个空槽
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if _player_inv.has_method("unequip_armor"):
			_player_inv.unequip_armor(slot_kind)
			_refresh_all()   # 修: 卸下后刷新, 否则盔甲槽图标残留
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	# 左键 4 种情况:
	#   cursor 空 + 槽空: 啥也别干
	#   cursor 空 + 槽有: 拿到 cursor (槽清空)
	#   cursor 有 + 类型不匹配: 啥也别干 (不让乱装)
	#   cursor 有 + 类型匹配: swap (槽里的去 cursor, cursor 的装上)
	var cursor = _player_inv.cursor_slot
	var equipped = _player_inv.get_armor(slot_kind)
	if cursor == null:
		if equipped != null:
			_player_inv.cursor_slot = equipped
			_player_inv.set_armor(slot_kind, null)
			_refresh_all()   # 修: 拿到 cursor 后刷新, 否则盔甲槽图标残留
		return
	# cursor 有东西: 必须是匹配 slot 的盔甲
	if ItemDB.armor_slot(String(cursor.item_id)) != slot_kind:
		return
	# 匹配: swap. 槽里旧装备 → cursor, cursor 内装上
	_player_inv.set_armor(slot_kind, {"item_id": String(cursor.item_id), "count": 1})
	_player_inv.cursor_slot = equipped   # null 或旧装备, 都直接赋
	_refresh_all()   # 修: swap 后刷新盔甲槽


func _refresh_armor_slots() -> void:
	if _player_inv == null or _armor_slot_nodes.is_empty():
		return
	for panel in _armor_slot_nodes:
		var slot_kind: String = panel.get_meta("slot_kind", "")
		var equipped = _player_inv.get_armor(slot_kind)
		var icon: TextureRect = panel.get_node("Layout/Icon")
		var hint: Label = panel.get_node("Layout/Hint")
		if equipped == null:
			icon.texture = null
			hint.visible = true
			panel.tooltip_text = ""
		else:
			icon.texture = ArtCache.get_inventory_icon(equipped.item_id)
			hint.visible = false
			var name: String = _zh_name(equipped.item_id)
			var defense: int = ItemDB.defense(equipped.item_id)
			panel.tooltip_text = "%s\n防御 +%d (减 %.1f 伤)\n左键卸下" % [name, defense, float(defense) * 0.5]


func _make_inv_slot(idx: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP   # 接受点击
	panel.clip_contents = true
	panel.gui_input.connect(_on_inv_slot_input.bind(idx))
	var style := _blue_slot_style()
	panel.add_theme_stylebox_override("panel", style)
	var layout := Control.new()
	layout.name = "Layout"
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	panel.add_child(layout)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.add_child(icon)
	var count_lbl := Label.new()
	count_lbl.name = "Count"
	count_lbl.add_theme_font_size_override("font_size", 10)
	count_lbl.add_theme_color_override("font_color", Color.WHITE)
	count_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	count_lbl.add_theme_constant_override("outline_size", 2)
	count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count_lbl.position = Vector2(-18, -16)
	count_lbl.size = Vector2(16, 14)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	layout.add_child(count_lbl)
	# 0..8 是热键栏, 加小标号
	if idx < 9:
		var idx_lbl := Label.new()
		idx_lbl.text = str(idx + 1)
		idx_lbl.add_theme_font_size_override("font_size", 8)
		idx_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		idx_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		idx_lbl.add_theme_constant_override("outline_size", 2)
		idx_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		idx_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
		idx_lbl.position = Vector2(2, 0)
		layout.add_child(idx_lbl)
	return panel


func _recipe_tooltip(recipe: Dictionary) -> String:
	var req: Dictionary = _required_inputs(recipe)
	var lines: Array = ["产出: %s × %d" % [_zh_name(recipe.output_id), recipe.output_count]]
	for item_id in req:
		lines.append("  · %s × %d" % [_zh_name(item_id), req[item_id]])
	if max(recipe.grid_size.x, recipe.grid_size.y) > 2:
		lines.append("(需要工作台)")
	return "\n".join(lines)


# 物品/方块中文名 (面板用)
const _ZH_NAMES := {
	"log": "原木",
	"planks": "木板",
	"dirt": "泥土",
	"grass": "草",
	"stone": "石头",
	"sand": "沙子",
	"leaves": "树叶",
	"pine_leaves": "松针",
	"autumn_leaves": "秋叶",
	"workbench": "工作台",
	"door": "门",
	"slime_jelly": "史莱姆果冻",
	"apple": "苹果",
	"slime_torch": "史莱姆灯",
	"torch": "火把",
	"coal": "煤",
	"iron_ore": "铁矿",
	"wood_sword": "木阔剑",
	"wood_pickaxe": "木镐",
	"wood_axe": "木斧",
	"stone_sword": "石阔剑",
	"stone_pickaxe": "石镐",
	"stone_axe": "石斧",
	"iron_pickaxe": "铁镐",
	"iron_sword": "铁阔剑",
	"iron_axe": "铁斧",
	"copper_sword": "铜阔剑",
	"copper_pickaxe": "铜镐",
	"copper_axe": "铜斧",
	"silver_ore": "银矿",
	"silver_sword": "银阔剑",
	"silver_pickaxe": "银镐",
	"silver_axe": "银斧",
	"gold_sword": "金阔剑",
	"gold_pickaxe": "金镐",
	"gold_axe": "金斧",
	"diamond_sword": "钻石阔剑",
	"diamond_pickaxe": "钻石镐",
	"diamond_axe": "钻石斧",
	"wood_dagger": "木短剑",
	"stone_dagger": "石短剑",
	"copper_dagger": "铜短剑",
	"iron_dagger": "铁短剑",
	"silver_dagger": "银短剑",
	"gold_dagger": "金短剑",
	"diamond_dagger": "钻石短剑",
	"hell_dagger": "地狱短剑",
	"copper_ore": "铜矿",
	"tin_ore": "锡矿",
	"gold_ore": "金矿",
	"diamond": "钻石",
	"hell_crystal": "地狱晶体",
	"cactus": "仙人掌",
	"raw_meat": "生肉",
	"leather": "皮革",
	"wool": "羊毛",
	"chest": "箱子",
	"bed": "床",
	"grappling_hook": "钩爪",
	"fishing_rod": "鱼竿",
	"kitchen_knife": "菜刀",
	"wheat_seed": "小麦种子",
	"wheat": "小麦",
	"bone": "骨头",
	"spider_eye": "蜘蛛眼",
	"feather": "羽毛",
	"cloud_boots": "云靴",
	"lens": "镜片",
	"furnace": "熔炉",
	"cooking_pot": "铁锅",
	"cutting_board": "菜板",
	"rice": "米",
	"rice_seed": "稻种",
	"cooked_rice": "米饭",
	"fish_slice": "鱼片",
	"sushi": "寿司",
	"sashimi": "刺身",
	"onigiri": "饭团",
	"shrimp_sushi": "虾寿司",
	"uni_gunkan": "海胆军舰",
	"bread": "面包",
	"mushroom_soup": "蘑菇汤",
	"apple_pie": "苹果派",
	"meat_skewer": "烤肉串",
	"mushroom_stew": "蘑菇炖肉",
	"apple_jam": "苹果酱",
	"jelly_pudding": "果冻布丁",
	"salmon": "三文鱼",
	"tuna": "金枪鱼",
	"octopus": "章鱼",
	"sea_urchin": "海胆",
	"lobster": "龙虾",
	"eel": "鳗鱼",
	"sweet_shrimp": "甜虾",
	"scallop": "扇贝",
	"seaweed": "紫菜",
	"grilled_fish": "烤鱼",
	"iron_ingot": "铁锭",
	"copper_ingot": "铜锭",
	"tin_ingot": "锡锭",
	"silver_ingot": "银锭",
	"gold_ingot": "金锭",
	"cooked_meat": "熟肉",
	"snow": "雪块",
	"ice": "冰块",
	"jungle_grass": "丛林草",
	"mud": "泥",
	"swamp_grass": "沼泽草",
	"wood_platform": "木平台",
	"wood_wall": "木墙",
	"stone_wall": "石墙",
	"dirt_wall": "土墙",
	"grass_wall": "草墙",
	"wood_hammer": "木锤",
	"stone_hammer": "石锤",
	"copper_hammer": "铜锤",
	"iron_hammer": "铁锤",
	"silver_hammer": "银锤",
	"gold_hammer": "金锤",
	"diamond_hammer": "钻石锤",
	"hell_hammer": "地狱锤",
	"rope": "绳子",
	"jungle_dirt": "丛林泥",
	"snow_dirt": "冻土",
	"jungle_leaves": "丛林叶",
	"mushroom": "蘑菇",
	"hell_stone": "地狱石",
	"obsidian": "黑曜石",
	"hell_fruit": "火果",
	"wood_bow": "木弓",
	"wood_arrow": "木箭",
	"pistol": "手枪",
	"smg": "冲锋枪",
	"assault_rifle": "突击步枪",
	"shotgun": "霰弹枪",
	"sniper": "狙击枪",
	"laser_gun": "激光枪",
	"flamethrower": "火焰喷射器",
	"freeze_ray": "冰冻枪",
	"arcane_gun": "追踪魔弹枪",
	"poison_gun": "毒液枪",
	"lightning_gun": "闪电链枪",
	"star_gun": "星星炮",
	"slime_gun": "史莱姆枪",
	"bullet": "子弹",
	"hell_crystal_ingot": "魔晶锭",
	"hell_alloy_ore": "地狱合金矿",
	"hell_alloy_ingot": "地狱合金锭",
	# 盔甲
	"copper_helmet": "铜头盔", "copper_chest": "铜胸甲", "copper_pants": "铜裤子",
	"iron_helmet": "铁头盔", "iron_chest": "铁胸甲", "iron_pants": "铁裤子",
	"silver_helmet": "银头盔", "silver_chest": "银胸甲", "silver_pants": "银裤子",
	"gold_helmet": "金头盔", "gold_chest": "金胸甲", "gold_pants": "金裤子",
	"diamond_helmet": "钻石头盔", "diamond_chest": "钻石胸甲", "diamond_pants": "钻石裤子",
	# 地狱武器 (tier 8)
	"hell_sword": "地狱阔剑", "hell_pickaxe": "地狱镐", "hell_axe": "地狱斧",
	"hell_staff": "地狱魔火法杖",
	"wood_staff": "木魔草杖", "iron_staff": "铁蓝晶杖",
	"mana_potion": "魔力药水",
	"health_potion": "生命药水",
	"sandstone": "砂岩",
	"cloud": "云块",
	"slime_crown": "史莱姆王冠",
	"slime_ball": "史莱姆球",
	"bone_sword": "骨剑",
	"skull_summon": "骷髅头骨",
	"skeleton_helmet": "骷髅头盔",
	"skeleton_chest": "骷髅胸甲",
	"skeleton_pants": "骷髅腿甲",
	"skull_staff": "骷髅法杖",
}


func _zh_name(item_id: String) -> String:
	return _ZH_NAMES.get(item_id, item_id)


# ---- 公共 API ----

func bind_inventory(player_inv: Node) -> void:
	_player_inv = player_inv
	if player_inv != null and player_inv.has_signal("inventory_changed"):
		player_inv.inventory_changed.connect(_refresh_all)
	# 盔甲槽变化时也重渲背包 (装备/卸下都要刷)
	if player_inv != null and player_inv.has_signal("armor_changed"):
		player_inv.armor_changed.connect(_refresh_all)


func open(grid_n: int) -> void:
	# 互斥: 开合成前先关箱子面板 (防两个面板同时开 → 点击穿透 + 双光标)
	var chest_p: CanvasLayer = get_tree().get_first_node_in_group("chest_panel")
	if chest_p != null and chest_p.has_method("is_open") and chest_p.is_open() and chest_p.has_method("close"):
		chest_p.close()
	_mode = grid_n
	# 重建旧网格 (测试用)
	for child in grid.get_children():
		child.queue_free()
	_cell_nodes = []
	_cell_nodes.resize(3)
	for r in 3:
		var row_n: Array = []; row_n.resize(3); row_n.fill(null)
		_cell_nodes[r] = row_n
	grid.columns = grid_n
	for r in grid_n:
		for c in grid_n:
			var cell := _make_cell(r, c)
			grid.add_child(cell)
			_cell_nodes[r][c] = cell
	for r in 3:
		for c in 3:
			_cells[r][c] = null
	_output_preview = null
	if not output_slot.gui_input.is_connected(_on_output_clicked):
		output_slot.gui_input.connect(_on_output_clicked)
	visible = true
	_refresh_all()
	opened.emit()


func close() -> void:
	if _player_inv != null:
		for r in 3:
			for c in 3:
				var v = _cells[r][c]
				if v != null:
					_player_inv.pickup(v.item_id, v.count)
					_cells[r][c] = null
		if _cursor_item != null:
			_player_inv.pickup(_cursor_item.item_id, _cursor_item.count)
		# 鼠标手持 (拖动用) slot → 回 inv
		if _player_inv.inventory != null:
			InventoryCursor.return_cursor_to_inv(_player_inv, _player_inv.inventory.slots)
			if _player_inv.has_signal("inventory_changed"):
				_player_inv.inventory_changed.emit()
	_cursor_item = null
	_output_preview = null
	cursor.visible = false
	visible = false
	_mode = 0
	closed.emit()


# 拖动状态: 严格"按住拖" — press 只拿起 / release 才放下, 没有 click-click
var _drag_active: bool = false
var _drag_picked_up_this_press: bool = false
var _drag_press_idx: int = -1


# 36 个背包格子: press 只拿起 (cursor 空时), 不放下. 放下走 _input release.
func _on_inv_slot_input(event: InputEvent, idx: int) -> void:
	if not (event is InputEventMouseButton):
		return
	if _player_inv == null or _player_inv.inventory == null:
		return
	# 右键: 如果该 slot 是盔甲 → 装备到对应盔甲槽 (优先于 LMB 拖拽)
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var s = _player_inv.inventory.slots[idx]
		if s != null and ItemDB.armor_slot(s.item_id) != "":
			_player_inv.equip_armor_from_slot(idx)
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not event.pressed:
		return
	_drag_press_idx = idx
	if _player_inv.cursor_slot == null:
		_apply_inv_click(idx)
		if _player_inv.cursor_slot != null:
			_drag_active = true
			_drag_picked_up_this_press = true
		else:
			_drag_active = false
			_drag_picked_up_this_press = false
	else:
		_drag_active = true
		_drag_picked_up_this_press = false


func _apply_inv_click(idx: int) -> void:
	InventoryCursor.click_slot(_player_inv, _player_inv.inventory.slots, idx)
	if _player_inv.has_signal("inventory_changed"):
		_player_inv.inventory_changed.emit()


# 全局监听鼠标松开 → 找鼠标下的 slot → 放下/合并/交换 (没拖动则取消)
func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if not _drag_active:
		return
	var found_idx := _find_inv_slot_under_mouse()
	if found_idx < 0:
		# 松手在 slot 外: 本次拿起的就放回, 否则 cursor 保留
		if _drag_picked_up_this_press:
			_apply_inv_click(_drag_press_idx)
		_drag_active = false
		return
	if found_idx == _drag_press_idx:
		# 同 slot 松手 (没拖动): 取消本次拿起
		if _drag_picked_up_this_press:
			_apply_inv_click(_drag_press_idx)
		_drag_active = false
		return
	# 拖到不同 slot → 放下/合并/交换
	_apply_inv_click(found_idx)
	# 拖动交换 (drag-swap): 本次按下才拿起的 + 交换后 cursor 还有东西
	# = "拖 A 到 B 上, B 应该回到 A 原位置, 不是留在鼠标"
	if _drag_picked_up_this_press and _player_inv.cursor_slot != null:
		var src_idx: int = _drag_press_idx
		if src_idx >= 0 and src_idx < _player_inv.inventory.slots.size():
			if _player_inv.inventory.slots[src_idx] == null:
				_player_inv.inventory.slots[src_idx] = _player_inv.cursor_slot
				_player_inv.cursor_slot = null
				if _player_inv.has_signal("inventory_changed"):
					_player_inv.inventory_changed.emit()
	_drag_active = false


func _find_inv_slot_under_mouse() -> int:
	var mp: Vector2 = get_viewport().get_mouse_position()
	for i in _inv_slot_nodes.size():
		var slot: Control = _inv_slot_nodes[i]
		if slot.get_global_rect().has_point(mp):
			return i
	return -1


func is_open() -> bool:
	return visible and _mode > 0


# ---- 配方点击 ----

func _on_recipe_pressed(recipe_id: String) -> void:
	var recipe = RecipeDB.get_recipe(recipe_id)
	if recipe == null:
		return
	# 检查模式: 3x3 配方需要工作台 (_mode == 3)
	if max(recipe.grid_size.x, recipe.grid_size.y) > _mode:
		return
	# 要求工作台的配方 (如云靴): 必须在工作台模式, 防徒手合
	if recipe.get("requires", "") == "workbench" and _mode < 3:
		return
	if _player_inv == null:
		return
	var inv = _player_inv.inventory
	var req = _required_inputs(recipe)
	# 检查素材
	for item_id in req:
		if _count_in_inv(inv, item_id) < req[item_id]:
			return
	# 快照 + 试做 + 装不下回滚 (避免材料消耗后产物无处放)
	var snapshot: Array = _snapshot_slots(inv)
	for item_id in req:
		_remove_from_inv(inv, item_id, req[item_id])
	var leftover: int = inv.add(recipe.output_id, recipe.output_count)
	if leftover > 0:
		_restore_slots(inv, snapshot)
		return
	_player_inv.inventory_changed.emit()


func _snapshot_slots(inv) -> Array:
	var snap: Array = []
	for s in inv.slots:
		snap.append(null if s == null else {"item_id": s.item_id, "count": s.count})
	return snap


func _restore_slots(inv, snapshot: Array) -> void:
	for i in inv.slots.size():
		inv.slots[i] = snapshot[i]


func _required_inputs(recipe: Dictionary) -> Dictionary:
	var req := {}
	for row in recipe.pattern:
		for cell in row:
			if cell != "":
				req[cell] = req.get(cell, 0) + 1
	return req


func _count_in_inv(inv, item_id: String) -> int:
	var n: int = 0
	for s in inv.slots:
		if s != null and s.item_id == item_id:
			n += s.count
	return n


func _remove_from_inv(inv, item_id: String, count: int) -> void:
	var remaining: int = count
	for i in inv.slots.size():
		if remaining == 0:
			break
		var s = inv.slots[i]
		if s == null or s.item_id != item_id:
			continue
		var take: int = min(s.count, remaining)
		s.count -= take
		remaining -= take
		if s.count <= 0:
			inv.slots[i] = null


# ---- 刷新 ----

func _refresh_all() -> void:
	_refresh_wb_label()
	_refresh_recipes()
	_refresh_creative_section()
	_refresh_inv()
	_refresh_armor_slots()
	_refresh_cells()
	_refresh_output()


func _refresh_wb_label() -> void:
	if _wb_label == null:
		return
	if _mode == 3:
		_wb_label.text = "[ 工作台 3×3 ]"
		_wb_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	else:
		_wb_label.text = "[ 徒手 2×2 ]"
		_wb_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.5))


func _refresh_recipes() -> void:
	if _player_inv == null:
		return
	var inv = _player_inv.inventory
	if inv == null:
		# 玩家 inv 还没初始化 (race), 全部 disable 防"看起来都能合成"假象
		for entry in _recipe_buttons:
			(entry.button as Button).disabled = true
			(entry.button as Button).modulate = Color(0.5, 0.5, 0.5, 0.7)
		return
	# 查附近是否有 furnace (跟 workbench 同模式)
	var has_furnace: bool = _has_furnace_nearby()
	var has_cooking_pot: bool = _has_cooking_pot_nearby()
	var has_cutting_board: bool = _has_cutting_board_nearby()
	for entry in _recipe_buttons:
		var recipe: Dictionary = entry.recipe
		var btn: Button = entry.button
		# 模式过滤: 2x2 模式只显示 2x2 配方; 工作台 (3x3 模式) 显示 ≤ 3x3 的全部配方
		var recipe_size: int = max(recipe.grid_size.x, recipe.grid_size.y)
		btn.visible = (recipe_size <= _mode)
		if not btn.visible:
			continue
		# 冶炼配方过滤: 要求 "furnace" 的, 玩家身边必须有 furnace
		var requires: String = recipe.get("requires", "")
		if requires == "furnace" and not has_furnace:
			btn.visible = false
			continue
		# 料理配方过滤: 要求 "pot" 的, 玩家身边必须有铁锅
		if requires == "pot" and not has_cooking_pot:
			btn.visible = false
			continue
		# 寿司配方过滤: 要求 "board" 的, 玩家身边必须有菜板
		if requires == "board" and not has_cutting_board:
			btn.visible = false
			continue
		# 工作台配方过滤: 要求 "workbench" 的必须在工作台模式 (_mode==3); 否则徒手能合云靴等
		if requires == "workbench" and _mode < 3:
			btn.visible = false
			continue
		# 素材是否够 → 灰显
		var req: Dictionary = _required_inputs(recipe)
		var has_materials: bool = true
		for item_id in req:
			if _count_in_inv(inv, item_id) < req[item_id]:
				has_materials = false
				break
		btn.disabled = not has_materials
		btn.modulate = Color(1, 1, 1, 1) if has_materials else Color(0.5, 0.5, 0.5, 0.7)


# 玩家附近 (≤ 2 格) 有 furnace tile 吗 (跟 workbench 同检测)
func _has_furnace_nearby() -> bool:
	if _player_inv == null:
		return false
	var player: Node = _player_inv.get_parent()
	if player == null:
		return false
	var pa: Node = player.get_node_or_null("PlayerAction")
	if pa == null or not pa.has_method("player_tile"):
		return false
	var pt: Vector2i = pa.player_tile()
	var terrain: TileMapLayer = get_tree().get_first_node_in_group("terrain_layer") as TileMapLayer
	if terrain == null:
		return false
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var tid: int = terrain.get_cell_source_id(pt + Vector2i(dx, dy))
			if tid == Tiles.FURNACE:
				return true
	return false


# 查附近 ±2 格有没有铁锅 (做饭工作站, 跟 furnace 同模式)
func _has_cooking_pot_nearby() -> bool:
	if _player_inv == null:
		return false
	var player: Node = _player_inv.get_parent()
	if player == null:
		return false
	var pa: Node = player.get_node_or_null("PlayerAction")
	if pa == null or not pa.has_method("player_tile"):
		return false
	var pt: Vector2i = pa.player_tile()
	var terrain: TileMapLayer = get_tree().get_first_node_in_group("terrain_layer") as TileMapLayer
	if terrain == null:
		return false
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var tid: int = terrain.get_cell_source_id(pt + Vector2i(dx, dy))
			if tid == Tiles.COOKING_POT:
				return true
	return false


# 查附近 ±2 格有没有菜板 (做寿司工作站, 跟 furnace/pot 同模式)
func _has_cutting_board_nearby() -> bool:
	if _player_inv == null:
		return false
	var player: Node = _player_inv.get_parent()
	if player == null:
		return false
	var pa: Node = player.get_node_or_null("PlayerAction")
	if pa == null or not pa.has_method("player_tile"):
		return false
	var pt: Vector2i = pa.player_tile()
	var terrain: TileMapLayer = get_tree().get_first_node_in_group("terrain_layer") as TileMapLayer
	if terrain == null:
		return false
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var tid: int = terrain.get_cell_source_id(pt + Vector2i(dx, dy))
			if tid == Tiles.CUTTING_BOARD:
				return true
	return false


func _refresh_inv() -> void:
	if _player_inv == null:
		return
	var inv = _player_inv.inventory
	for i in 36:
		var s = inv.slots[i]
		var panel: PanelContainer = _inv_slot_nodes[i]
		var icon: TextureRect = panel.get_node("Layout/Icon")
		var count_lbl: Label = panel.get_node("Layout/Count")
		if s == null:
			icon.texture = null
			count_lbl.text = ""
			panel.tooltip_text = ""
		else:
			icon.texture = ArtCache.get_inventory_icon(s.item_id)
			count_lbl.text = "" if s.count <= 1 else str(s.count)
			# tooltip: 盔甲显示防御, 其他显示名字
			var item_name: String = _zh_name(s.item_id)
			var aslot: String = ItemDB.armor_slot(s.item_id)
			if aslot != "":
				var defense: int = ItemDB.defense(s.item_id)
				panel.tooltip_text = "%s\n防御 +%d (减 %.1f 伤)\n右键装备" % [item_name, defense, float(defense) * 0.5]
			else:
				panel.tooltip_text = item_name


# ============= 旧测试 API (保留) =============

func _make_cell(r: int, c: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	var style := _blue_slot_style()
	panel.add_theme_stylebox_override("panel", style)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	panel.add_child(icon)
	var label := Label.new()
	label.name = "Count"
	label.add_theme_font_size_override("font_size", 10)
	label.size_flags_horizontal = Control.SIZE_SHRINK_END | Control.SIZE_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_END | Control.SIZE_FILL
	panel.add_child(label)
	panel.gui_input.connect(_on_cell_clicked.bind(r, c))
	return panel


func _process(_delta: float) -> void:
	if cursor.visible:
		cursor.position = cursor.get_viewport().get_mouse_position() - Vector2(CELL_SIZE / 2, CELL_SIZE / 2)
	_update_drag_cursor()


# 鼠标手持 slot 的 floating icon (reuse cursor 节点显示 inv 物品图标)
func _update_drag_cursor() -> void:
	if _player_inv == null:
		return
	var cs = _player_inv.cursor_slot
	if cs == null:
		# 放下后清掉 drag icon (bug fix: 不然图标残留在屏幕上)
		var icon_clear: TextureRect = cursor.get_node_or_null("DragIcon")
		if icon_clear != null:
			icon_clear.texture = null
		var lbl_clear: Label = cursor.get_node_or_null("DragCount")
		if lbl_clear != null:
			lbl_clear.text = ""
		# 只有 crafting 的 _cursor_item 也不在用时才隐 cursor 节点
		if _cursor_item == null:
			cursor.visible = false
		return
	# 确保子节点存在
	var icon: TextureRect = cursor.get_node_or_null("DragIcon")
	if icon == null:
		icon = TextureRect.new()
		icon.name = "DragIcon"
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		cursor.add_child(icon)
	var lbl: Label = cursor.get_node_or_null("DragCount")
	if lbl == null:
		lbl = Label.new()
		lbl.name = "DragCount"
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 2)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		lbl.position = Vector2(-18, -16)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cursor.add_child(lbl)
	cursor.visible = true
	cursor.position = cursor.get_viewport().get_mouse_position() - Vector2(CELL_SIZE / 2, CELL_SIZE / 2)
	icon.texture = ArtCache.get_inventory_icon(String(cs.item_id))
	lbl.text = str(int(cs.count)) if int(cs.count) > 1 else ""


func _on_cell_clicked(event: InputEvent, r: int, c: int) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		_left_click_cell(r, c)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_right_click_cell(r, c)
	_recompute_output()
	_refresh_cells()
	_refresh_output()


func _left_click_cell(r: int, c: int) -> void:
	var s = _cells[r][c]
	if _cursor_item == null:
		if s != null:
			_cursor_item = s
			_cells[r][c] = null
	else:
		if s == null:
			_cells[r][c] = _cursor_item
			_cursor_item = null
		elif s.item_id == _cursor_item.item_id:
			var ms: int = ItemDB.max_stack(s.item_id)
			var room: int = ms - s.count
			if room > 0:
				var n: int = min(room, _cursor_item.count)
				s.count += n
				_cursor_item.count -= n
				if _cursor_item.count <= 0:
					_cursor_item = null
		else:
			var tmp = _cells[r][c]
			_cells[r][c] = _cursor_item
			_cursor_item = tmp
	_update_cursor_visual()


func _right_click_cell(r: int, c: int) -> void:
	var s = _cells[r][c]
	if _cursor_item == null:
		if s != null and s.count > 1:
			var half: int = s.count / 2
			s.count -= half
			_cursor_item = {"item_id": s.item_id, "count": half}
	else:
		if s == null:
			_cells[r][c] = {"item_id": _cursor_item.item_id, "count": 1}
			_cursor_item.count -= 1
		elif s.item_id == _cursor_item.item_id and s.count < ItemDB.max_stack(s.item_id):
			s.count += 1
			_cursor_item.count -= 1
		if _cursor_item != null and _cursor_item.count <= 0:
			_cursor_item = null
	_update_cursor_visual()


func _on_output_clicked(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _output_preview == null:
		return
	var output_id: String = _output_preview.output_id
	var output_count: int = _output_preview.output_count
	if _cursor_item != null and _cursor_item.item_id != output_id:
		return
	var max_stack: int = ItemDB.max_stack(output_id)
	if _cursor_item != null and _cursor_item.count + output_count > max_stack:
		return
	for cell in _output_preview.input_cells:
		var s = _cells[cell.y][cell.x]
		if s != null:
			s.count -= 1
			if s.count <= 0:
				_cells[cell.y][cell.x] = null
	if _cursor_item == null:
		_cursor_item = {"item_id": output_id, "count": output_count}
	else:
		_cursor_item.count += output_count
	_update_cursor_visual()
	_recompute_output()
	_refresh_cells()
	_refresh_output()


func _recompute_output() -> void:
	var n: int = _mode
	var sub: Array = []
	for r in n:
		var row: Array = []
		for c in n:
			var s = _cells[r][c]
			row.append("" if s == null else String(s.item_id))
		sub.append(row)
	# 工作站: 身边有哪些就允许哪些 station 配方 (在菜板边切鱼片, 在锅边烤鱼; 没站只出徒手配方)
	var stations: Array = []
	if _has_furnace_nearby():
		stations.append("furnace")
	if _has_cooking_pot_nearby():
		stations.append("pot")
	if _has_cutting_board_nearby():
		stations.append("board")
	_output_preview = RecipeMatcher.find_match(sub, stations)


func _refresh_cells() -> void:
	for r in _mode:
		for c in _mode:
			var panel: PanelContainer = _cell_nodes[r][c]
			if panel == null:
				continue
			var s = _cells[r][c]
			var icon: TextureRect = panel.get_node("Icon")
			var label: Label = panel.get_node("Count")
			if s == null:
				icon.texture = null
				label.text = ""
			else:
				icon.texture = ArtCache.get_inventory_icon(s.item_id)
				label.text = "" if s.count <= 1 else str(s.count)


func _refresh_output() -> void:
	var icon_node: Node = output_slot.get_node_or_null("Icon")
	if icon_node == null:
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		output_slot.add_child(icon)
		icon_node = icon
		var lbl := Label.new()
		lbl.name = "Count"
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.size_flags_horizontal = Control.SIZE_SHRINK_END | Control.SIZE_FILL
		lbl.size_flags_vertical = Control.SIZE_SHRINK_END | Control.SIZE_FILL
		output_slot.add_child(lbl)
	var icon: TextureRect = output_slot.get_node("Icon")
	var label: Label = output_slot.get_node("Count")
	if _output_preview == null:
		icon.texture = null
		label.text = ""
	else:
		icon.texture = ArtCache.get_inventory_icon(_output_preview.output_id)
		label.text = "" if _output_preview.output_count <= 1 else str(_output_preview.output_count)


func _update_cursor_visual() -> void:
	if _cursor_item == null:
		cursor.visible = false
		return
	cursor.visible = true
	var icon: TextureRect = cursor.get_node_or_null("Icon")
	if icon == null:
		icon = TextureRect.new()
		icon.name = "Icon"
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		cursor.add_child(icon)
		var lbl := Label.new()
		lbl.name = "Count"
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.size_flags_horizontal = Control.SIZE_SHRINK_END | Control.SIZE_FILL
		lbl.size_flags_vertical = Control.SIZE_SHRINK_END | Control.SIZE_FILL
		cursor.add_child(lbl)
	var label: Label = cursor.get_node("Count")
	icon.texture = ArtCache.get_inventory_icon(_cursor_item.item_id)
	label.text = "" if _cursor_item.count <= 1 else str(_cursor_item.count)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("ui_cancel_crafting"):
		close()
		get_viewport().set_input_as_handled()


# ---- 测试 API ----
func place_in_cell(r: int, c: int, item_id: String, count: int) -> void:
	_cells[r][c] = {"item_id": item_id, "count": count}
	_recompute_output()
	_refresh_cells()
	_refresh_output()


func get_cursor_item() -> Variant:
	return _cursor_item


func get_output_preview() -> Variant:
	return _output_preview


func simulate_take_output() -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	_on_output_clicked(e)
