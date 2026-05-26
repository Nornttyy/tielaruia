# 玩家控制器：左右移动、跳跃、重力、AnimatedSprite2D 动画切换。
# 朝向通过 sprite.flip_h 处理；面向右默认。
extends CharacterBody2D

const Chunk = preload("res://scripts/world/chunk.gd")
const CAVE_DEPTH_THRESHOLD := 10   # 玩家离原始地表 >10 格才算"地下" (即使顶上方块挖掉了)

const SPEED := 140.0
const JUMP_VELOCITY := -320.0
const GRAVITY := 900.0
const COYOTE_TIME := 0.10
const LAND_VY_THRESHOLD := 200.0    # 落地时 vy 超此值才扬大灰
const WALK_PUFF_INTERVAL := 0.3     # 走路每 0.3s 一次 puff
const TILE_SIZE := 16
# 游泳物理: 水里重力 ~22%, 按 Space/W 持续上浮.
const SWIM_GRAVITY := 200.0         # 水里重力 (vs GRAVITY 900 → 慢慢沉)
const SWIM_UP_SPEED := -110.0       # 按 jump 上浮速度 (vs JUMP_VELOCITY -320 → 弱跳)
const SWIM_MAX_SINK := 180.0        # 最大下沉速度 (浮力封顶)
# Auto-step: 走着碰 1 格高台阶, 不按跳自动爬上去 (Terraria 风).
# 17 = TILE_SIZE+1 (Godot test_move 有 0.08px safe_margin, 多抬 1 px 避免误判).
const AUTO_STEP_LIFT := TILE_SIZE + 1
const AUTO_STEP_DURATION := 0.08    # tween 时长; 比动物快 (玩家反应需要)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _player_aura: PointLight2D = $PlayerAura
@onready var _sun_aura: PointLight2D = $SunAura
@onready var _held_item: Sprite2D = $HeldItem

const HURT_DURATION := 0.4
const KNOCKBACK_VX := 90.0
const KNOCKBACK_VY := -180.0
const SHAKE_MAX_OFFSET := 4.0
const SHAKE_DECAY := 20.0

# Light2D 配置: PlayerAura 常亮小光圈, SunAura 头顶天空时大日光 (0.3s lerp)
const PLAYER_AURA_TEX_SIZE := 64
const SUN_AURA_TEX_SIZE := 400
const SUN_ENERGY_ON := 1.5
const SUN_ENERGY_OFF := 0.0
const SUN_FADE_TIME := 0.3

var _coyote_timer: float = 0.0
var _facing_right: bool = true
var _was_on_floor: bool = true
var _previous_vy: float = 0.0
var _walk_step_timer: float = 0.0
var _hurt_timer: float = 0.0
var _shake_amount: float = 0.0
var _stepping: bool = false   # auto-step tween 进行中, 物理暂停
# 节流: 音乐场景每 0.5s 检测一次, 日光每 0.1s 检测一次 (节省 chunk_manager 查询)
const _MUSIC_INTERVAL := 0.5
const _SUN_INTERVAL := 0.1
var _music_timer: float = 0.0
var _sun_timer: float = 0.0
var _cached_chunk_manager = null   # 第一次 _process 查到后缓存, 避免反复 get_tree 查 group

# 钩爪状态: 持 grappling_hook 时右键发射, 锁定到第一个实心方块, 拉玩家过去
const HOOK_MAX_DIST_TILES := 15           # 最远射程 15 tile
const HOOK_PULL_SPEED := 280.0            # 拉过去的速度 px/s
const HOOK_RELEASE_DIST := 10.0           # 距锚点 < 这个值就脱钩 (避免抖)
var _hook_active: bool = false
var _hook_anchor: Vector2 = Vector2.ZERO
var _hook_line: Line2D = null


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
	var tx: int = int(floor(global_position.x / 16.0))
	var ty: int = int(floor((global_position.y - 11.0) / 16.0))
	return _is_water_tile(cm.get_tile(tx, ty))


# 头部是否露出水面 (用于"跳上岸": 头出水可走普通跳跃, 强度够蹬上岸)
func _is_head_above_water() -> bool:
	var cm = _get_chunk_manager()
	if cm == null:
		return true
	var tx: int = int(floor(global_position.x / 16.0))
	var ty: int = int(floor((global_position.y - 22.0) / 16.0))
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


# Auto-step: 撞 1 格台阶时 tween 上去, 不需要按跳. 返回 true 表示触发了 step.
# 跟 animal_base._try_auto_step 同套路: probe 上方空气 + 下方有平台 → tween 上去.
func _try_auto_step(dir: float) -> bool:
	var step_x: float = signf(dir) * float(TILE_SIZE)
	var lift: float = float(AUTO_STEP_LIFT)
	var probe := global_transform.translated(Vector2(step_x, -lift))
	# probe 位置不该有碰撞 (头顶 1 格空气)
	if test_move(probe, Vector2.ZERO):
		return false
	# probe 往下 lift 距离应该被挡住 (台阶顶有平台落脚)
	if not test_move(probe, Vector2(0, lift)):
		return false
	var target := global_position + Vector2(step_x, -float(TILE_SIZE))
	_stepping = true
	velocity = Vector2.ZERO
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "global_position", target, AUTO_STEP_DURATION)
	tw.tween_callback(_on_auto_step_done)
	return true


