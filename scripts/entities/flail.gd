# 链锤球: 按住时绕玩家转 (蓄力), 松开甩向鼠标到 MAX_DIST 再飞回, 全程一条链子连着玩家。
# 出去/绕转/回来路上都打怪 (同怪 HIT_CD 内不重复)。命中走 player_action.flail_hit (扣血 + 特殊效果)。
extends Area2D

const ORBIT_RADIUS := 26.0    # 绕玩家转的半径 (用户: 之前太大, 缩小)
const ORBIT_SPEED := 13.0     # 转速 (rad/s, 越大转越快)
const FLY_SPEED := 560.0      # 甩出去/飞回的速度
const MAX_DIST := 150.0       # 甩出多远开始往回飞
const BALL_R := 6.0           # 球的命中半径 (跟像素贴图大小对齐)
const HIT_CD := 0.3           # 同一只怪两次命中间隔
const LIFE_MAX := 8.0         # 兜底寿命

var _ball: Sprite2D = null    # 像素贴图球 (子节点, 跟着 Area2D, 自转)

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
	# 像素贴图球 (按元素色现画一张小尖刺球, 最近邻过滤 = 保持像素)
	_ball = Sprite2D.new()
	_ball.texture = _make_ball_texture(_ball_color)
	_ball.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_ball)


# 现画一张 13×13 像素尖刺球贴图: 黑描边 + 元素色实心 + 高光 + 4 根短刺。
func _make_ball_texture(col: Color) -> ImageTexture:
	var S := 13
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ctr := Vector2(6, 6)
	var R := 4.0
	var outline := Color8(28, 24, 30)
	# 圆球本体 + 1px 描边
	for y in S:
		for x in S:
			var d: float = Vector2(x, y).distance_to(ctr)
			if d <= R:
				img.set_pixel(x, y, col)
			elif d <= R + 1.0:
				img.set_pixel(x, y, outline)
	# 4 根短刺 (上下左右各戳出 2px)
	for s in [Vector2i(6, 0), Vector2i(6, 1), Vector2i(6, 11), Vector2i(6, 12),
			Vector2i(0, 6), Vector2i(1, 6), Vector2i(11, 6), Vector2i(12, 6)]:
		img.set_pixel(s.x, s.y, outline)
	# 高光 (左上 2 点)
	img.set_pixel(4, 4, Color(1, 1, 1, 0.9))
	img.set_pixel(5, 4, col.lightened(0.45))
	return ImageTexture.create_from_image(img)


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


# 松手: 甩向 target. 方向从【玩家中心】算, 不是从球当前绕转位置 —
# 否则球转到玩家另一侧时, "球→鼠标" 会指反 = 用户报的"有时不面向鼠标"。
func release(target: Vector2) -> void:
	var origin: Vector2 = _thrower.global_position if _thrower != null and is_instance_valid(_thrower) else global_position
	var d: Vector2 = target - origin
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
	if _ball != null:
		_ball.rotation = _spin   # 球贴图自转 (尖刺转起来)
	_check_hits()
	queue_redraw()   # 每帧重画链子 (玩家在动, 链子要跟)


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
	# 链子: 一节节 2×2 像素方块 (draw_rect 不抗锯齿 = 保持像素), 从玩家手画到球。
	var hand: Vector2 = to_local(_thrower.global_position + Vector2(0, -5))
	var links: int = 6
	for i in range(0, links):
		var p: Vector2 = hand.lerp(Vector2.ZERO, float(i) / float(links))
		var px: float = round(p.x)
		var py: float = round(p.y)
		var col: Color = Color8(150, 152, 160) if i % 2 == 0 else Color8(95, 97, 105)
		draw_rect(Rect2(px - 1.0, py - 1.0, 2.0, 2.0), col, true)   # 实心像素链节
