# 玩家手枪子弹投射物. Area2D, 笔直飞 (无重力, 跟箭的抛物线相反).
# 命中怪 → 造成伤害 + 销毁. 命中实心方块 → 销毁. 1.2s 自销.
# 跟 arrow.gd 同结构, 但: 无重力 / 更快 (560 vs 260) / 寿命更短.
extends Area2D

const TILE_SIZE := 12
const SPEED := 560.0            # 比箭(260)快一倍多 → 几乎点哪打哪
const LIFETIME_SEC := 1.2       # 飞得快, 不用活太久
const BASE_DAMAGE := 9

var velocity: Vector2 = Vector2.ZERO
var damage: int = BASE_DAMAGE   # 由枪 tier 控制, 外部传入
var _life_t: float = 0.0
var _lifetime: float = LIFETIME_SEC   # 可被 opts 覆盖 (火焰喷射器很短 = 近距离)
var _cached_chunk_manager = null
var _is_dead: bool = false
var _shooter: Node = null       # 谁射的 (玩家), 避免自伤
# 特殊枪机制 (从 opts 读): 穿透 / 冰冻减速 / 外观.
var pierce: bool = false        # true=命中不消失, 继续飞穿过去 (激光枪)
var slow_factor: float = 0.0    # >0=命中给怪减速到此倍率 (冰冻枪)
var slow_dur: float = 0.0
var _visual: String = "bullet"  # bullet / laser / fire / ice / magic / poison → 选不同贴图
var _hit_ids: Dictionary = {}   # 穿透时记下已命中的怪, 同一只不重复打
# 魔法机制 (从 opts 读): 追踪 / 毒 / 连锁 / 反弹 / 重力
var homing: float = 0.0         # >0 = 每秒朝最近怪转向 homing 弧度 (追踪魔弹枪)
var dot_dps: int = 0            # >0 = 命中给怪上毒, 每秒掉 dot_dps 血 (毒液枪)
var dot_dur: float = 0.0
var chain: int = 0              # >0 = 命中时再电附近 chain 只怪 (闪电链枪)
var chain_radius: float = 60.0  # 连锁跳跃半径
var bounce: int = 0             # >0 = 撞墙反弹而不消失, 剩余次数 (星星炮/史莱姆枪)
var grav: float = 0.0           # >0 = 每帧下坠 (史莱姆枪弹丸抛物线弹跳)
# B 波法杖机制: 爆炸范围伤害 / 击飞
var explode_radius: float = 0.0 # >0 = 命中/撞墙时炸一圈, 半径内的怪都受 explode_dmg (爆裂火球/水之法杖)
var explode_dmg: int = 0        # 爆炸伤害 (0 → 用 damage)
var explode_on_land_only: bool = false  # true = 只在落地(撞实心)才炸, 空中穿过怪不炸 (水之法杖: 像水球, 砸地才溅)
var knockback: float = 140.0    # 击退力度 (狂风法杖调很大 = 弹飞)
var launch: bool = false        # true = 击退带上抛 (把怪打飞起来, 狂风法杖)
var _impact_color: Color = Color(0, 0, 0, 0)  # 大招牌特效的基色 (法杖/gun_impact 强力枪才设)
var _impact_fx: String = ""     # 大招牌特效形状 spark/gas/sparkle/gust/explosion/splash (空=不放)
var _fx_color: Color = Color8(255, 220, 140)  # 小命中特效基色 (所有弹都有: 打怪爆闪/打墙火星, 跟枪系色走)
var _trail: Line2D = null       # 法杖弹的发光拖尾 (top_level, 记录飞过的点)
var _glow: Sprite2D = null      # 法杖弹的发光光晕 (弹体后面一圈柔光)
const TRAIL_MAX_PTS := 12       # 拖尾最多记几个点 (越多越长)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


