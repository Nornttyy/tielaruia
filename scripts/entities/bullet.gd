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
var knockback: float = 140.0    # 击退力度 (狂风法杖调很大 = 弹飞)
var launch: bool = false        # true = 击退带上抛 (把怪打飞起来, 狂风法杖)
var _impact_color: Color = Color(0, 0, 0, 0)  # a>0 = 销毁时爆一撮此色火花 (法杖命中特效; 枪不设 → 不喷, 防刷屏)
var _splash: bool = false       # true = 炸开时额外溅一片水花 (水之法杖: 落地/命中都溅水)

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
	knockback = float(opts.get("knockback", 140.0))
	launch = bool(opts.get("launch", false))
	_impact_color = opts.get("impact_color", Color(0, 0, 0, 0))
	_splash = bool(opts.get("splash", false))
	var lt: float = float(opts.get("lifetime", 0.0))
	if lt > 0.0:
		_lifetime = lt
	var dir: Vector2 = (target_pos - start_pos).normalized() if start_pos.distance_to(target_pos) > 0.01 else Vector2.RIGHT
	var spd: float = speed if speed > 0.0 else SPEED
	velocity = dir * spd
	rotation = velocity.angle()   # sprite 朝飞行方向 (子弹直线, 整程不变向)
	_apply_visual()   # setup 在 add_child 后调 → sprite 已就绪, 换成对应贴图


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
				return
			# 爆裂/水之: 撞墙也炸 (只伤怪, 不破方块)
			if explode_radius > 0.0:
				_explode(global_position)
			_destroy()
			return
	var prev_pos: Vector2 = global_position
	global_position = next
	# 手动撞怪. 联机视觉副本 (is_remote) 不撞, 伤害由发起端 host 算.
	if not has_meta("is_remote"):
		_check_enemy_hit(prev_pos)


# from_pos = 这一帧移动前的位置. 用"线段(上一帧→这一帧)到怪的最近距离"判定,
# 而不是只看落点那一个点 — 否则子弹飞太快 (步长 > 命中半径) 会从怪身上跳过去不算命中.
func _check_enemy_hit(from_pos: Vector2) -> void:
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
			if explode_radius > 0.0:
				_explode(global_position)   # 爆裂/水之: 命中玩家也炸 (AoE 只伤怪, 直击靠上面 send_player_damage)
			if not pierce:
				_destroy()
				return



# 找最近的怪 (slimes + animals), 给追踪用. 没有则 null.
func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d: float = INF
	for group in ["slimes", "animals"]:
		for e in get_tree().get_nodes_in_group(group):
			if e == _shooter or not is_instance_valid(e) or not e is Node2D:
				continue
			var d: float = global_position.distance_to((e as Node2D).global_position)
			if d < best_d:
				best_d = d
				best = e
	return best

# 爆炸: 爆心 pos 半径 explode_radius 内的怪都受伤 (爆裂火球/水之法杖); 只伤怪, 不破方块.
func _explode(pos: Vector2) -> void:
	# 水之法杖: 炸开时溅一片蓝水花 (落地 / 命中都溅, 比纯爆炸更"水")
	if _splash and Effects != null:
		Effects.spawn_splash(pos)
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
	# 法杖命中特效: 爆一撮元素色火花 (枪没设 impact_color → a=0 跳过, 不给快枪刷屏)
	if _impact_color.a > 0.0 and Effects != null:
		Effects.spawn_explosion(global_position, _impact_color)
	queue_free()


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


# 闪电连锁: 从 from_enemy 跳到半径内最近的 chain 只其他怪, 各扣 damage.
func _do_chain(from_enemy: Node2D, src: Vector2) -> void:
	if from_enemy == null:
		return
	var origin: Vector2 = from_enemy.global_position
	var cands: Array = []
	for group in ["slimes", "animals"]:
		for e in get_tree().get_nodes_in_group(group):
			if e == from_enemy or e == _shooter or not is_instance_valid(e) or not e is Node2D:
				continue
			if e.has_meta("is_remote"):
				continue
			var d: float = origin.distance_to((e as Node2D).global_position)
			if d <= chain_radius:
				cands.append({"e": e, "d": d})
	cands.sort_custom(func(a, b): return a["d"] < b["d"])
	var n: int = min(chain, cands.size())
	for i in n:
		var e = cands[i]["e"]
		if e.has_method("take_damage"):
			e.take_damage(damage, src, 80.0)


func _get_cm():
	if _cached_chunk_manager != null and is_instance_valid(_cached_chunk_manager):
		return _cached_chunk_manager
	_cached_chunk_manager = get_tree().get_first_node_in_group("chunk_manager")
	return _cached_chunk_manager
