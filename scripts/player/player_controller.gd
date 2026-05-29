# 玩家控制器：左右移动、跳跃、重力、AnimatedSprite2D 动画切换。
# 朝向通过 sprite.flip_h 处理；面向右默认。
extends CharacterBody2D

const Chunk = preload("res://scripts/world/chunk.gd")
const ItemsArt = preload("res://scripts/art/items_art.gd")
const CAVE_DEPTH_THRESHOLD := 10   # 玩家离原始地表 >10 格才算"地下" (即使顶上方块挖掉了)

const SPEED := 105.0
const JUMP_VELOCITY := -240.0
const GRAVITY := 675.0
const COYOTE_TIME := 0.10
const LAND_VY_THRESHOLD := 150.0    # 落地时 vy 超此值才扬大灰
const WALK_PUFF_INTERVAL := 0.3     # 走路每 0.3s 一次 puff
const TILE_SIZE := 12
# 游泳物理: 水里重力 ~22%, 按 Space/W 持续上浮.
const SWIM_GRAVITY := 150.0         # 水里重力 (vs GRAVITY 900 → 慢慢沉)
const SWIM_UP_SPEED := -82.0       # 按 jump 上浮速度 (vs JUMP_VELOCITY -320 → 弱跳)
const SWIM_MAX_SINK := 135.0        # 最大下沉速度 (浮力封顶)
const ROPE_CLIMB_SPEED := 82.0     # 绳子上下爬速度 (vs SPEED 140 — 慢点)
const ROPE_HOLD_GRAVITY := 0.0      # 抓绳子时无重力 (松手才掉)
# 玩家碰撞框高度 (跟 player.tscn 同步, 用于水/绳/头检测)
const PLAYER_BODY_HEIGHT := 22      # collider y 尺寸 (1.3x 之后)
const PLAYER_HEAD_OFFSET := -22     # 头部 y 偏移 (脚到头)
const PLAYER_WAIST_OFFSET := -11    # 腰部 y 偏移

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _player_aura: PointLight2D = $PlayerAura
@onready var _sun_aura: PointLight2D = $SunAura
@onready var _held_item: Sprite2D = $HeldItem

const HURT_DURATION := 0.4
const KNOCKBACK_VX := 67.0
const KNOCKBACK_VY := -135.0
const SHAKE_MAX_OFFSET := 4.0
const SHAKE_DECAY := 20.0

# Light2D 配置: PlayerAura 常亮小光圈, SunAura 头顶天空时大日光 (0.3s lerp)
const PLAYER_AURA_TEX_SIZE := 48      # TILE_SIZE 16→12 后缩 0.75 (光圈跟世界比例同)
const SUN_AURA_TEX_SIZE := 300        # 同上
const SUN_ENERGY_ON := 1.5
const SUN_ENERGY_OFF := 0.0
const SUN_FADE_TIME := 0.3

var _coyote_timer: float = 0.0
# 下平台: 按 S/Down 0.3s 内不撞 bit 2 (木平台), 落下
const DROP_THROUGH_DURATION := 0.3
var _drop_through_t: float = 0.0
var _facing_right: bool = true
var _was_on_floor: bool = true
var _previous_vy: float = 0.0
var _walk_step_timer: float = 0.0
var _hurt_timer: float = 0.0
var _shake_amount: float = 0.0
# 节流: 音乐场景每 0.5s 检测一次, 日光每 0.1s 检测一次 (节省 chunk_manager 查询)
const _MUSIC_INTERVAL := 0.5
const _SUN_INTERVAL := 0.1
var _music_timer: float = 0.0
var _sun_timer: float = 0.0
var _cached_chunk_manager = null   # 第一次 _process 查到后缓存, 避免反复 get_tree 查 group

