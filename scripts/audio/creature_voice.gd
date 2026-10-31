# 僵尸/骷髅隔一段时间叫一次，远处和死亡实体不发声。
extends Node
var _remaining := 4.0
func _ready() -> void:
	_remaining = randf_range(4.0, 12.0)
func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining > 0.0: return
	_remaining = randf_range(5.0, 14.0)
	var creature := get_parent() as Node2D
	if creature == null or creature.is_queued_for_deletion(): return
	if creature.get("_is_dying") == true: return
	SfxBank.play_at("zombie_idle", creature.global_position, 300.0)