# speed=0 → 用默认 SPEED; opts 配特殊机制 (pierce/slow_factor/slow_dur/visual/lifetime).
func setup(start_pos: Vector2, target_pos: Vector2, dmg: int, shooter: Node, speed: float = 0.0, opts: Dictionary = {}) -> void:
	global_position = start_pos
	damage = dmg
	_shooter = shooter
	pierce = bool(opts.get("pierce", false))
	slow_factor = float(opts.get("slow_factor", 0.0))
	slow_dur = float(opts.get("slow_dur", 0.0))
	_visual = String(opts.get("visual", "bullet"))
	homing = float(opts.get("homing", 0.0))
	dot_dps = int(opts.get("dot_dps", 0))
	dot_dur = float(opts.get("dot_dur", 0.0))
	chain = int(opts.get("chain", 0))
	chain_radius = float(opts.get("chain_radius", 60.0))
	bounce = int(opts.get("bounce", 0))
	grav = float(opts.get("gravity", 0.0))
	explode_radius = float(opts.get("explode_radius", 0.0))
	explode_dmg = int(opts.get("explode_dmg", 0))
	explode_on_land_only = bool(opts.get("explode_on_land_only", false))
	knockback = float(opts.get("knockback", 140.0))
	launch = bool(opts.get("launch", false))
	_impact_color = opts.get("impact_color", Color(0, 0, 0, 0))
	_impact_fx = String(opts.get("impact_fx", ""))
	_fx_color = opts.get("fx_color", Color8(255, 220, 140))
	var lt: float = float(opts.get("lifetime", 0.0))
	if lt > 0.0:
		_lifetime = lt
	var dir: Vector2 = (target_pos - start_pos).normalized() if start_pos.distance_to(target_pos) > 0.01 else Vector2.RIGHT
	var spd: float = speed if speed > 0.0 else SPEED
	velocity = dir * spd
	rotation = velocity.angle()   # sprite 朝飞行方向 (子弹直线, 整程不变向)
	_apply_visual()   # setup 在 add_child 后调 → sprite 已就绪, 换成对应贴图
	# 法杖弹 (impact_fx 有值): 弹体放大 + 加发光光晕 + 拖尾, 让它"更像魔法弹" (枪弹不加)
	if _impact_fx != "" and _impact_color.a > 0.0:
		_make_staff_visuals(_impact_color)


# 按 _visual 换投射物贴图 (激光/火焰/冰用现成的发光弹贴图, 普通用子弹).
func _apply_visual() -> void:
	if sprite == null or _visual == "bullet":
		return
	var frames: SpriteFrames = null
	match _visual:
		"laser":  frames = ArtCache.laser_proj_frames
		"fire":   frames = ArtCache.fireball_frames      # 火焰喷射器复用火球粒子
		"ice":    frames = ArtCache.spell_frames_ice     # 冰冻枪复用蓝色冰弹
		"magic":     frames = ArtCache.magic_proj_frames    # 追踪魔弹枪: 紫色奥术弹
		"poison":    frames = ArtCache.spell_frames_nature  # 毒液枪复用绿色自然弹
		"lightning": frames = ArtCache.lightning_proj_frames # 闪电链枪: 黄电球
		"star":      frames = ArtCache.star_proj_frames      # 星星炮: 金色星
		"slimeblob": frames = ArtCache.slime_blob_proj_frames # 史莱姆枪: 绿果冻团
		"leaf":      frames = ArtCache.leaf_proj_frames       # 绿叶枪: 绿叶片
		"wind":      frames = ArtCache.wind_proj_frames       # 狂风法杖: 白青气流
	if frames == null:
		return
	sprite.sprite_frames = frames
	var names: PackedStringArray = frames.get_animation_names()
	if names.size() > 0:
		sprite.play(names[0])


# 法杖弹专属"重画": 弹体放大 1.5x + 身后一圈加色柔光 (additive) + 一条发光拖尾。
func _make_staff_visuals(color: Color) -> void:
	if sprite != null:
		sprite.scale = Vector2(1.5, 1.5)   # 弹体更大更显眼
	# 发光光晕: 柔光圆 + 叠加混合 (发光感), 放弹体后面
	var glow := Sprite2D.new()
	glow.texture = ArtCache.radial_gradient(20)
	glow.modulate = Color(color.r, color.g, color.b, 0.75)
	glow.scale = Vector2(1.6, 1.6)
	glow.z_index = -1
	var gmat := CanvasItemMaterial.new()
	gmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = gmat
	add_child(glow)
	_glow = glow
	# 拖尾: top_level Line2D 记飞过的点, 头粗尾细 + 头亮尾透明 (像彗星尾)
	var tr := Line2D.new()
	tr.top_level = true            # 不跟弹体旋转/位移, 点用世界坐标
	tr.width = 7.0
	tr.begin_cap_mode = Line2D.LINE_CAP_ROUND
	tr.end_cap_mode = Line2D.LINE_CAP_ROUND
	tr.joint_mode = Line2D.LINE_JOINT_ROUND
	var wc := Curve.new()
	wc.add_point(Vector2(0.0, 0.0))   # 尾 (旧点) 细
	wc.add_point(Vector2(1.0, 1.0))   # 头 (新点) 粗
	tr.width_curve = wc
	var grad := Gradient.new()
	grad.set_color(0, Color(color.r, color.g, color.b, 0.0))   # 尾透明
	grad.set_color(1, Color(color.r, color.g, color.b, 0.7))   # 头亮
	tr.gradient = grad
	var tmat := CanvasItemMaterial.new()
	tmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	tr.material = tmat
	add_child(tr)
	_trail = tr


