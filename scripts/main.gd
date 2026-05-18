# 游戏根：实例化 World + HUD + DebugHUD + FloatingPrompt。
extends Node

const WorldScene = preload("res://scenes/world/world.tscn")
const DebugHudScene = preload("res://scenes/ui/debug_hud.tscn")
const FloatingPromptScene = preload("res://scenes/ui/floating_prompt.tscn")
const HudScene = preload("res://scenes/ui/hud.tscn")

var world: Node2D
var debug_hud: CanvasLayer
var floating_prompt: CanvasLayer
var hud: CanvasLayer


func _ready() -> void:
	world = WorldScene.instantiate()
	add_child(world)

	hud = HudScene.instantiate()
	add_child(hud)

	floating_prompt = FloatingPromptScene.instantiate()
	floating_prompt.add_to_group("floating_prompt")
	add_child(floating_prompt)

	debug_hud = DebugHudScene.instantiate()
	add_child(debug_hud)

	# 等下一帧 World._ready 完成（玩家被 spawn）再绑
	_wire_player.call_deferred()


func _wire_player() -> void:
	var player: Node2D = world.get_player()
	if player == null:
		return
	debug_hud.set_player(player)
	hud.bind_player(player)
