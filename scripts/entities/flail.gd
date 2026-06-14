# 链锤球: 按住时绕玩家转 (蓄力), 松开甩向鼠标到 MAX_DIST 再飞回, 全程一条链子连着玩家。
# 出去/绕转/回来路上都打怪 (同怪 HIT_CD 内不重复)。命中走 player_action.flail_hit (扣血 + 特殊效果)。
extends Area2D

const ORBIT_RADIUS := 40.0    # 绕玩家转的半径
const ORBIT_SPEED := 13.0     # 转速 (rad/s, 越大转越快)
const FLY_SPEED := 600.0      # 甩出去/飞回的速度
const MAX_DIST := 180.0       # 甩出多远开始往回飞
const BALL_R := 8.0           # 球的命中/视觉半径
const HIT_CD := 0.3           # 同一只怪两次命中间隔
const LIFE_MAX := 8.0         # 兜底寿命

# 状态: 0=绕转(蓄力) 1=甩出 2=飞回
const ST_ORBIT := 0
const ST_OUT := 1
const ST_RETURN := 2

var _thrower: Node2D = null
var _action: Node = null      # player_action, 命中回调用
var _damage: int = 10
var _knockback: float = 180.0
var _state: int = ST_ORBIT
var _angle: float = 0.0       # 绕转角
var _dir: Vector2 = Vector2.RIGHT
var _out: float = 0.0
var _life: float = 0.0
var _spin: float = 0.0        # 球自转 (视觉)
var _hit_t: Dictionary = {}
var _ball_color: Color = Color8(180, 185, 195)
var _slow_factor: float = 0.0
var _slow_dur: float = 0.0


func setup(thrower: Node2D, action: Node, dmg: int, def: Dictionary) -> void:
	_thrower = thrower
	_action = action
	_damage = dmg
	_knockback = float(def.get("melee_knockback", 180.0))
	_ball_color = _color_for(String(def.get("gun_visual", "metal")))
	_slow_factor = float(def.get("gun_slow_factor", 0.0))
	_slow_dur = float(def.get("gun_slow_dur", 0.0))
	if thrower != null:
		global_position = thrower.global_position + Vector2(ORBIT_RADIUS, 0)


func _color_for(v: String) -> Color:
	match v:
		"fire":      return Color8(255, 150, 40)
		"ice":       return Color8(90, 180, 240)
		"leaf":      return Color8(120, 200, 80)
		"lightning": return Color8(255, 235, 90)
		"void":      return Color8(150, 90, 220)
		_:           return Color8(180, 185, 195)   # 金属灰


func is_orbiting() -> bool:
	return _state == ST_ORBIT


# 松手: 甩向 target 方向
func release(target: Vector2) -> void:
	var d: Vector2 = target - global_position
	_dir = d.normalized() if d.length() > 0.01 else Vector2.RIGHT
	_state = ST_OUT
	_out = 0.0


func _physics_process(delta: float) -> void:
	_life += delta
	_spin += delta * 16.0
	if _life >= LIFE_MAX or _thrower == null or not is_instance_valid(_thrower):
		queue_free()
		return
	var pivot: Vector2 = _thrower.global_position
	match _state:
		ST_ORBIT:
			# 绕玩家快速转圈 (蓄力中)
			_angle += ORBIT_SPEED * delta
			global_position = pivot + Vector2(ORBIT_RADIUS, 0).rotated(_angle)
		ST_OUT:
			global_position += _dir * FLY_SPEED * delta
			_out += FLY_SPEED * delta
			if _out >= MAX_DIST:
				_state = ST_RETURN
		ST_RETURN:
			var to: Vector2 = pivot - global_position
			if to.length() < 16.0:
				queue_free()   # 飞回手里, 收工
				return
			global_position += to.normalized() * FLY_SPEED * delta
	_check_hits()
	queue_redraw()   # 每帧重画球 + 链子 (玩家在动, 链子要跟)


func _check_hits() -> void:
	for grp in ["slimes", "animals"]:
		for e in get_tree().get_nodes_in_group(grp):
			if not is_instance_valid(e) or not (e is Node2D) or e.has_meta("is_remote"):
				continue
			var id: int = e.get_instance_id()
			if float(_hit_t.get(id, -1.0)) > _life:
				continue
			var r: float = e.melee_hit_radius() if e.has_method("melee_hit_radius") else 0.0
			if global_position.distance_to((e as Node2D).global_position) <= BALL_R + 4.0 + r:
				if _slow_factor > 0.0 and e.has_method("apply_slow"):
					e.apply_slow(_slow_factor, _slow_dur)   # 寒冰锤: 命中减速
				if _action != null and _action.has_method("flail_hit"):
					_action.flail_hit(e, global_position, _knockback)
				_hit_t[id] = _life + HIT_CD
	# PvP: 对战房里也能砸远程玩家 (照 boomerang)
	if NetworkManager != null and NetworkManager.combat_enabled():
		for s in get_tree().get_nodes_in_group("remote_player"):
			var rp := s as Node2D
			if rp == null or not is_instance_valid(rp):
				continue
			var id2: int = rp.get_instance_id()
			if float(_hit_t.get(id2, -1.0)) > _life:
				continue
			var r2: float = rp.melee_hit_radius() if rp.has_method("melee_hit_radius") else 8.0
			if global_position.distance_to(rp.global_position) <= BALL_R + 4.0 + r2:
				var pid: String = String(rp.peer_id) if "peer_id" in rp else ""
				if pid != "":
					NetworkManager.send_player_damage(pid, _damage, _knockback, global_position.x, global_position.y)
					if rp.has_method("flash_hit"):
						rp.flash_hit()
				_hit_t[id2] = _life + HIT_CD


func _draw() -> void:
	if _thrower == null or not is_instance_valid(_thrower):
		return
	# 链子: 从玩家手 (local) 画到球 (原点). 几节短线段看着像铁链。
	var hand: Vector2 = to_local(_thrower.global_position + Vector2(0, -6))
	var chain_col := Color8(90, 92, 100)
	draw_line(hand, Vector2.ZERO, chain_col, 3.0)
	# 链节小点 (沿链子等距, 看着像一节节)
	var links: int = 5
	for i in range(1, links):
		var p: Vector2 = hand.lerp(Vector2.ZERO, float(i) / float(links))
		draw_circle(p, 1.8, Color8(140, 142, 150))
	# 球: 深色描边 + 主体 + 4 根尖刺 + 高光
	draw_circle(Vector2.ZERO, BALL_R + 1.5, Color8(35, 35, 42))   # 描边
	for k in 4:
		var a: float = _spin + float(k) * PI / 2.0
		var tip: Vector2 = Vector2(BALL_R + 4.0, 0).rotated(a)
		draw_line(tip * 0.5, tip, Color8(60, 62, 70), 3.0)        # 尖刺
	draw_circle(Vector2.ZERO, BALL_R, _ball_color)               # 主体 (元素色)
	draw_circle(Vector2(-2.5, -2.5), 2.2, Color(1, 1, 1, 0.7))   # 高光