# 每帧把当前位置塞进拖尾尾端, 超长就丢最旧的点 (尾巴跟着弹体走)
func _update_trail() -> void:
	if _trail == null:
		return
	_trail.add_point(global_position)
	while _trail.get_point_count() > TRAIL_MAX_PTS:
		_trail.remove_point(0)


const HIT_RADIUS_PX := 10.0   # 飞行线段到怪中心 ≤ 此值算击中 (大点更好打中, 不那么"擦边没伤害")

func _ready() -> void:
	sprite.sprite_frames = ArtCache.bullet_proj_frames
	sprite.play("fly")


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_life_t += delta
	if _life_t >= _lifetime:
		_destroy()
		return
	# 追踪: 每帧把速度方向朝最近的怪转 homing*delta 弧度 (保持速率不变)
	if homing > 0.0:
		var tgt: Node2D = _nearest_enemy()
		if tgt != null:
			var want: Vector2 = (tgt.global_position - global_position)
			if want.length() > 0.01:
				var cur_ang: float = velocity.angle()
				var new_ang: float = cur_ang + clampf(angle_difference(cur_ang, want.angle()), -homing * delta, homing * delta)
				velocity = Vector2(cos(new_ang), sin(new_ang)) * velocity.length()
				rotation = new_ang
	# 史莱姆枪弹丸: 重力下坠 → 抛物线 (普通子弹 grav=0 笔直飞)
	if grav > 0.0:
		velocity.y += grav * delta
	var next: Vector2 = global_position + velocity * delta
	var cm = _get_cm()
	if cm != null:
		var tx: int = int(floor(next.x / TILE_SIZE))
		var ty: int = int(floor(next.y / TILE_SIZE))
		if _solid_at(cm, tx, ty):
			var in_dir: Vector2 = velocity   # 撞墙前的飞行方向 (火星往反方向溅)
			if bounce > 0:
				# 反弹: 判断撞横墙还是地板/天花板, 翻对应速度分量, 不移进墙
				bounce -= 1
				var cx: int = int(floor(global_position.x / TILE_SIZE))
				var cy: int = int(floor(global_position.y / TILE_SIZE))
				var hit_h: bool = _solid_at(cm, tx, cy)
				var hit_v: bool = _solid_at(cm, cx, ty)
				if hit_h and not hit_v:
					velocity.x = -velocity.x
				elif hit_v and not hit_h:
					velocity.y = -velocity.y
				else:
					velocity = -velocity
				rotation = velocity.angle()
				# 弹墙火星: 每次反弹都闪一下 (看清在哪弹的)
				if Effects != null and Effects.has_method("spawn_bullet_impact"):
					Effects.spawn_bullet_impact(global_position, in_dir, _fx_color, "wallhit")
				return
			# 爆裂/水之: 撞墙也炸 (只伤怪, 不破方块)
			if explode_radius > 0.0:
				_explode(global_position)
			# 打到方块: 反弹火星特效 (所有枪都有, 看清子弹打哪了)
			if Effects != null and Effects.has_method("spawn_bullet_impact"):
				Effects.spawn_bullet_impact(global_position, in_dir, _fx_color, "wallhit")
			_destroy()
			return
	var prev_pos: Vector2 = global_position
	global_position = next
	_update_trail()   # 弹体走到哪, 拖尾跟到哪
	# 手动撞怪. 联机视觉副本 (is_remote) 不撞, 伤害由发起端 host 算.
	if not has_meta("is_remote"):
		_check_enemy_hit(prev_pos)


