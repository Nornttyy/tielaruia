# 游戏根：实例化 World + HUD + CraftingPanel + DebugHUD + FloatingPrompt。
extends Node

const WorldScene = preload("res://scenes/world/world.tscn")
const DebugHudScene = preload("res://scenes/ui/debug_hud.tscn")
const FloatingPromptScene = preload("res://scenes/ui/floating_prompt.tscn")
const HudScene = preload("res://scenes/ui/hud.tscn")
const CraftingPanelScene = preload("res://scenes/ui/crafting_panel.tscn")

var world: Node2D
var debug_hud: CanvasLayer
var floating_prompt: CanvasLayer
var hud: CanvasLayer
var crafting_panel: CanvasLayer


func _ready() -> void:
	world = WorldScene.instantiate()
	add_child(world)

	hud = HudScene.instantiate()
	add_child(hud)

	crafting_panel = CraftingPanelScene.instantiate()
	crafting_panel.add_to_group("crafting_panel")
	add_child(crafting_panel)

	floating_prompt = FloatingPromptScene.instantiate()
	floating_prompt.add_to_group("floating_prompt")
	add_child(floating_prompt)

	debug_hud = DebugHudScene.instantiate()
	add_child(debug_hud)

	_wire_player.call_deferred()


func _wire_player() -> void:
	var player: Node2D = world.get_player()
	if player == null:
		return
	debug_hud.set_player(player)
	hud.bind_player(player)
	crafting_panel.bind_inventory(player.get_node("PlayerInventory"))
