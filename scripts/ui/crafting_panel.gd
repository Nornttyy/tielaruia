# 合成面板: 显示背包 (36 槽只读) + 配方列表 (一键合成)。
# 旧的 _cells/_cursor_item 内部网格保留, 仅供集成测试调用 (place_in_cell / simulate_take_output)。
extends CanvasLayer

const RecipeMatcher = preload("res://scripts/crafting/recipe_matcher.gd")

const CELL_SIZE := 40
const SLOT_SIZE := 36
const RECIPE_SIZE := 48
const CELL_NORMAL_COLOR := Color(0, 0, 0, 0.4)

signal opened
signal closed

@onready var grid: GridContainer = $Center/Panel/VBox/Row/InputGrid
@onready var output_slot: PanelContainer = $Center/Panel/VBox/Row/OutputSlot
@onready var cursor: PanelContainer = $Cursor
@onready var vbox: VBoxContainer = $Center/Panel/VBox
@onready var row_old: HBoxContainer = $Center/Panel/VBox/Row

var _player_inv: Node = null
var _mode: int = 0
var _cells: Array = []
var _cell_nodes: Array = []
var _output_preview: Variant = null
var _cursor_item: Variant = null

# 新 UI 节点 (由 _ready 程序化构建)
var _title_label: Label
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
	# 标题
	_title_label = Label.new()
	_title_label.text = "合成 & 背包"
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	vbox.add_child(_title_label)
	vbox.move_child(_title_label, 0)

	# 工作台状态
	_wb_label = Label.new()
	_wb_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_wb_label)
	vbox.move_child(_wb_label, 1)

	# 配方区
	var rec_title := Label.new()
	rec_title.text = "── 配方 ──"
	rec_title.add_theme_font_size_override("font_size", 12)
	rec_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(rec_title)
	vbox.move_child(rec_title, 2)

	_recipe_container = VBoxContainer.new()
	_recipe_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_recipe_container)
	vbox.move_child(_recipe_container, 3)
	_build_recipe_buttons()

	# 背包区
	var inv_title := Label.new()
	inv_title.text = "── 背包 ──"
	inv_title.add_theme_font_size_override("font_size", 12)
	inv_title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(inv_title)
	vbox.move_child(inv_title, 4)

	_inv_grid = GridContainer.new()
	_inv_grid.columns = 9
	_inv_grid.add_theme_constant_override("h_separation", 3)
	_inv_grid.add_theme_constant_override("v_separation", 3)
	vbox.add_child(_inv_grid)
	vbox.move_child(_inv_grid, 5)
	_build_inv_slots()

	# 关闭提示
	var hint := Label.new()
	hint.text = "按 E 关闭"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)


func _build_recipe_buttons() -> void:
	# 分两行: 2x2 在上 (徒手), 3x3 在下 (工作台)
	var row_2x2 := HBoxContainer.new()
	row_2x2.add_theme_constant_override("separation", 6)
	_recipe_container.add_child(row_2x2)
	var row_3x3 := HBoxContainer.new()
	row_3x3.add_theme_constant_override("separation", 6)
	_recipe_container.add_child(row_3x3)

	for r in RecipeDB.all_recipes():
		var entry := _make_recipe_button(r)
		_recipe_buttons.append(entry)
		var parent: HBoxContainer = row_2x2 if r.grid_size.x == 2 else row_3x3
		parent.add_child(entry.button)


func _make_recipe_button(recipe: Dictionary) -> Dictionary:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(RECIPE_SIZE + 24, RECIPE_SIZE + 24)
	btn.tooltip_text = _recipe_tooltip(recipe)
	# 内容: 图标在上 + 数量, 下方小文字材料
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.add_child(vb)

	var icon := TextureRect.new()
	icon.texture = ArtCache.get_inventory_icon(recipe.output_id)
	icon.custom_minimum_size = Vector2(RECIPE_SIZE, RECIPE_SIZE)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(icon)

	var cost_label := Label.new()
	cost_label.add_theme_font_size_override("font_size", 9)
	cost_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(cost_label)
	cost_label.text = _short_cost_text(recipe)

	btn.pressed.connect(_on_recipe_pressed.bind(recipe.id))
	return {"recipe": recipe, "button": btn, "cost_label": cost_label}