# from_pos = 这一帧移动前的位置. 用"线段(上一帧→这一帧)到怪的最近距离"判定,
# 而不是只看落点那一个点 — 否则子弹飞太快 (步长 > 命中半径) 会从怪身上跳过去不算命中.
func _check_enemy_hit(from_pos: Vector2) -> void:
	# 水之法杖: 只落地才炸 → 空中直接穿过怪, 不在半空命中/引爆 (用户要求: 像水球砸地才溅).
	if explode_on_land_only:
		return
	# 扫两组: slimes (敌对怪) + animals (牛羊猪 — 枪也该能打). 照 arrow.gd.
	for group in ["slimes", "animals"]:
		for enemy in get_tree().get_nodes_in_group(group):
			if enemy == _shooter or not is_instance_valid(enemy):
				continue
			if not enemy is Node2D:
				continue
			if _hit_ids.has(enemy.get_instance_id()):
				continue   # 穿透时: 这只已经打过, 不重复扣血
			# 大怪/Boss 给身子半径 (跟近战一致), 否则子弹只认中心一点, 从大身子飞过去不算命中
			var radius: float = enemy.melee_hit_radius() if enemy.has_method("melee_hit_radius") else 0.0
			if _seg_point_dist(from_pos, global_position, (enemy as Node2D).global_position) > HIT_RADIUS_PX + radius:
				continue
			_hit_ids[enemy.get_instance_id()] = true
			# 击退源位置: 沿飞行反方向退 32px, 让 (enemy - source).normalized 指向飞行方向.
			var src: Vector2 = global_position - velocity.normalized() * 32.0
			# 爆裂/水之: 命中即炸 (范围伤害), 不再单体打
			if explode_radius > 0.0:
				_explode(global_position)
				_destroy()
				return
			var kb_src: Vector2 = src
			if launch and enemy is Node2D:
				kb_src = (enemy as Node2D).global_position - (velocity.normalized() + Vector2(0, -1.2)).normalized() * 32.0
			# 打中怪: 放射爆闪特效 (所有枪都有, 颜色跟枪系走; 本地/远程怪都放 — 纯视觉)
			if Effects != null and Effects.has_method("spawn_bullet_impact"):
				Effects.spawn_bullet_impact(global_position, velocity, _fx_color, "hit")
			if enemy.has_meta("is_remote"):
				# 联机 client: 远程怪 host 权威, 发伤害给 host, 不本地打视觉副本
				if NetworkManager != null and NetworkManager.connected():
					var rid: int = int(enemy.get_meta("remote_id", 0))
					if rid != 0:
						NetworkManager.send_entity_damage(rid, damage, knockback, kb_src.x, kb_src.y)
			else:
				if enemy.has_method("take_damage"):
					enemy.take_damage(damage, kb_src, knockback)
				# 冰冻枪: 命中给怪减速 (本地权威端才挂; 联机对端 host 各管各的)
				if slow_factor > 0.0 and enemy.has_method("apply_slow"):
					enemy.apply_slow(slow_factor, slow_dur)
				# 毒液枪: 命中给怪上毒 (持续掉血)
				if dot_dps > 0 and enemy.has_method("apply_poison"):
					enemy.apply_poison(dot_dps, dot_dur)
				# 闪电链枪: 命中后再电附近几只
				if chain > 0:
					_do_chain(enemy as Node2D, src)
			if not pierce:
				_destroy()
				return
			# pierce (激光): 不销毁, 继续飞, 可同帧/后续帧再命中别的怪
	# PvP: 对战房里子弹也能打到远程玩家 (本地判命中 → 发伤害给对方, 对方扣自己血). 照 arrow.gd.
	if NetworkManager != null and NetworkManager.combat_enabled():
		for s in get_tree().get_nodes_in_group("remote_player"):
			var rp := s as Node2D
			if rp == null or not is_instance_valid(rp):
				continue
			if _hit_ids.has(rp.get_instance_id()):
				continue   # 穿透: 同一个玩家不重复发伤害
			var radius2: float = rp.melee_hit_radius() if rp.has_method("melee_hit_radius") else 8.0
			if _seg_point_dist(from_pos, global_position, rp.global_position) > HIT_RADIUS_PX + radius2:
				continue
			_hit_ids[rp.get_instance_id()] = true
			var psrc: Vector2 = global_position - velocity.normalized() * 32.0
			var pid: String = String(rp.peer_id) if "peer_id" in rp else ""
			if pid != "":
				NetworkManager.send_player_damage(pid, damage, knockback, psrc.x, psrc.y)
				if rp.has_method("flash_hit"):
					rp.flash_hit()
				# PvP 打中对方玩家也放爆闪 (跟打怪一致)
				if Effects != null and Effects.has_method("spawn_bullet_impact"):
					Effects.spawn_bullet_impact(global_position, velocity, _fx_color, "hit")
			if explode_radius > 0.0:
				_explode(global_position)   # 爆裂/水之: 命中玩家也炸 (AoE 只伤怪, 直击靠上面 send_player_damage)
			if not pierce:
				_destroy()
				return



# 找追踪目标: 敌对怪 (slimes) 优先, 一只都没有才考虑动物 — 追踪弹别丢下僵尸去追小猪.
func _nearest_enemy() -> Node2D:
	for group in ["slimes", "animals"]:
		var best: Node2D = null
		var best_d: float = INF
		for e in get_tree().get_nodes_in_group(group):
			if e == _shooter or not is_instance_valid(e) or not e is Node2D:
				continue
			var d: float = global_position.distance_to((e as Node2D).global_position)
			if d < best_d:
				best_d = d
				best = e
		if best != null:
			return best
	return null

