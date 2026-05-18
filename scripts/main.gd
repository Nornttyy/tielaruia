# 游戏根：实例化 World + DebugHUD + FloatingPrompt。
extends Node

const WorldScene = preload("res://scenes/world/world.tscn")
const DebugHudScene = preload("res://scenes/ui/debug_hud.tscn")
const FloatingPromptScene = preload("res://scenes/ui/floating_prompt.tscn")

var world: Node2D
var debug_hud: CanvasLayer
var floating_prompt: CanvasLayer


func _ready() -> void:
	world = WorldScene.instantiate()
	add_child(world)

	floating_prompt = FloatingPromptScene.instantiate()
	floating_prompt.add_to_group("floating_prompt")
	add_child(floating_prompt)

	debug_hud = DebugHudScene.instantiate()
	add_child(debug_hud)

	debug_hud.call_deferred("set_player", world.get_player())
