# 灰尘对象池. 跳/落/走 3 种动作都用 DustParticle, 跳一下 4 颗 / 落一下 6 颗.
# 没池每次 instantiate + add_child + _ready, 每秒多次跳 = 多次 alloc 卡帧.
# 池预分配 60 个, 复用. 比 SparkPool 同模式.
extends Node2D

const PoolSize := 60
const DustParticleScene = preload("res://scenes/fx/dust_particle.tscn")

var _pool: Array[Node] = []
var _idle: Array[Node] = []


func _ready() -> void:
	add_to_group("dust_pool")
	for i in PoolSize:
		var d = DustParticleScene.instantiate()
		add_child(d)
		if "_pool" in d:
			d._pool = self
		_deactivate(d)
		_pool.append(d)
		_idle.append(d)


# 返回 true = 成功取到 + 已激活. false = 池满, 调用方应放弃这一颗.
func request_dust(start_pos: Vector2, scale_factor: float = 1.0) -> bool:
	if _idle.is_empty():
		return false
	var d: Node = _idle.pop_back()
	_activate(d, start_pos, scale_factor)
	return true


# DustParticle 寿命到调: 回池
func recycle(d: Node) -> void:
	if d == null or not is_instance_valid(d):
		return
	_deactivate(d)
	_idle.append(d)


func _activate(d: Node, pos: Vector2, scale_factor: float) -> void:
	d.visible = true
	d.set_process(true)
	if d.has_method("setup"):
		d.setup(pos, scale_factor)


func _deactivate(d: Node) -> void:
	d.visible = false
	d.set_process(false)
