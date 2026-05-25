# 地上的物品堆。Area2D 检测玩家碰触，触发拾取。
extends Area2D

const GRAVITY := 600.0
const FRICTION := 200.0
const MAX_FALL_SPEED := 400.0
const LIFETIME_SECONDS := 30.0
const PICKUP_DELAY := 0.4  # 刚 spawn 时短暂无法拾取
const TILE_SIZE := 16

@export var item_id: String = ""
@export var count: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var lifetime: Timer = $Lifetime

var velocity: Vector2 = Vector2.ZERO
var _pickup_ready: bool = false


func _ready() -> void:
	if item_id != "":
		sprite.texture = ArtCache.get_inventory_icon(item_id)
	lifetime.wait_time = LIFETIME_SECONDS
	lifetime.one_shot = true
	lifetime.start()
	lifetime.timeout.connect(queue_free)
	# 初始随机弹跳动量
	velocity = Vector2(randf_range(-30.0, 30.0), -80.0)
	# 短暂延迟才可拾取；到时再扫一次已重叠的 body（玩家跟着掉落同帧重叠时
	# body_entered 不会触发，需要主动检查）
	get_tree().create_timer(PICKUP_DELAY).timeout.connect(_on_pickup_ready)
	body_entered.connect(_on_body_entered)
	add_to_group("item_drops")


func _on_pickup_ready() -> void:
	_pickup_ready = true
	# 扫描所有已重叠的 body，触发一次 pickup
	for body in get_overlapping_bodies():
		_on_body_entered(body)
		if not is_inside_tree():
			return  # 已经被 queue_free 了


func _physics_process(delta: float) -> void:
	velocity.y = min(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	# 水平摩擦
	velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	var prev_position := position
	position += velocity * delta
	# 简单地面检测：查脚下 tile 是否实心
	var terrain := get_tree().get_first_node_in_group("terrain_layer")
	if terrain != null:
		var foot_tile: Vector2i = terrain.local_to_map(terrain.to_local(global_position + Vector2(0, 4)))
		var tid: int = terrain.get_cell_source_id(foot_tile)
		if tid != -1 and Tiles.is_solid(tid):
			if velocity.y > 0.0:
				position = prev_position
				velocity.y = -velocity.y * 0.25
				velocity.x *= 0.5
				if abs(velocity.y) < 30.0:
					velocity.y = 0.0


func _on_body_entered(body: Node) -> void:
	if not _pickup_ready:
		return
	# 联机 client: 远程掉落物只看不能捡 (host 才是权威, client 捡会和主端不同步)
	if has_meta("is_remote"):
		return
	if not body.has_node("PlayerInventory"):
		return
	var pi: Node = body.get_node("PlayerInventory")
	if not pi.has_method("pickup"):
		return
	var leftover: int = pi.pickup(item_id, count)
	if leftover < count:
		SfxBank.play("pickup", 0.20)  # ±20% 变调, Minecraft 风
	if leftover == 0:
		queue_free()
	else:
		count = leftover
