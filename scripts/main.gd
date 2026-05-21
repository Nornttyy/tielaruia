# 游戏根 + 状态机。
# 状态: "menu" (主菜单显示中) / "game" (世界 + HUD + 面板存在)。
# 启动进 menu。MainMenu 点新游戏 → game。暂停菜单点回主菜单 → menu。
extends Node

const WorldScene = preload("res://scenes/world/world.tscn")
const DebugHudScene = preload("res://scenes/ui/debug_hud.tscn")
const FloatingPromptScene = preload("res://scenes/ui/floating_prompt.tscn")
const HudScene = preload("res://scenes/ui/hud.tscn")
const CraftingPanelScene = preload("res://scenes/ui/crafting_panel.tscn")
const DialogueBoxScene = preload("res://scenes/ui/dialogue_box.tscn")

@onready var _main_menu: CanvasLayer = $MainMenu
@onready var _pause_menu: CanvasLayer = $PauseMenu
@onready var _death_screen: CanvasLayer = $DeathScreen

var _state: String = "menu"
var _game_nodes: Array[Node] = []

var world: Node2D:
	get:
		return get_node_or_null("World")


func _ready() -> void:
	_main_menu.start_game.connect(_start_game)
	_pause_menu.return_to_menu.connect(_return_to_menu)
	_death_screen.respawn.connect(_on_respawn)
	_show_menu_state()


func _show_menu_state() -> void:
	_state = "menu"
	_main_menu.visible = true
	_pause_menu.close()
	_death_screen.hide_death()


func _start_game(world_seed: int = 0) -> void:
	_state = "game"
	if _main_menu != null and is_instance_valid(_main_menu):
		_main_menu.visible = false
	var w = WorldScene.instantiate()
	w.name = "World"
	if world_seed != 0:
		w.world_seed = world_seed
	add_child(w)
	_game_nodes.append(w)

	var hud = HudScene.instantiate()
	hud.name = "HUD"
	add_child(hud)
	_game_nodes.append(hud)

	var crafting = CraftingPanelScene.instantiate()
	crafting.name = "CraftingPanel"
	crafting.add_to_group("crafting_panel")
	add_child(crafting)
	_game_nodes.append(crafting)

	var floating = FloatingPromptScene.instantiate()
	floating.add_to_group("floating_prompt")
	add_child(floating)
	_game_nodes.append(floating)

	var debug = DebugHudScene.instantiate()
	add_child(debug)
	_game_nodes.append(debug)

	var dialogue = DialogueBoxScene.instantiate()
	add_child(dialogue)
	_game_nodes.append(dialogue)

	_wire_player.call_deferred()


# 测试用 helper: 同步切到 game 状态。等价于按"新游戏"。
# 顺便 queue_free MainMenu (测试不需要主菜单的 tween/动画副作用)。
# 默认固定 seed=42 让测试结果可重复; 生产路径走 _main_menu.start_game 信号 → _start_game() 走随机.
func boot_to_game(world_seed: int = 42) -> void:
	if _state == "game":
		return
	if _main_menu != null and is_instance_valid(_main_menu):
		_main_menu.queue_free()
		_main_menu = null
	_start_game(world_seed)


func _wire_player() -> void:
	var w := world
	if w == null:
		return
	var player: Node2D = w.get_player()
	if player == null:
		return
	for child in _game_nodes:
		if child.has_method("bind_player"):
			child.bind_player(player)
		if child.has_method("bind_inventory"):
			child.bind_inventory(player.get_node("PlayerInventory"))
		if child.has_method("set_player"):
			child.set_player(player)
	# 死亡信号 → 死亡屏
	var hp: Node = player.get_node_or_null("PlayerHealth")
	if hp != null and hp.has_signal("died"):
		if not hp.died.is_connected(_death_screen.show_death):
			hp.died.connect(_death_screen.show_death)


func _return_to_menu() -> void:
	_pause_menu.close()
	for n in _game_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_game_nodes.clear()
	get_tree().paused = false
	_show_menu_state()


func _on_respawn() -> void:
	var w := world
	if w != null:
		w.respawn_player()
	_death_screen.hide_death()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_save") and _state == "game":
		SaveManager.save(self)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_pause") and _state == "game":
		if _death_screen.visible:
			return
		# 对话框开着时 ESC 优先让对话框自己关 (它的 _unhandled_input 会消费)
		var db := get_tree().get_first_node_in_group("dialogue_box")
		if db != null and db.visible:
			return
		_pause_menu.toggle()
		get_viewport().set_input_as_handled()
