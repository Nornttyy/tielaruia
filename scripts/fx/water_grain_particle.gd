# 单颗水珠 (纯视觉)。受重力下落, 短寿命渐隐后回池。
# 由 WaterGrainPool 管理 — 寿命到调 _pool.recycle(self) 复用, 没池兜底 queue_free。
# 重力比碎块(800)轻 → 水珠飘一点, 不像石头那样砸下去。
extends Sprite2D

const ParticlesArt = preload("res://scripts/fx/particles_art.gd")
const GRAVITY := 520.0
const LIFETIME := 0.6
const TILE_SIZE := ChunkConstants.TILE_SIZE               # 本项目格子像素 (落地碰撞查询用)

var velocity: Vector2 = Vector2.ZERO
var _age: float = 0.0
var _alpha0: float = 1.0   # 起始 alpha (群系水色自带), 渐隐基于它
var _pool: Node = null     # WaterGrainPool 持有, 死时回池
var _cm = null             # chunk_manager: 查 get_tile 做落地碰撞 (池在 _activate 时赋值, 可能 null)
var _splashes: bool = true # 落地是否溅小花。落地溅出的小水珠设 false → 不再二次溅 (防无限套娃)


func setup(start_pos: Vector2, vel: Vector2, color: Color, splashes: bool = true) -> void:
	global_position = start_pos
	velocity = vel
	texture = ParticlesArt.get_water_drop()
	modulate = color
	_alpha0 = color.a
	_splashes = splashes
	_age = 0.0   # 池复用必须归零, 否则立刻"老了"消失


func _process(delta: float) -> void:
	_age += delta
	velocity.y += GRAVITY * delta
	global_position += velocity * delta
	modulate.a = _alpha0 * clamp(1.0 - _age / LIFETIME, 0.0, 1.0)
	# 落地: 撞到实心方块 → 溅一小朵 + 顺坡偏 + 回收。
	# 只认 solid 不认水: 水珠是从"水刚落进的那格水"里冒出来的, 认水会一生成就溅 (没弧线)。
	if _cm != null and _splashes:
		var tx: int = floori(global_position.x / float(TILE_SIZE))
		var ty: int = floori(global_position.y / float(TILE_SIZE))
		if Tiles.is_solid(_cm.get_tile(tx, ty)):
			_splash_on_land(tx, ty)
			_recycle()
			return
	if _age >= LIFETIME:
		_recycle()


# 落地溅花: 顺坡偏 + 溅 1 颗向上的小水珠 (splashes=false 防套娃)。
func _splash_on_land(tx: int, ty: int) -> void:
	var bias := 0.0   # 顺坡: 落点左右哪边是空的(低) → 溅花往那边偏
	var left_open: bool = not Tiles.is_solid(_cm.get_tile(tx - 1, ty))
	var right_open: bool = not Tiles.is_solid(_cm.get_tile(tx + 1, ty))
	if left_open and not right_open:
		bias = -28.0
	elif right_open and not left_open:
		bias = 28.0
	Effects.spawn_water_grains(global_position, Vector2(bias, -28), Tiles.WATER, 1, false)


func _recycle() -> void:
	if _pool != null and _pool.has_method("recycle"):
		_pool.recycle(self)
	else:
		queue_free()   # 没池兜底
