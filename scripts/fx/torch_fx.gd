# 火把整体特效。挂在 TorchLights 下, 跟 tile 坐标对齐。
# 三个组件:
#   - Flame: 2 帧 sprite 切换 (scale.y 微跳)
#   - Light: PointLight2D, energy 呼吸 (sin + 随机抖)
#   - SparkTimer: 0.12-0.20s 触发一次, spawn 火花到 effects_root
extends Node2D

const TILE_SIZE := ChunkConstants.TILE_SIZE
const LIGHT_RADIUS := 48        # 半径 px
const BASE_ENERGY := 1.2
const ENERGY_OSC := 0.10        # sin 幅度
const ENERGY_NOISE := 0.05      # 每帧随机抖幅度
const FLAME_FRAME_TIME := 0.15
const LIGHT_COLOR := Color(1.0, 0.7, 0.3)

const TorchSparkScene = preload("res://scenes/fx/torch_spark_particle.tscn")

var _time: float = 0.0
var _flame_t: float = 0.0
var _flame_frame: int = 0

@onready var flame: Sprite2D = $Flame
@onready var light: PointLight2D = $Light
@onready var spark_timer: Timer = $SparkTimer


func _ready() -> void:
	# 老 Light2D 光照已禁用 (改用 DarknessLayer 瓦片光照)。
	# Light 节点保留场景结构兼容性, 但不发光 — 真实照明由 TileLightGrid 计算。
	light.enabled = false
	_setup_flame_texture()
	spark_timer.wait_time = randf_range(0.12, 0.20)
	spark_timer.start()
	spark_timer.timeout.connect(_on_spark)


# 火苗 sprite: 用 ParticlesArt 暖色像素拉伸成竖向 4x6 小火苗, 放在 tile 顶上方
func _setup_flame_texture() -> void:
	var ParticlesArt = preload("res://scripts/fx/particles_art.gd")
	flame.texture = ParticlesArt.get_torch_spark(Color(1.0, 0.6, 0.2))
	flame.scale = Vector2(2, 3)
	flame.position = Vector2(0, -6)


func _process(delta: float) -> void:
	_time += delta
	# Light 已禁用, 仅做火焰 2 帧切换
	_flame_t += delta
	if _flame_t >= FLAME_FRAME_TIME:
		_flame_t = 0.0
		_flame_frame = 1 - _flame_frame
		flame.scale.y = 3.0 if _flame_frame == 0 else 2.6


func _on_spark() -> void:
	var spawn_pos: Vector2 = global_position + Vector2(randf_range(-1, 1), -7)
	# 优先用 SparkPool (effects_root 下), 池满或没池 fallback 老 instantiate
	var pool: Node = get_tree().get_first_node_in_group("spark_pool")
	if pool != null and pool.has_method("request_spark"):
		pool.request_spark(spawn_pos)
	else:
		var s = TorchSparkScene.instantiate()
		var root: Node = get_tree().get_first_node_in_group("effects_root")
		if root == null:
			root = get_tree().current_scene
		if root != null:
			root.add_child(s)
			s.setup(spawn_pos)
	# 下一次 timer 随机
	spark_timer.wait_time = randf_range(0.12, 0.20)
	spark_timer.start()
