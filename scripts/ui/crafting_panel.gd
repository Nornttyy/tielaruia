# 弹出式合成面板。CanvasLayer，遮住游戏画面顶部。
# - open(2) → 2x2 模式 (按 C 触发)
# - open(3) → 3x3 模式 (E + 靠近工作台)
# - 关闭时残留 input 物品退回 Inventory
extends CanvasLayer

const GRID_2 := 2
const GRID_3 := 3

signal opened
signal closed

@onready var panel: PanelContainer = $Center/Panel
@onready var grid: GridContainer = $Center/Panel/VBox/Row/InputGrid
@onready var output_slot: PanelContainer = $Center/Panel/VBox/Row/OutputSlot
@onready var cursor: PanelContainer = $Cursor

var _player_inv: Node = null
var _mode: int = 0           # 2 or 3 or 0 (closed)
# _cells[r][c] = null 或 {"item_id", "count"}；3x3 满布；2x2 模式只用 [0..1][0..1]
var _cells: Array = []
var _cursor_item: Variant = null
var _output_preview: Variant = null


func _ready() -> void:
	_init_cells()
	visible = false


func _init_cells() -> void:
	_cells.resize(3)
	for r in 3:
		var row: Array = []
		row.resize(3)
		row.fill(null)
		_cells[r] = row


func bind_inventory(player_inv: Node) -> void:
	_player_inv = player_inv


func open(grid_n: int) -> void:
	_mode = grid_n
	# 清空 grid 视觉 child
	for child in grid.get_children():
		child.queue_free()
	_init_cells()
	_output_preview = null
	visible = true
	opened.emit()


func close() -> void:
	_return_cells_to_inventory()
	_init_cells()
	_output_preview = null
	if _cursor_item != null and _player_inv != null:
		_player_inv.pickup(_cursor_item.item_id, _cursor_item.count)
		_cursor_item = null
	cursor.visible = false
	visible = false
	_mode = 0
	closed.emit()


func is_open() -> bool:
	return visible and _mode > 0


func _return_cells_to_inventory() -> void:
	if _player_inv == null:
		return
	for r in 3:
		for c in 3:
			var v = _cells[r][c]
			if v != null:
				_player_inv.pickup(v.item_id, v.count)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("ui_cancel_crafting"):
		close()
		get_viewport().set_input_as_handled()