# 爆炸: 爆心 pos 半径 explode_radius 内的怪都受伤 (爆裂火球/水之法杖); 只伤怪, 不破方块.
func _explode(pos: Vector2) -> void:
	# 注: 视觉特效由 _destroy 的 _impact_fx 分发统一放 (爆裂=explosion/水之=splash), 这里只算 AoE 伤害。
	var dmg: int = explode_dmg if explode_dmg > 0 else damage
	for group in ["slimes", "animals"]:
		for e in get_tree().get_nodes_in_group(group):
			if e == _shooter or not is_instance_valid(e) or not e is Node2D or e.has_meta("is_remote"):
				continue
			var ep: Vector2 = (e as Node2D).global_position
			var r: float = e.melee_hit_radius() if e.has_method("melee_hit_radius") else 0.0
			if pos.distance_to(ep) <= explode_radius + r and e.has_method("take_damage"):
				e.take_damage(dmg, pos, knockback)   # src=爆心 → 击退朝外


func _destroy() -> void:
	if _is_dead:
		return
	_is_dead = true
	# 法杖命中特效: 按 _impact_fx 形状放 (闪电星/毒云/魔法星/风条/火爆/水花). 枪没设 → 跳过 (防刷屏)。
	if _impact_fx != "" and Effects != null:
		Effects.spawn_spell_impact(_impact_fx, global_position, _impact_color)
	_release_trail()   # 拖尾别跟着弹一起瞬间消失 → 脱离弹体, 原地渐隐 0.25s
	queue_free()


# 销毁时把拖尾交还给场景, 渐隐后自删 (否则拖尾随弹 queue_free 一下子没了, 很突兀)
func _release_trail() -> void:
	if _trail == null or not is_instance_valid(_trail):
		return
	var tr := _trail
	_trail = null
	var parent := get_parent()
	if parent == null:
		return
	remove_child(tr)
	parent.add_child(tr)
	var tw := tr.create_tween()
	tw.tween_property(tr, "modulate:a", 0.0, 0.25)
	tw.tween_callback(tr.queue_free)


# 点 p 到线段 [a,b] 的最近距离 (扫掠命中判定: 防快子弹两帧间跳过怪)
func _seg_point_dist(a: Vector2, b: Vector2, p: Vector2) -> float:
	var ab: Vector2 = b - a
	var len2: float = ab.length_squared()
	var t: float = 0.0
	if len2 > 0.0001:
		t = clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


# 某格是不是实心墙 (反弹/撞墙判断用)
func _solid_at(cm, x: int, y: int) -> bool:
	var t: int = cm.get_tile(x, y)
	return t != Tiles.AIR and Tiles.is_solid(t)


# 闪电连锁 (接力式): 第一只 → 最近 → 次近 依次跳, 每跳从上一只出发量半径 + 画一道电弧.
# 敌对怪 (slimes) 优先, 动物只在没敌对怪时垫底 (跟 _nearest_enemy 同规矩).
func _do_chain(from_enemy: Node2D, src: Vector2) -> void:
	if from_enemy == null:
		return
	var hit: Dictionary = {from_enemy.get_instance_id(): true}
	var current: Node2D = from_enemy
	for _i in chain:
		var next: Node2D = _chain_next(current, hit)
		if next == null:
			break   # 链断: 半径内没新目标了
		hit[next.get_instance_id()] = true
		if Effects != null and Effects.has_method("spawn_lightning_arc"):
			Effects.spawn_lightning_arc(current.global_position, next.global_position)
		if next.has_method("take_damage"):
			next.take_damage(damage, src, 80.0)
		current = next


# 接力下一跳: current 周围 chain_radius 内没电过的怪, 敌对优先取最近. 没有 → null (链断).
func _chain_next(current: Node2D, hit: Dictionary) -> Node2D:
	for group in ["slimes", "animals"]:
		var best: Node2D = null
		var best_d: float = INF
		for e in get_tree().get_nodes_in_group(group):
			if e == _shooter or not is_instance_valid(e) or not e is Node2D:
				continue
			if e.has_meta("is_remote") or hit.has(e.get_instance_id()):
				continue
			var d: float = current.global_position.distance_to((e as Node2D).global_position)
			if d <= chain_radius and d < best_d:
				best_d = d
				best = e
		if best != null:
			return best
	return null


func _get_cm():
	if _cached_chunk_manager != null and is_instance_valid(_cached_chunk_manager):
		return _cached_chunk_manager
	_cached_chunk_manager = get_tree().get_first_node_in_group("chunk_manager")
	return _cached_chunk_manager
