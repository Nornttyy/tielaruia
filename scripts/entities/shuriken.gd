# 手里剑: 物理飞镖 (不是魔法!). 用自己的图标当贴图旋转飞, 笔直前进, 穿透 (一只怪打一次),
# 命中冒一小撮金属火星 (无魔法拖尾/光晕). 撞实心方块 / 超时消失。PvP 也能打远程玩家。
extends Area2D

const SPEED := 540.0
const LIFE := 1.2
const TILE_SIZE := 12

var damage: int = 6
var _dir: Vector2 = Vector2.RIGHT
var _life: float = 0.0
var _hit: Dictionary = {}   # 已打过的目标 id (穿透不重复打)
var _cm = null

@onready var sprite: Sprite2D = $Sprite2D


func setup(start_pos: Vector2, target: Vector2, dmg: int, _shooter: Node2D) -> void:
	global_position = start_pos
	damage = dmg
	var d: Vector2 = target - start_pos
	_dir = d.normalized() if d.length() > 0.01 else Vector2.RIGHT


func _ready() -> void:
	if sprite != null:
		sprite.texture = ArtCache.get_inventory_icon("shuriken")   # 金属飞镖图标


func _physics_process(delta: float) -> void:
	_life += delta
	if _life >= LIFE:
		queue_free()
		return
	var next: Vector2 = global_position + _dir * SPEED * delta
	var cm = _get_cm()
	if cm != null:
		var t: int = cm.get_tile(int(floor(next.x / TILE_SIZE)), int(floor(next.y / TILE_SIZE)))
		if t != Tiles.AIR and Tiles.is_solid(t):
			queue_free()   # 钉墙上
			return
	global_position = next
	if sprite != null:
		sprite.rotation += delta * 30.0   # 飞快旋转 = 金属星
	_check_hits()


func _check_hits() -> void:
	for grp in ["slimes", "animals"]:
		for e in get_tree().get_nodes_in_group(grp):
			if not is_instance_valid(e) or not (e is Node2D) or e.has_meta("is_remote"):
				continue
			var id: int = e.get_instance_id()
			if _hit.has(id):
				continue
			var r: float = e.melee_hit_radius() if e.has_method("melee_hit_radius") else 0.0
			if global_position.distance_to((e as Node2D).global_position) <= 10.0 + r:
				if e.has_method("take_damage"):
					e.take_damage(damage, global_position, 60.0)
				_hit[id] = true
				if Effects != null and Effects.has_method("spawn_bullet_impact"):
					Effects.spawn_bullet_impact(global_position, _dir, Color8(205, 205, 215), "hit")   # 金属火星
	if NetworkManager != null and NetworkManager.combat_enabled():
		for s in get_tree().get_nodes_in_group("remote_player"):
			var rp := s as Node2D
			if rp == null or not is_instance_valid(rp):
				continue
			var id2: int = rp.get_instance_id()
			if _hit.has(id2):
				continue
			var r2: float = rp.melee_hit_radius() if rp.has_method("melee_hit_radius") else 8.0
			if global_position.distance_to(rp.global_position) <= 10.0 + r2:
				var pid: String = String(rp.peer_id) if "peer_id" in rp else ""
				if pid != "":
					NetworkManager.send_player_damage(pid, damage, 60.0, global_position.x, global_position.y)
					if rp.has_method("flash_hit"):
						rp.flash_hit()
				_hit[id2] = true


func _get_cm():
	if _cm != null and is_instance_valid(_cm):
		return _cm
	var terrain: Node = get_tree().get_first_node_in_group("terrain_layer")
	if terrain == null:
		return null
	var world: Node = terrain.get_parent()
	_cm = world.get("chunk_manager") if world != null else null
	return _cm