# 钩爪状态: 持 grappling_hook 时右键发射. 状态机:
# - flying: 钩头沿 dir 飞 (HOOK_FLY_SPEED). 撞实心 tile → active. 飞超 max_dist → 释放.
# - active: 玩家被匀速拉向锚点. 距锚 < HOOK_RELEASE_DIST 自动脱; jump 中断.
const HOOK_MAX_DIST_TILES := 15           # 最远射程 15 tile
const HOOK_FLY_SPEED := 360.0             # 钩头飞行速度 px/s (比拉拽快, 才看得清钩)
const HOOK_PULL_SPEED := 210.0            # 拉过去的速度 px/s
const HOOK_RELEASE_DIST := 7.5           # 距锚点 < 这个值就脱钩 (避免抖)
var _hook_active: bool = false
var _hook_anchor: Vector2 = Vector2.ZERO
var _hook_line: Line2D = null
# 飞行阶段
var _hook_flying: bool = false
var _hook_tip: Vector2 = Vector2.ZERO
var _hook_dir: Vector2 = Vector2.ZERO
var _hook_origin: Vector2 = Vector2.ZERO
var _hook_head: Sprite2D = null


func _ready() -> void:
	sprite.sprite_frames = ArtCache.player_frames
	sprite.play("idle")
	add_to_group("player")
	# 连受击信号
	var hp: Node = get_node_or_null("PlayerHealth")
	if hp != null and hp.has_signal("damaged"):
		hp.damaged.connect(_on_damaged)
	# 光源纹理: 两个尺寸 (玩家身光 + 大日光)
	_player_aura.texture = ArtCache.radial_gradient(PLAYER_AURA_TEX_SIZE)
	_sun_aura.texture = ArtCache.radial_gradient(SUN_AURA_TEX_SIZE)
	# 手持物品: 绑定 inventory, 之后 hotbar 切换会自动刷新 sprite
	var pinv: Node = get_node_or_null("PlayerInventory")
	if pinv != null and _held_item != null:
		_held_item.bind_inventory(pinv)


func _process(delta: float) -> void:
	_sun_timer -= delta
	if _sun_timer <= 0.0:
		_sun_timer = _SUN_INTERVAL
		_update_sun_aura(_SUN_INTERVAL)  # 用 interval 当作 dt, lerp 系数等效
	_music_timer -= delta
	if _music_timer <= 0.0:
		_music_timer = _MUSIC_INTERVAL
		_update_music_context()
	# 联机: 每 0.1s 把本地位置 broadcast 给对方
	if NetworkManager != null and NetworkManager.connected():
		var anim_name: String = sprite.animation if sprite != null else "idle"
		var facing_int: int = 1 if _facing_right else -1
		NetworkManager.tick_send_player_pos(delta, global_position.x, global_position.y, facing_int, anim_name)


# SunAura 跟随 SkyLightGrid: 玩家头顶有天空 → 启用大日光; 钻进洞穴 → 关掉。0.3s lerp 避免硬切。
func _update_sun_aura(delta: float) -> void:
	var tile_x: int = int(floor(global_position.x / TILE_SIZE))
	var tile_y: int = int(floor(global_position.y / TILE_SIZE))
	var exposed: bool = SkyLightGrid.is_sky_exposed(tile_x, tile_y)
	var target: float = SUN_ENERGY_ON if exposed else SUN_ENERGY_OFF
	var t: float = clamp(delta / SUN_FADE_TIME, 0.0, 1.0)
	_sun_aura.energy = lerp(_sun_aura.energy, target, t)


# 背景音乐场景检测:
# cave 条件 (满足一个就播洞穴音乐):
#   1) 玩家所在格背后有墙 (= 自然矿洞内)
#   2) 玩家深度 (= y_tile - 原始 surf) > CAVE_DEPTH_THRESHOLD
#      用 chunk.surfaces[lx] 取原始地表, 跟玩家挖没挖无关 — "顶上方块挖掉也算"
# 否则按白天/夜晚分.
func _update_music_context() -> void:
	var tile_x: int = int(floor(global_position.x / TILE_SIZE))
	var tile_y: int = int(floor(global_position.y / TILE_SIZE))
	var ctx: String
	if _is_player_underground(tile_x, tile_y):
		ctx = "cave"
	elif TimeOfDay.is_night():
		ctx = "night"
	else:
		ctx = "day"
	MusicBank.set_context(ctx)


# 缓存 chunk_manager 引用 (从 World 找一次, 避免每帧 get_tree 群组查询)
func _get_chunk_manager():
	if _cached_chunk_manager != null:
		return _cached_chunk_manager
	var terrain: Node = get_tree().get_first_node_in_group("terrain_layer")
	if terrain == null:
		return null
	var world: Node = terrain.get_parent()
	if world == null:
		return null
	_cached_chunk_manager = world.get("chunk_manager")
	return _cached_chunk_manager


