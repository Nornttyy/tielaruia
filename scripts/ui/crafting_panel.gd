# 合成面板: 显示背包 (36 槽只读) + 配方列表 (一键合成)。
# 旧的 _cells/_cursor_item 内部网格保留, 仅供集成测试调用 (place_in_cell / simulate_take_output)。
extends CanvasLayer

const RecipeMatcher = preload("res://scripts/crafting/recipe_matcher.gd")
const InventoryCursor = preload("res://scripts/items/inventory_cursor.gd")

const CELL_SIZE := 40
const SLOT_SIZE := 36
const RECIPE_SIZE := 48
const CELL_NORMAL_COLOR := Color(0, 0, 0, 0.4)

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
var _recipe_container: VBoxContainer
var _recipe_buttons: Array = []  # [{recipe_dict, button, cost_label}]
var _inv_grid: GridContainer
var _inv_slot_nodes: Array = []  # 36 个 PanelContainer

# 内部 _cells 初始化用
func _ready() -> void:
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

	_inv_grid = GridContainer.new()
	_inv_grid.columns = 9
	_inv_grid.add_theme_constant_override("h_separation", 3)
	_inv_grid.add_theme_constant_override("v_separation", 3)
	inv_vbox.add_child(_inv_grid)
	_build_inv_slots()

	# ===== 配方面板 (左下) =====
	var rec_title := Label.new()
	rec_title.text = "合成"
	rec_title.add_theme_font_size_override("font_size", 16)
	rec_title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	recipe_vbox.add_child(rec_title)
	recipe_vbox.move_child(rec_title, 0)

	_wb_label = Label.new()
	_wb_label.add_theme_font_size_override("font_size", 12)
	recipe_vbox.add_child(_wb_label)
	recipe_vbox.move_child(_wb_label, 1)

	# 配方列表用 ScrollContainer 包起来 (现在配方数 > 6 时会溢出, 加滚动条解决)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(200, 320)  # 窄宽不撑面板, 高 320 自动垂直滚
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	recipe_vbox.add_child(scroll)
	recipe_vbox.move_child(scroll, 2)

	_recipe_container = VBoxContainer.new()
	_recipe_container.add_theme_constant_override("separation", 4)
	_recipe_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_recipe_container)
	_build_recipe_buttons()

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


func _make_recipe_row(recipe: Dictionary) -> Dictionary:
	# 2 行高布局 (窄, 不撑面板宽度):
	#   上行: [输出图标 24×24] [输出名字 expand]
	#   下行: [配料图标 14×14 ×N] [配料图标 ×M] ...  (左缩进 ~28px 与输出图标对齐)
	# 细节 (工作台需求) 仍在 hover tooltip.
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(180, 54)  # 高度 54 = 上 24 + 下 16 + padding
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


func _make_inv_slot(idx: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP   # 接受点击
	panel.clip_contents = true
	panel.gui_input.connect(_on_inv_slot_input.bind(idx))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.4)
	style.border_color = Color(0.4, 0.4, 0.4, 1)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
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
	"wood_sword": "木剑",
	"wood_pickaxe": "木镐",
	"wood_axe": "木斧",
	"stone_sword": "石剑",
	"stone_pickaxe": "石镐",
	"stone_axe": "石斧",
	"iron_pickaxe": "铁镐",
	"iron_sword": "铁剑",
	"iron_axe": "铁斧",
	"gold_sword": "金剑",
	"gold_pickaxe": "金镐",
	"gold_axe": "金斧",
	"diamond_sword": "钻石剑",
	"diamond_pickaxe": "钻石镐",
	"diamond_axe": "钻石斧",
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
	"grappling_hook": "钩爪",
	"bone": "骨头",
	"snow": "雪块",
	"ice": "冰块",
	"jungle_grass": "丛林草",
	"mud": "泥",
	"swamp_grass": "沼泽草",
}


func _zh_name(item_id: String) -> String:
	return _ZH_NAMES.get(item_id, item_id)


# ---- 公共 API ----

func bind_inventory(player_inv: Node) -> void:
	_player_inv = player_inv
	if player_inv != null and player_inv.has_signal("inventory_changed"):
		player_inv.inventory_changed.connect(_refresh_all)


func open(grid_n: int) -> void:
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


# 36 个背包格子左键: 拿起/放下/合并/交换
func _on_inv_slot_input(event: InputEvent, idx: int) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _player_inv == null or _player_inv.inventory == null:
		return
	InventoryCursor.click_slot(_player_inv, _player_inv.inventory.slots, idx)
	if _player_inv.has_signal("inventory_changed"):
		_player_inv.inventory_changed.emit()


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
	_refresh_inv()
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
	for entry in _recipe_buttons:
		var recipe: Dictionary = entry.recipe
		var btn: Button = entry.button
		# 模式过滤: 2x2 模式只显示 2x2 配方; 工作台 (3x3 模式) 显示 ≤ 3x3 的全部配方
		# (= 工作台也能合 2x2 的徒手配方, 用户偏好)
		var recipe_size: int = max(recipe.grid_size.x, recipe.grid_size.y)
		btn.visible = (recipe_size <= _mode)
		if not btn.visible:
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
		else:
			icon.texture = ArtCache.get_inventory_icon(s.item_id)
			count_lbl.text = "" if s.count <= 1 else str(s.count)


# ============= 旧测试 API (保留) =============

func _make_cell(r: int, c: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	var style := StyleBoxFlat.new()
	style.bg_color = CELL_NORMAL_COLOR
	style.border_color = Color(0.4, 0.4, 0.4, 1)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
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
		return  # 不接管 cursor (留给老逻辑)
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
	_output_preview = RecipeMatcher.find_match(sub)


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
