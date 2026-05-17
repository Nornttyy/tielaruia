# 游戏根：实例化 World + DebugHUD，串好引用。
extends Node

const WorldScene = preload("res://scenes/world/world.tscn")
const DebugHudScene = preload("res://scenes/ui/debug_hud.tscn")

var world: Node2D
var debug_hud: CanvasLayer


func _ready() -> void:
	world = WorldScene.instantiate()
	add_child(world)

	debug_hud = DebugHudScene.instantiate()
	add_child(debug_hud)

	# 等 World 完成 _ready (它在 _ready 里 spawn 玩家)，
	# 再把玩家引用传给 HUD。call_deferred 确保下一帧。
	debug_hud.call_deferred("set_player", world.get_player())
