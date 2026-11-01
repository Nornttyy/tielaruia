# 地上的物品堆。Area2D 检测玩家碰触，触发拾取。
extends Area2D

const GRAVITY := 450.0
const FRICTION := 150.0
const MAX_FALL_SPEED := 300.0
const LIFETIME_SECONDS := 30.0
const PICKUP_DELAY := 0.4  # 刚 spawn 时短暂无法拾取
const TILE_SIZE := 12
const Metrics = preload("res://scripts/art/world_metrics.gd")

@export var item_id: String = ""
@export var count: int = 1
# 联机: client 端的 remote drop 用 host 给的 ent_id (跨实例稳定 id),
# host 端不需要预设 (用 entity_id_for(self) 自动算).
@export var ent_id: int = 0
# 非零 = 丢弃时给的初速度 (朝鼠标飞一小段). 为零则用默认随机弹跳 (挖矿/死亡掉落).
@export var toss_velocity: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var lifetime: Timer = $Lifetime

var velocity: Vector2 = Vector2.ZERO
var _pickup_ready: bool = false
var _cached_terrain: TileMapLayer = null  # 缓存 terrain ref, 50+ drops 时每帧少 50 群组查
var _half_size := Vector2(6, 6)


func _ready() -> void:
	if item_id != "":
		sprite.texture = ArtCache.get_inventory_icon(item_id)
	_configure_bounds()
	lifetime.wait_time = LIFETIME_SECONDS
	lifetime.one_shot = true
	lifetime.start()
	lifetime.timeout.connect(queue_free)
	# 初速度: 丢弃 (toss_velocity 非零) 时朝鼠标飞一小段; 否则随机弹跳 (挖矿/死亡掉落)
	if toss_velocity != Vector2.ZERO:
		velocity = toss_velocity
	else:
		velocity = Vector2(randf_range(-22.0, 22.0), -60.0)
	# 短暂延迟才可拾取；到时再扫一次已重叠的 body（玩家跟着掉落同帧重叠时
	# body_entered 不会触发，需要主动检查）
	get_tree().create_timer(PICKUP_DELAY).timeout.connect(_on_pickup_ready)
	body_entered.connect(_on_body_entered)
	add_to_group("item_drops")
	# 联机 host: 离场时 (被捡 / lifetime 到期) 广播 ent_die, 让 client 端同步消失.
	# 用 tree_exiting 信号 (queue_free 后 frame 末触发, instance_id 仍可用).
	if not has_meta("is_remote") \
			and NetworkManager != null \
			and NetworkManager.connected() \
			and NetworkManager.is_host:
		tree_exiting.connect(_on_host_drop_exiting)


# host 端: drop 消失时通知 client. (client 端的 is_remote drop 不连接此信号)
func _on_host_drop_exiting() -> void:
	if NetworkManager != null and NetworkManager.connected() and NetworkManager.is_host:
		NetworkManager.send_entity_die(NetworkManager.entity_id_for(self))


func _on_pickup_ready() -> void:
	_pickup_ready = true
	# 扫描所有已重叠的 body，触发一次 pickup
	for body in get_overlapping_bodies():
		_on_body_entered(body)
		if not is_inside_tree():
			return  # 已经被 queue_free 了


func _physics_process(delta: float) -> void:
	# 联机 client 端的远程 drop: 位置由 host 直接 set, 自己不要跑物理 (否则跟同步信号打架抖)
	if has_meta("is_remote"):
		return
	velocity.y = min(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	# 水平摩擦
	velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	if _cached_terrain == null or not is_instance_valid(_cached_terrain):
		_cached_terrain = get_tree().get_first_node_in_group("terrain_layer") as TileMapLayer
	if _cached_terrain == null:
		position += velocity * delta
		return
	# 分步扫过整个物品的边缘，长剑/家具不能只检测贴图中心下方 3px。
	_move_axis(velocity.x * delta, false)
	_move_axis(velocity.y * delta, true)


func _configure_bounds() -> void:
	if sprite.texture == null: return
	sprite.scale = Vector2.ONE * Metrics.PIXEL_SCALE
	var opaque := sprite.texture.get_image().get_used_rect()
	if not opaque.has_area(): return
	sprite.offset = sprite.texture.get_size() / 2.0 - (Vector2(opaque.position) + Vector2(opaque.size) / 2.0)
	_half_size = Vector2(opaque.size) * Metrics.PIXEL_SCALE / 2.0
	var pickup_shape := RectangleShape2D.new()
	pickup_shape.size = _half_size * 2.0 + Vector2(4, 4)
	$CollisionShape2D.shape = pickup_shape


func _move_axis(distance: float, vertical: bool) -> void:
	if is_zero_approx(distance): return
	var steps := maxi(1, ceili(absf(distance) / 3.0))
	var amount := distance / steps
	var direction := signf(amount)
	for i in steps:
		var proposed := global_position + (Vector2(0, amount) if vertical else Vector2(amount, 0))
		var edge := proposed + (Vector2(0, direction * _half_size.y) if vertical else Vector2(direction * _half_size.x, 0))
		var span := _half_size.x if vertical else _half_size.y
		var a := edge - (Vector2(span - 0.1, 0) if vertical else Vector2(0, span - 0.1))
		var b := edge + (Vector2(span - 0.1, 0) if vertical else Vector2(0, span - 0.1))
		var first := _cached_terrain.local_to_map(_cached_terrain.to_local(a))
		var last := _cached_terrain.local_to_map(_cached_terrain.to_local(b))
		for n in range(first.x if vertical else first.y, (last.x if vertical else last.y) + 1):
			var cell := Vector2i(n, first.y) if vertical else Vector2i(first.x, n)
			var tile := _cached_terrain.get_cell_source_id(cell)
			if not Tiles.is_solid(tile) and not (vertical and direction > 0 and tile == Tiles.WOOD_PLATFORM): continue
			var center := _cached_terrain.to_global(_cached_terrain.map_to_local(cell))
			if vertical:
				proposed.y = center.y - direction * (TILE_SIZE / 2.0 + _half_size.y) - direction * 0.01
				velocity.y = -velocity.y * 0.25 if direction > 0 else 0.0
				velocity.x *= 0.5
				if absf(velocity.y) < 30.0: velocity.y = 0.0
			else:
				proposed.x = center.x - direction * (TILE_SIZE / 2.0 + _half_size.x) - direction * 0.01
				velocity.x *= -0.25
			global_position = proposed
			return
		global_position = proposed


func _on_body_entered(body: Node) -> void:
	if not _pickup_ready:
		return
	if not body.has_node("PlayerInventory"):
		return
	# 对战房: 资源本来就无限 → 凋落物不进背包, 碰到直接消失 (用户要求)。
	if NetworkManager != null and NetworkManager.room_mode == "pvp":
		queue_free()
		return
	var pi: Node = body.get_node("PlayerInventory")
	if not pi.has_method("pickup"):
		return
	var leftover: int = pi.pickup(item_id, count)
	if leftover < count:
		SfxBank.play("pickup", 0.20)
	if leftover == 0:
		# 是 remote drop (client 这边的 host 副本) → 通知 host 捡走它的真本
		# + 标 picked_up 防 host 0.2s 广播 又把它复活
		if has_meta("is_remote") \
				and NetworkManager != null and NetworkManager.connected() \
				and ent_id != 0:
			NetworkManager.send_drop_pickup(ent_id)
			var w: Node = get_tree().get_first_node_in_group("world")
			if w != null and w.has_method("mark_drop_picked_up"):
				w.mark_drop_picked_up(ent_id)
		queue_free()
	else:
		count = leftover