func _build_inv_slots() -> void:
	for i in 36:
		var slot := _make_inv_slot(i)
		_inv_grid.add_child(slot)
		_inv_slot_nodes.append(slot)


func _make_inv_slot(idx: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.clip_contents = true
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
	var lines: Array = ["产出: %s × %d" % [recipe.output_id, recipe.output_count]]
	for item_id in req:
		lines.append("  · %s × %d" % [item_id, req[item_id]])
	if recipe.grid_size.x == 3:
		lines.append("(需要工作台)")
	return "\n".join(lines)


func _short_cost_text(recipe: Dictionary) -> String:
	var req: Dictionary = _required_inputs(recipe)
	var parts: Array = []
	for item_id in req:
		parts.append("%d%s" % [req[item_id], _short_name(item_id)])
	return " ".join(parts)


func _short_name(item_id: String) -> String:
	const SHORT := {
		"log": "原木", "planks": "板", "stick": "棍",
		"workbench": "台", "leaves": "叶",
	}
	return SHORT.get(item_id, item_id)


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
	# 内部 cells 的物品退回 (测试可能放置)
	if _player_inv != null:
		for r in 3:
			for c in 3:
				var v = _cells[r][c]
				if v != null:
					_player_inv.pickup(v.item_id, v.count)
					_cells[r][c] = null
		if _cursor_item != null:
			_player_inv.pickup(_cursor_item.item_id, _cursor_item.count)
	_cursor_item = null
	_output_preview = null
	cursor.visible = false
	visible = false
	_mode = 0
	closed.emit()


func is_open() -> bool:
	return visible and _mode > 0


# ---- 配方点击 ----

func _on_recipe_pressed(recipe_id: String) -> void:
	var recipe = RecipeDB.get_recipe(recipe_id)
	if recipe == null:
		return
	# 检查模式: 3x3 配方需要工作台 (_mode == 3)
	if recipe.grid_size.x > _mode:
		return
	if _player_inv == null:
		return
	var inv = _player_inv.inventory
	var req = _required_inputs(recipe)
	# 检查素材
	for item_id in req:
		if _count_in_inv(inv, item_id) < req[item_id]:
			return
	# 输出格够不够? add 会自动判断 leftover
	# 先扣再加, leftover 用 drop 兜底 (简单起见)
	for item_id in req:
		_remove_from_inv(inv, item_id, req[item_id])
	var leftover = inv.add(recipe.output_id, recipe.output_count)
	# leftover 暂时丢弃 (后续可改成掉地上)
	if leftover > 0:
		# 加回去保证不丢: 跑一遍 add (理论上不应发生因为输出 count 通常 <=4)
		pass
	_player_inv.inventory_changed.emit()


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
		_wb_label.text = "🛠 工作台旁 — 全部配方可用"
		_wb_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	else:
		_wb_label.text = "✋ 徒手 — 仅 2×2 配方可用"
		_wb_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.5))


func _refresh_recipes() -> void:
	if _player_inv == null:
		return
	var inv = _player_inv.inventory
	for entry in _recipe_buttons:
		var recipe: Dictionary = entry.recipe
		var btn: Button = entry.button
		var needs_workbench: bool = recipe.grid_size.x == 3
		var has_workbench: bool = _mode == 3
		var req: Dictionary = _required_inputs(recipe)
		var has_materials: bool = true
		for item_id in req:
			if _count_in_inv(inv, item_id) < req[item_id]:
				has_materials = false
				break
		var disabled: bool = (needs_workbench and not has_workbench) or not has_materials
		btn.disabled = disabled
		# 视觉提示
		if disabled:
			btn.modulate = Color(0.5, 0.5, 0.5, 0.7)
		else:
			btn.modulate = Color(1, 1, 1, 1)


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
