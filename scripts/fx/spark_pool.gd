# 火花对象池. 预分配 N 个 spark Sprite2D, 复用代替每次 instantiate / queue_free.
# 一颗火花活 0.8s, 每个火把 0.12-0.20s 喷一颗 → 每火把同时存活 4-7 颗.
# 50 个火把就会有 200-350 颗火花同时存在; 没池每秒分配 ~250 个 Sprite, 池后省掉.
extends Node2D

const PoolSize := 80                         # 上限. 超了暂时丢一帧火花 (没池就要 alloc, 太亏)
const TorchSparkScene = preload("res://scenes/fx/torch_spark_particle.tscn")

var _pool: Array[Node] = []   # 全部预分配的 spark (含 active + idle)
var _idle: Array[Node] = []   # 空闲列表


func _ready() -> void:
	add_to_group("spark_pool")
	for i in PoolSize:
		var s = TorchSparkScene.instantiate()
		add_child(s)
		if "_pool" in s:
			s._pool = self   # 火花死时调 self.recycle(s) 回池
		_deactivate(s)
		_pool.append(s)
		_idle.append(s)


func request_spark(start_pos: Vector2) -> void:
	# 找一个 idle 的, 没了就跳过 (限流防卡)
	if _idle.is_empty():
		return
	var s: Node = _idle.pop_back()
	_activate(s, start_pos)


# 火花 spark 自己调: lifetime 到了 → 回池
func recycle(s: Node) -> void:
	if s == null or not is_instance_valid(s):
		return
	_deactivate(s)
	_idle.append(s)


func _activate(s: Node, pos: Vector2) -> void:
	s.visible = true
	s.set_physics_process(true)
	(s as Sprite2D).global_position = pos
	if s.has_method("setup"):
		s.setup(pos)   # 重置 velocity / color / age
	(s as Sprite2D).modulate = Color(1, 1, 1, 1)
	# spark 自己用 reset_age() 把 _age 归零 (从 setup 里走)


func _deactivate(s: Node) -> void:
	s.visible = false
	s.set_physics_process(false)