static func _is_water_tile(tid: int) -> bool:
	return tid == Tiles.WATER or tid == Tiles.WATER_L1 \
			or tid == Tiles.WATER_L2 or tid == Tiles.WATER_L3


# 玩家腰部是否在水里 (= 在游泳)
func _is_in_water() -> bool:
	var cm = _get_chunk_manager()
	if cm == null:
		return false
	var tx: int = int(floor(global_position.x / float(TILE_SIZE)))
	var ty: int = int(floor((global_position.y + float(PLAYER_WAIST_OFFSET)) / float(TILE_SIZE)))
	return _is_water_tile(cm.get_tile(tx, ty))


# 玩家身体 (腰或胸) 是否在绳子 tile 内
func _is_on_rope() -> bool:
	var cm = _get_chunk_manager()
	if cm == null:
		return false
	var tx: int = int(floor(global_position.x / float(TILE_SIZE)))
	# 脚 + 腰 + 头 3 个 y 任何一个在 rope tile 上就算抓住
	for off_y in [-2.0, float(PLAYER_WAIST_OFFSET), float(PLAYER_HEAD_OFFSET)]:
		var ty: int = int(floor((global_position.y + off_y) / float(TILE_SIZE)))
		if cm.get_tile(tx, ty) == Tiles.ROPE:
			return true
	return false


# 头部是否露出水面 (用于"跳上岸": 头出水可走普通跳跃, 强度够蹬上岸)
func _is_head_above_water() -> bool:
	var cm = _get_chunk_manager()
	if cm == null:
		return true
	var tx: int = int(floor(global_position.x / float(TILE_SIZE)))
	var ty: int = int(floor((global_position.y + float(PLAYER_HEAD_OFFSET)) / float(TILE_SIZE)))
	return not _is_water_tile(cm.get_tile(tx, ty))


func _is_player_underground(tile_x: int, tile_y: int) -> bool:
	var cm = _get_chunk_manager()
	if cm == null:
		return false
	# 条件 1: 自然矿洞 (有墙背景)
	if cm.get_wall(tile_x, tile_y) != Tiles.AIR:
		return true
	# 条件 2: 深度 > 10 (用原始 surf, 不被玩家挖掉影响)
	var chunk_x: int = Chunk.chunk_x_of(tile_x)
	var local_x: int = Chunk.local_x_of(tile_x)
	var ch = cm.get_chunk(chunk_x)
	if ch == null:
		return false
	if not ("surfaces" in ch) or ch.surfaces.size() <= local_x:
		return false
	var surf: int = ch.surfaces[local_x]
	return (tile_y - surf) > CAVE_DEPTH_THRESHOLD


# 公共接口: 朝向 (+1 右, -1 左)
func facing_dir() -> int:
	return 1 if _facing_right else -1


# 背包/合成/箱子 任意一个打开 → block 玩家输入
func _is_inventory_ui_open() -> bool:
	var c: Node = get_tree().get_first_node_in_group("crafting_panel")
	var ch: Node = get_tree().get_first_node_in_group("chest_panel")
	if c != null and c.has_method("is_open") and c.is_open():
		return true
	if ch != null and ch.has_method("is_open") and ch.is_open():
		return true
	return false


func _on_damaged(_amount: int, source_pos: Vector2) -> void:
	_hurt_timer = HURT_DURATION
	# 击退: 远离 source
	var dx: float = global_position.x - source_pos.x
	var kb_dir: float = signf(dx) if abs(dx) > 0.1 else 1.0
	velocity.x = kb_dir * KNOCKBACK_VX
	velocity.y = KNOCKBACK_VY