func _on_auto_step_done() -> void:
	_stepping = false


func _on_damaged(_amount: int, source_pos: Vector2) -> void:
	_hurt_timer = HURT_DURATION
	# 击退: 远离 source
	var dx: float = global_position.x - source_pos.x
	var kb_dir: float = signf(dx) if abs(dx) > 0.1 else 1.0
	velocity.x = kb_dir * KNOCKBACK_VX
	velocity.y = KNOCKBACK_VY


func _physics_process(delta: float) -> void:
	# auto-step tween 期间: 暂停物理 (tween 接管 position)
	if _stepping:
		return
	# 钩爪拉拽中: 跳过普通物理, 直接朝锚点匀速冲过去
	if _hook_active:
		_update_hook_pull(delta)
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
	var speed_mul: float = 0.5 if in_water else 1.0
	velocity.x = dir * SPEED * speed_mul
	sprite.modulate = Color(0.7, 0.85, 1.15) if in_water else Color.WHITE

	var on_floor_now := is_on_floor()

	# 重力 + 游泳: 在水里用 SWIM_GRAVITY (弱), 按 jump 持续上浮.
	# 不在水里则正常重力 + 单次跳跃.
	var did_jump := false
	if in_water:
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

	# 记录跳前 vy 给落地用
	var pre_move_vy := velocity.y

	move_and_slide()

	# Auto-step: 走墙 + 在地 + 有方向 → 试爬 1 格台阶
	# 不在水里 (水里有上浮代替), 不在跳起的瞬间 (会跟跳跃冲突)
	if not in_water and not did_jump \
			and is_on_wall() and is_on_floor() and abs(dir) > 0.01:
		_try_auto_step(dir)

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
	var pt := Vector2i(int(floor(foot.x / 16.0)), int(floor(foot.y / 16.0)))
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var coord := pt + Vector2i(dx, dy)
			if terrain.get_cell_source_id(coord) == Tiles.WORKBENCH:
				fp.show_prompt(Vector2(coord.x * 16 + 8, coord.y * 16 - 4), "按 E")
				return
	# 没找到
	if fp.is_showing():
		fp.hide_prompt()


func shake(amount: float = 4.0) -> void:
	_shake_amount = clampf(amount, 0.0, SHAKE_MAX_OFFSET)


# ===== 钩爪 (grappling_hook) =====

# 由 player_action 在右键 + 持钩爪时调. target_world = 鼠标对应的世界坐标.
# 射线从玩家中心出发, 沿方向每 4 px 步进, 找到第一个实心 tile 当锚点.
func fire_grappling_hook(target_world: Vector2) -> void:
	if _hook_active:
		_release_hook()
		return
	var cm = _chunk_manager()
	if cm == null:
		return
	var origin: Vector2 = global_position
	var dir: Vector2 = (target_world - origin).normalized()
	if dir.length() < 0.01:
		return
	var max_dist: float = HOOK_MAX_DIST_TILES * TILE_SIZE
	var step: float = 4.0
	var t: float = 0.0
	while t < max_dist:
		t += step
		var p: Vector2 = origin + dir * t
		var tx: int = int(floor(p.x / TILE_SIZE))
		var ty: int = int(floor(p.y / TILE_SIZE))
		var tid: int = cm.get_tile(tx, ty)
		if tid != -1 and Tiles.is_solid(tid):
			# 锚到 tile 中心
			_hook_anchor = Vector2(tx * TILE_SIZE + TILE_SIZE / 2.0, ty * TILE_SIZE + TILE_SIZE / 2.0)
			_hook_active = true
			_spawn_hook_line()
			SfxBank.play("hurt", 0.20)   # 临时复用音效 (没专门钩爪音)
			return
	# 没打到任何 tile → 不发钩


func _spawn_hook_line() -> void:
	if _hook_line != null and is_instance_valid(_hook_line):
		_hook_line.queue_free()
	_hook_line = Line2D.new()
	_hook_line.width = 1.5
	_hook_line.default_color = Color(0.55, 0.4, 0.25)   # 麻绳棕
	_hook_line.add_point(global_position)
	_hook_line.add_point(_hook_anchor)
	# 加到 world (effects_root) 上方, top-level 避免被玩家 transform 跟着动
	_hook_line.top_level = true
	var root: Node = get_tree().get_first_node_in_group("effects_root")
	if root == null:
		root = get_parent()
	if root != null:
		root.add_child(_hook_line)


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
		return
	# 朝锚点匀速冲, move_and_slide 仍处理碰撞 (撞墙不穿)
	velocity = to_anchor.normalized() * HOOK_PULL_SPEED
	move_and_slide()
	if _hook_line != null and is_instance_valid(_hook_line):
		_hook_line.set_point_position(0, global_position)


func _release_hook() -> void:
	_hook_active = false
	if _hook_line != null and is_instance_valid(_hook_line):
		_hook_line.queue_free()
	_hook_line = null


func _chunk_manager():
	if _cached_chunk_manager != null and is_instance_valid(_cached_chunk_manager):
		return _cached_chunk_manager
	var world: Node = get_tree().get_first_node_in_group("world")
	if world == null:
		return null
	_cached_chunk_manager = world.get("chunk_manager")
	return _cached_chunk_manager
