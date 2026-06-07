# 水珠对象池. 预分配 N 颗 WaterGrainParticle 复用, 代替每次 instantiate / queue_free。
# 仿 dust_pool.gd / spark_pool.gd。瀑布密集处一秒几十颗, 没池就一直 alloc 卡帧。
extends Node2D

const PoolSize := 120
const WaterGrainScene = preload("res://scenes/fx/water_grain_particle.tscn")

var _pool: Array[Node] = []
var _idle: Array[Node] = []


func _ready() -> void:
	add_to_group("water_grain_pool")
	for i in PoolSize:
		var g = WaterGrainScene.instantiate()
		add_child(g)
		if "_pool" in g:
			g._pool = self   # 水珠死时调 self.recycle(g) 回池
		_deactivate(g)
		_pool.append(g)
		_idle.append(g)


# 返回 true = 取到并激活; false = 池满, 调用方放弃这一颗。
func request_grain(start_pos: Vector2, vel: Vector2, color: Color) -> bool:
	if _idle.is_empty():
		return false
	var g: Node = _idle.pop_back()
	_activate(g, start_pos, vel, color)
	return true


func recycle(g: Node) -> void:
	if g == null or not is_instance_valid(g):
		return
	_deactivate(g)
	_idle.append(g)


func _activate(g: Node, pos: Vector2, vel: Vector2, color: Color) -> void:
	g.visible = true
	g.set_process(true)
	if g.has_method("setup"):
		g.setup(pos, vel, color)


func _deactivate(g: Node) -> void:
	g.visible = false
	g.set_process(false)
