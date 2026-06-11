# 地裂 (地裂法杖): 地上一道发光裂缝, 站在上面 (横向范围内) 的怪每 TICK 秒受伤, LIFETIME 后消失.
extends Node2D

const LIFETIME := 4.0
const TICK := 0.5
const HALF_WIDTH := 40.0   # 裂缝横向半宽
const VERT_UP := 26.0      # 裂缝上方多高的怪算"站在上面"
const VERT_DOWN := 10.0

var damage: int = 6
var _shooter: Node = null
var _life_t: float = 0.0
var _tick_t: float = 0.0
var _line: Line2D = null
var _glow: Line2D = null


func setup(dmg: int, shooter: Node) -> void:
	damage = dmg
	_shooter = shooter


func _ready() -> void:
	# 视觉: 一道橙红锯齿裂缝 (外发光宽淡 + 内亮线)
	_glow = Line2D.new()
	_glow.width = 6.0
	_glow.default_color = Color(1.0, 0.45, 0.1, 0.35)
	_glow.points = _crack_points()
	add_child(_glow)
	_line = Line2D.new()
	_line.width = 2.5
	_line.default_color = Color(1.0, 0.75, 0.25, 1.0)
	_line.points = _crack_points()
	add_child(_line)


func _crack_points() -> PackedVector2Array:
	# 锯齿裂缝 (横向), 几个上下抖动的点
	return PackedVector2Array([
		Vector2(-HALF_WIDTH, 0), Vector2(-HALF_WIDTH * 0.5, -3),
		Vector2(-8, 2), Vector2(6, -2), Vector2(HALF_WIDTH * 0.5, 3),
		Vector2(HALF_WIDTH, -1),
	])


func _physics_process(delta: float) -> void:
	_life_t += delta
	if _life_t >= LIFETIME:
		queue_free()
		return
	# 临消失前淡出
	var fade: float = clampf((LIFETIME - _life_t) / 1.0, 0.0, 1.0)
	if _line != null:
		_line.modulate.a = fade
	if _glow != null:
		_glow.modulate.a = fade
	_tick_t -= delta
	if _tick_t <= 0.0:
		_tick_t = TICK
		_damage_enemies()


func _damage_enemies() -> void:
	for grp in ["slimes", "animals"]:
		for e in get_tree().get_nodes_in_group(grp):
			if e == _shooter or not is_instance_valid(e) or not (e is Node2D):
				continue
			if e.has_meta("is_remote"):
				continue
			var ep: Vector2 = (e as Node2D).global_position
			if _in_band(ep) and e.has_method("take_damage"):
				# 从下往上顶一下 (src 在裂缝下方 → 击退朝上)
				e.take_damage(damage, Vector2(ep.x, global_position.y + 24.0), 70.0)
	# PvP: 对战房里裂缝也能伤站上面的远程玩家 (发伤害给对方, 对方扣自己血)
	if NetworkManager != null and NetworkManager.combat_enabled():
		for s in get_tree().get_nodes_in_group("remote_player"):
			var rp := s as Node2D
			if rp == null or not is_instance_valid(rp) or not _in_band(rp.global_position):
				continue
			var pid: String = String(rp.peer_id) if "peer_id" in rp else ""
			if pid != "":
				NetworkManager.send_player_damage(pid, damage, 70.0, rp.global_position.x, global_position.y + 24.0)
				if rp.has_method("flash_hit"):
					rp.flash_hit()


# 点是否落在裂缝的横向带 + 上方一点点 (= "站在裂缝上")
func _in_band(p: Vector2) -> bool:
	return abs(p.x - global_position.x) <= HALF_WIDTH \
			and p.y <= global_position.y + VERT_DOWN and p.y >= global_position.y - VERT_UP