func _physics_process(delta: float) -> void:
	# 背包/合成/箱子 UI 打开时: 玩家停止 input, 只保留重力 (用户要求)
	if _is_inventory_ui_open():
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
		move_and_slide()
		if sprite.animation != "idle":
			sprite.play("idle")
		_was_on_floor = is_on_floor()
		_previous_vy = velocity.y
		return
	# 钩爪拉拽中: 跳过普通物理, 直接朝锚点匀速冲过去
	if _hook_active:
		_update_hook_pull(delta)
		return
	# 钩头飞行中: 玩家继续受重力, 钩头独立前进 + 撞墙检测
	if _hook_flying:
		_update_hook_flying(delta)
		return
	# 受击 lockout: 保留击退速度, 玩家暂失输入控制
	if _hurt_timer > 0.0:
		_hurt_timer = max(0.0, _hurt_timer - delta)
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		else:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		move_and_slide()
		if sprite.animation != "hurt":
			sprite.play("hurt")
		_was_on_floor = is_on_floor()
		_previous_vy = velocity.y
		return

	var dir := Input.get_axis("move_left", "move_right")
	# 泡水里走得慢一半 + sprite 偏蓝
	var in_water: bool = _is_in_water()
	var on_rope: bool = _is_on_rope() and not is_on_floor()
	var speed_mul: float = 0.5 if in_water else 1.0
	velocity.x = dir * SPEED * speed_mul
	sprite.modulate = Color(0.7, 0.85, 1.15) if in_water else Color.WHITE

	var on_floor_now := is_on_floor()

	# 重力 + 游泳 + 绳子. 绳子优先于普通重力.
	var did_jump := false
	if on_rope:
		# 抓绳子: 无重力, jump(W/space) 上爬, S 下爬, 否则悬停
		var up: bool = Input.is_action_pressed("jump")
		var down: bool = Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
		if up and not down:
			velocity.y = -ROPE_CLIMB_SPEED
		elif down and not up:
			velocity.y = ROPE_CLIMB_SPEED
		else:
			velocity.y = 0.0
	elif in_water:
		# 水里物理: 慢慢沉, 按 jump 上浮 (持续按住能游上去)
		velocity.y += SWIM_GRAVITY * delta
		if velocity.y > SWIM_MAX_SINK:
			velocity.y = SWIM_MAX_SINK
		# 头出水时按 jump 走普通跳跃 (强力, 能蹬上岸); 头在水里持续按走弱上浮
		if Input.is_action_just_pressed("jump") and _is_head_above_water():
			velocity.y = JUMP_VELOCITY
			did_jump = true
			SfxBank.play("jump", 0.08)
		elif Input.is_action_pressed("jump"):
			velocity.y = SWIM_UP_SPEED
	else:
		if not on_floor_now:
			velocity.y += GRAVITY * delta
			_coyote_timer = max(0.0, _coyote_timer - delta)
		else:
			_coyote_timer = COYOTE_TIME
		# 跳跃 (仅在陆地, 水里用上浮代替)
		if Input.is_action_just_pressed("jump") and _coyote_timer > 0.0:
			velocity.y = JUMP_VELOCITY
			_coyote_timer = 0.0
			did_jump = true
			SfxBank.play("jump", 0.08)
		# 下平台: 按 S/Down 时关掉 bit 2 (木平台) 0.3s, 玩家从平台落下
		if on_floor_now and (Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)):
			_drop_through_t = DROP_THROUGH_DURATION
	# 平台 mask 切换 (放最外层, 任何状态下 timer 都能跑完)
	if _drop_through_t > 0.0:
		_drop_through_t = max(0.0, _drop_through_t - delta)
		collision_mask = 1   # 只撞 bit 0 (实心), 跳过 bit 2 (平台)
	elif collision_mask != 5:
		collision_mask = 5   # 恢复 bit 0+2

	# 记录跳前 vy 给落地用
	var pre_move_vy := velocity.y

	move_and_slide()

	var on_floor_after := is_on_floor()

	# 跳起瞬间扬灰
	if did_jump:
		Effects.spawn_jump_dust(global_position)

	# 落地瞬间扬灰：本帧由空中变地面 + 之前的 vy 够大
	if not _was_on_floor and on_floor_after and _previous_vy > LAND_VY_THRESHOLD:
		Effects.spawn_land_dust(global_position)
		SfxBank.play("land", 0.10, -3.0)

	# 走路 puff：在地 + 有移动
	if on_floor_after and abs(dir) > 0.01:
		_walk_step_timer -= delta
		if _walk_step_timer <= 0:
			var facing_sign := 1.0 if _facing_right else -1.0
			Effects.spawn_walk_puff(global_position + Vector2(-facing_sign * 4, 0))
			_walk_step_timer = WALK_PUFF_INTERVAL
	else:
		_walk_step_timer = 0.0

	_was_on_floor = on_floor_after
	_previous_vy = pre_move_vy

	# 相机震屏
	var camera: Camera2D = get_node_or_null("Camera2D")
	if camera != null:
		if _shake_amount > 0.01:
			camera.offset = Vector2(randf_range(-_shake_amount, _shake_amount), randf_range(-_shake_amount, _shake_amount))
			_shake_amount = max(0.0, _shake_amount - SHAKE_DECAY * delta)
		else:
			camera.offset = Vector2.ZERO

	# 朝向
	if dir > 0.01:
		_facing_right = true
	elif dir < -0.01:
		_facing_right = false
	sprite.flip_h = not _facing_right
	if _held_item != null:
		_held_item.set_facing(_facing_right)

	# 动画状态机
	_update_animation(dir, on_floor_after)
	_update_workbench_prompt()


