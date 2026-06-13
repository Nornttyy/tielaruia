# 回旋镖: 朝鼠标飞出去 MAX_DIST, 然后拐回来飞向投掷者, 被接住(或超时)消失。
# 飞出 + 飞回路上都打怪 (同一只怪 HIT_CD 内不重复打 → 出去打一次, 回来再打一次)。
extends Area2D

const SPEED := 340.0
const MAX_DIST := 150.0   # 飞出多远开始往回拐
const HIT_CD := 0.35      # 同一只怪两次命中的间隔 (出去/回来各一次)
const LIFE_MAX := 4.0     # 兜底寿命 (投掷者没了也别永久飞)

var damage: int = 9
var _thrower: Node2D = null
var _dir: Vector2 = Vector2.RIGHT
var _returning: bool = false
var _out: float = 0.0
var _life: float = 0.0
var _hit_t: Dictionary = {}   # enemy id → 下次可再打的 _life 时刻

@onready var sprite: Sprite2D = $Sprite2D


func setup(start_pos: Vector2, target: Vector2, dmg: int, thrower: Node2D) -> void:
	global_position = start_pos
	damage = dmg
	_thrower = thrower
	var d: Vector2 = target - start_pos
	_dir = d.normalized() if d.length() > 0.01 else Vector2.RIGHT


func _ready() -> void:
	if sprite != null:
		sprite.texture = ArtCache.get_inventory_icon("boomerang")   # 复用背包图标当飞行贴图
		sprite.scale = Vector2(1.4, 1.4)


func _physics_process(delta: float) -> void:
	_life += delta
	if _life >= LIFE_MAX:
		queue_free()
		return
	if not _returning:
		global_position += _dir * SPEED * delta
		_out += SPEED * delta
		if _out >= MAX_DIST:
			_returning = true
	else:
		if _thrower == null or not is_instance_valid(_thrower):
			queue_free()
			return
		var to: Vector2 = _thrower.global_position - global_position
		if to.length() < 12.0:
			queue_free()   # 飞回被接住
			return
		global_position += to.normalized() * SPEED * delta
	if sprite != null:
		sprite.rotation += delta * 20.0   # 旋转
	_check_hits()


func _check_hits() -> void:
	for grp in ["slimes", "animals"]:
		for e in get_tree().get_nodes_in_group(grp):
			if not is_instance_valid(e) or not (e is Node2D) or e.has_meta("is_remote"):
				continue
			var id: int = e.get_instance_id()
			if float(_hit_t.get(id, -1.0)) > _life:
				continue   # 还在 CD 里
			var r: float = e.melee_hit_radius() if e.has_method("melee_hit_radius") else 0.0
			if global_position.distance_to((e as Node2D).global_position) <= 12.0 + r:
				if e.has_method("take_damage"):
					e.take_damage(damage, global_position, 60.0)
				_hit_t[id] = _life + HIT_CD
	# PvP: 回旋镖也能打远程玩家 (照 arrow/bullet)
	if NetworkManager != null and NetworkManager.combat_enabled():
		for s in get_tree().get_nodes_in_group("remote_player"):
			var rp := s as Node2D
			if rp == null or not is_instance_valid(rp):
				continue
			var id2: int = rp.get_instance_id()
			if float(_hit_t.get(id2, -1.0)) > _life:
				continue
			var r2: float = rp.melee_hit_radius() if rp.has_method("melee_hit_radius") else 8.0
			if global_position.distance_to(rp.global_position) <= 12.0 + r2:
				var pid: String = String(rp.peer_id) if "peer_id" in rp else ""
				if pid != "":
					NetworkManager.send_player_damage(pid, damage, 60.0, global_position.x, global_position.y)
					if rp.has_method("flash_hit"):
						rp.flash_hit()
				_hit_t[id2] = _life + HIT_CD