func _update_animation(dir: float, on_floor: bool) -> void:
	var next_anim: String
	if not on_floor:
		next_anim = "jump" if velocity.y < 0.0 else "fall"
	elif abs(dir) > 0.01:
		next_anim = "walk"
	else:
		next_anim = "idle"
	if sprite.animation != next_anim:
		sprite.play(next_anim)


func _update_workbench_prompt() -> void:
	var fp: CanvasLayer = get_tree().get_first_node_in_group("floating_prompt")
	if fp == null:
		return
	var terrain := get_tree().get_first_node_in_group("terrain_layer") as TileMapLayer
	if terrain == null:
		return
	var foot := global_position
	var pt := Vector2i(int(floor(foot.x / float(TILE_SIZE))), int(floor(foot.y / float(TILE_SIZE))))
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var coord := pt + Vector2i(dx, dy)
			if terrain.get_cell_source_id(coord) == Tiles.WORKBENCH:
				fp.show_prompt(Vector2(coord.x * TILE_SIZE + TILE_SIZE / 2, coord.y * TILE_SIZE - TILE_SIZE / 4), "按 E")
				return
	# 没找到
	if fp.is_showing():
		fp.hide_prompt()


func shake(amount: float = 4.0) -> void:
	_shake_amount = clampf(amount, 0.0, SHAKE_MAX_OFFSET)


# ===== 钩爪 (grappling_hook) =====

# 由 player_action 在右键 + 持钩爪时调. target_world = 鼠标对应的世界坐标.
# 进入飞行阶段: 钩头从玩家中心朝鼠标方向飞, 撞实心 tile 锚定 + 切到拉拽.
# 已在飞行 / 已锚定时再调 = 立刻释放 (玩家中断).
func fire_grappling_hook(target_world: Vector2) -> void:
	if _hook_active or _hook_flying:
		_release_hook()
		return
	var origin: Vector2 = global_position
	var dir: Vector2 = (target_world - origin).normalized()
	if dir.length() < 0.01:
		return
	_hook_origin = origin
	_hook_dir = dir
	_hook_tip = origin
	_hook_flying = true
	_spawn_hook_line(origin, origin)
	_spawn_hook_head(origin, dir)
	SfxBank.play("swing", 0.10)   # 钩出: 甩绳感


func _spawn_hook_line(p_from: Vector2, p_to: Vector2) -> void:
	if _hook_line != null and is_instance_valid(_hook_line):
		_hook_line.queue_free()
	_hook_line = Line2D.new()
	_hook_line.width = 1.0
	_hook_line.default_color = Color(0.55, 0.4, 0.25)   # 麻绳棕
	_hook_line.add_point(p_from)
	_hook_line.add_point(p_to)
	# 加到 world (effects_root) 上方, top-level 避免被玩家 transform 跟着动
	_hook_line.top_level = true
	var root: Node = get_tree().get_first_node_in_group("effects_root")
	if root == null:
		root = get_parent()
	if root != null:
		root.add_child(_hook_line)


# 钩头 sprite: 小钩子图, rotation 跟飞行方向; 撞墙后停在锚点
func _spawn_hook_head(p_pos: Vector2, p_dir: Vector2) -> void:
	if _hook_head != null and is_instance_valid(_hook_head):
		_hook_head.queue_free()
	_hook_head = Sprite2D.new()
	_hook_head.texture = ItemsArt.get_hook_head_texture()
	_hook_head.centered = true
	_hook_head.top_level = true
	_hook_head.global_position = p_pos
	_hook_head.rotation = p_dir.angle()
	var root: Node = get_tree().get_first_node_in_group("effects_root")
	if root == null:
		root = get_parent()
	if root != null:
		root.add_child(_hook_head)


func _update_hook_pull(delta: float) -> void:
	# 玩家按 jump 主动脱钩
	if Input.is_action_just_pressed("jump"):
		_release_hook()
		# 给个小跳, 否则刚脱钩马上重力跌
		velocity = Vector2(velocity.x, JUMP_VELOCITY * 0.8)
		return
	var to_anchor: Vector2 = _hook_anchor - global_position
	var dist: float = to_anchor.length()
	if dist < HOOK_RELEASE_DIST:
		# 到了 → 脱钩, 停一下让玩家能继续跳
		_release_hook()
		velocity = Vector2.ZERO
		SfxBank.play("land", 0.10)   # 拉到了的"咚"
		return
	# 朝锚点匀速冲, move_and_slide 仍处理碰撞 (撞墙不穿)
	velocity = to_anchor.normalized() * HOOK_PULL_SPEED
	move_and_slide()
	if _hook_line != null and is_instance_valid(_hook_line):
		_hook_line.set_point_position(0, global_position)


# 钩头飞行阶段每帧: 推 _hook_tip + 撞墙检测 + 飞超 max_dist 释放.
# 撞实心 → 锁定锚点, 切换到 active (玩家被拉过去).
func _update_hook_flying(delta: float) -> void:
	# 玩家按 jump 主动取消
	if Input.is_action_just_pressed("jump"):
		_release_hook()
		return
	# 普通重力照常吃 (玩家飞钩时还得跌)
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	move_and_slide()
	# 推进钩头
	_hook_tip += _hook_dir * HOOK_FLY_SPEED * delta
	# 飞超 max_dist → miss, 释放
	if _hook_tip.distance_to(_hook_origin) > HOOK_MAX_DIST_TILES * TILE_SIZE:
		_release_hook()
		return
	# 撞实心 tile?
	var cm = _chunk_manager()
	if cm != null:
		var tx: int = int(floor(_hook_tip.x / TILE_SIZE))
		var ty: int = int(floor(_hook_tip.y / TILE_SIZE))
		var tid: int = cm.get_tile(tx, ty)
		if tid != -1 and Tiles.is_solid(tid):
			# 锚到 tile 中心 → 切换到 active
			_hook_anchor = Vector2(tx * TILE_SIZE + TILE_SIZE / 2.0, ty * TILE_SIZE + TILE_SIZE / 2.0)
			_hook_flying = false
			_hook_active = true
			# 钩头停在锚点
			if _hook_head != null and is_instance_valid(_hook_head):
				_hook_head.global_position = _hook_anchor
			# 绳子尾端也跟到锚点
			if _hook_line != null and is_instance_valid(_hook_line):
				_hook_line.set_point_position(1, _hook_anchor)
			SfxBank.play("place", 0.15)   # 钩中: 短金属敲击感
			return
	# 没撞 → 更新视觉
	if _hook_head != null and is_instance_valid(_hook_head):
		_hook_head.global_position = _hook_tip
	if _hook_line != null and is_instance_valid(_hook_line):
		_hook_line.set_point_position(0, global_position)
		_hook_line.set_point_position(1, _hook_tip)


func _release_hook() -> void:
	_hook_active = false
	_hook_flying = false
	if _hook_line != null and is_instance_valid(_hook_line):
		_hook_line.queue_free()
	_hook_line = null
	if _hook_head != null and is_instance_valid(_hook_head):
		_hook_head.queue_free()
	_hook_head = null


func _chunk_manager():
	if _cached_chunk_manager != null and is_instance_valid(_cached_chunk_manager):
		return _cached_chunk_manager
	var world: Node = get_tree().get_first_node_in_group("world")
	if world == null:
		return null
	_cached_chunk_manager = world.get("chunk_manager")
	return _cached_chunk_manager
