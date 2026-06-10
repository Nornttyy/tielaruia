# 玩家交互：鼠标瞄准、距离检查、挖放进度。
extends Node2D

const ItemDropScene = preload("res://scenes/items/item_drop.tscn")
const TILE_SIZE := 12
const REACH_TILES := 4
const INVALID_TILE := Vector2i(-1, -1)

# Tile 硬度（累计 tool_speed*delta 达此值挖完，单位"秒"）
# 用户改: 矿石按 tier 递增 (3→8s), 石头/煤 3s base.
# 镐 _tool_speed 按 tier 1-7 加速 (wood ×1 → diamond ×5).
const _HARDNESS := {
	Tiles.GRASS: 0.3,
	Tiles.DIRT: 0.3,
	Tiles.SAND: 0.3,
	Tiles.LEAVES: 0.2,
	Tiles.PLANKS: 0.3,
	Tiles.WORKBENCH: 0.5,
	Tiles.DOOR: 0.5,
	Tiles.LOG: 0.6,
	Tiles.STONE: 3.0,          # base (不变)
	Tiles.DEEP_STONE: 3.0,
	Tiles.COAL_ORE: 3.0,       # 跟石头同
	Tiles.COPPER_ORE: 5.0,     # 用户调: "稍微快一点", 石镐挖 4.2s
	Tiles.TIN_ORE: 5.0,
	Tiles.IRON_ORE: 6.0,       # 铜镐挖 4s
	Tiles.SILVER_ORE: 8.0,     # 铁镐挖 4s
	Tiles.GOLD_ORE: 10.0,      # 银镐挖 4s
	Tiles.DIAMOND_ORE: 12.0,   # 金镐挖 3.6s
	Tiles.HELL_CRYSTAL: 15.0,  # 用户改: 应是最久的矿 (> 钻 12s), 钻镐挖 3s
	Tiles.LOG_TOP: 0.6,
	Tiles.LOG_ROOT_L: 0.4,
	Tiles.LOG_ROOT_R: 0.4,
	Tiles.BRANCH_L: 0.4,
	Tiles.BRANCH_R: 0.4,
}

# 镐"石头类"目标 (拿 tier 加速): 石 + 深石 + 全部矿石.
# 草/泥/沙/木板等 pickaxe 用基础 ×1 速度, 不在表里.
const _PICKAXE_STONE_LIKE := {
	Tiles.STONE: true,
	Tiles.DEEP_STONE: true,
	Tiles.COAL_ORE: true,
	Tiles.COPPER_ORE: true,
	Tiles.TIN_ORE: true,
	Tiles.IRON_ORE: true,
	Tiles.SILVER_ORE: true,
	Tiles.GOLD_ORE: true,
	Tiles.DIAMOND_ORE: true,
	Tiles.HELL_CRYSTAL: true,
}

# 树的所有 tile 类型 (用于级联砍树)
const _TREE_PARTS := {
	Tiles.LOG: true,
	Tiles.LOG_TOP: true,
	Tiles.LOG_ROOT_L: true,
	Tiles.LOG_ROOT_R: true,
	Tiles.BRANCH_L: true,
	Tiles.BRANCH_R: true,
}

# 长在地上、需要下方有支撑的"植物": 下面方块被挖掉 → 它也跟着没 (防悬空). 仙人掌可叠 → 往上连消.
const _PLANT_NEEDS_GROUND := {
	Tiles.PLANT_GRASS: true, Tiles.MUSHROOM: true,
	Tiles.CACTUS: true, Tiles.CACTUS_BODY: true,
	Tiles.WHEAT_0: true, Tiles.WHEAT_1: true, Tiles.WHEAT_2: true, Tiles.WHEAT_3: true,
	Tiles.RICE_0: true, Tiles.RICE_1: true, Tiles.RICE_2: true, Tiles.RICE_3: true,
}

# 镐挖不了的"植物"类 tile (叶子 / 仙人掌 / 蘑菇 / 火果 / 火把等小物).
# 镐只破坏"方块". 不挡 axe (砍 LOG/仙人掌) / sword (无挖矿). 也不挡徒手 / 别工具.
const _PICKAXE_BLACKLIST := {
	Tiles.LEAVES: true,
	Tiles.LEAVES_PINE: true,
	Tiles.LEAVES_AUTUMN: true,
	Tiles.JUNGLE_LEAVES: true,
	Tiles.CACTUS: true,
	Tiles.CACTUS_BODY: true,
	Tiles.MUSHROOM: true,
	Tiles.HELL_FRUIT: true,
	Tiles.TORCH: true,
	Tiles.SLIME_TORCH: true,
}

# 斧能砍的 tile (用户改: 仙人掌也能砍). LOG 走 tree cascade, 仙人掌按段砍.
const _AXE_TARGETS := {
	Tiles.LOG: true,
	Tiles.CACTUS: true,
	Tiles.CACTUS_BODY: true,
}

# 测试注入
var aim_override: Variant = null
var primary_override: Variant = null     # null = 真实输入；bool = 强制
var place_override: bool = false
var secondary_held_override: Variant = null  # null = 真实输入；bool = 强制（测试）

# Mining 状态
var _mining_target: Vector2i = INVALID_TILE
var _mining_progress: float = 0.0
var _mining_swing_t: float = 0.0  # 挖矿挥镐动画节流
# 每个方块保留挖掘进度: Vector2i → [tid, progress]. 松手/切目标不清零, 回来接着挖.
# tid 一起存 → 那格方块换了 (挖掉重放/变了) 就不续旧进度.
var _mine_saved: Dictionary = {}

# 战斗
const SWORD_RANGE_PX := 27.0
const SWORD_COOLDOWN := 0.50   # 阔剑(扫): 跟挥击时长 0.5s 对齐, 一刀完整挥完才能再挥 (防连挥重叠抽搐); 短剑(戳)快 0.3
var _attack_cooldown: float = 0.0
# 剑的戳/挥交替: 0 = 下一击戳, 1 = 下一击挥. 切工具时归零.
var _attack_combo_step: int = 0

# 镐旋转: 用户改 — 怪要碰到镐才扣血 (不是 AoE 圆心扣血).
# spin 期间每帧算 pickaxe tip 世界位置, 距离 ≤ HIT_RADIUS 的怪扣 1 次.
# 用户改: PICKAXE_SPIN_DURATION 0.7→1.0 慢一点; spin 起始朝鼠标 (不再总从上).
const PICKAXE_SPIN_DURATION := 1.0
const PICKAXE_TIP_LOCAL_Y := -20.0   # tip 相对 held.position 的 y 偏移 (sprite 16h × scale 1.25)
const PICKAXE_HIT_RADIUS := 12.5     # tip 到怪中心 ≤ 12.5px 算碰到 (玩家 1.25x)
var _pickaxe_spin_active: bool = false
var _pickaxe_spin_t: float = 0.0
var _pickaxe_hit_this_spin: Dictionary = {}  # instance_id → true (1 spin 1 只怪 1 击)
# spin 起始旋转 + 朝向 (跟 held_item.play_pickaxe_attack 同步, 用于 hit 检测 tip 算法)
var _pickaxe_spin_start_rot: float = 0.0
var _pickaxe_spin_facing_right: bool = true
var _pickaxe_spin_damages: bool = false   # 只有"攻击"spin 扣血; 挖矿/斧的 spin 纯视觉 (修挖矿误伤旁边怪)

# 剑判定: 跟镐 spin 类似, 攻击期间每帧算 grip→tip 线段, 距怪 ≤ HIT_RADIUS 就扣血.
# 1 攻击 1 只怪 1 击 (hit set 去重). 替代原来的 AoE 矩形/圆形.
# 用户改: "剑碰到怪就扣血", 不是按攻击瞬间 AoE 圆扣.
# 注: rotation/position 自己按 _sword_attack_t 算, 不读 held.rotation —
# tween 在 _process 更新, _physics_process 这里读可能滞后 (headless 测试 tween 可能不动).
const SWORD_TIP_LOCAL_Y := -20.0       # tip 相对 held.position 的 y (sprite 16h × scale 1.25)
const SWORD_SWEEP_REACH_BONUS := 20.0  # 阔剑挥剑身比基础长这么多 → 够得更远 (用户嫌阔剑太短, 12→20)
const SWORD_HIT_RADIUS := 17.5         # 怪中心到 grip→tip 线段 ≤ 17.5px (玩家 1.25x). 视觉碰到了 算法也命中
const SWORD_POINT_BLANK_DIST := 22.5   # 怪离玩家中心 ≤ 22.5px 视为贴脸 (玩家 1.25x), 任何剑攻击一律命中
const SWORD_HAND_OFFSET_X := 5.0       # 跟 held_item.HAND_OFFSET_X 一致 (剑柄手位)
const SWORD_HAND_OFFSET_Y := -10.0     # 跟 held_item.HAND_OFFSET_Y 一致
const SWORD_THRUST_OFFSET := 8.0       # 跟 held_item.THRUST_OFFSET_PX 一致 (用户: 短剑戳太远 → 12.5→8)
const DAGGER_BLADE_SHORTEN := 6.0      # 短剑(戳)命中剑身比阔剑短这么多 → 戳得更近 (剑短)
const DAGGER_HIT_RADIUS := 13.0        # 短剑命中半径比阔剑(17.5)小, 更"贴"不糊到远处怪
const SWORD_THRUST_DURATION := 0.30    # 三段: 20% 突出, 55% dwell, 25% 收回
const SWORD_THRUST_EXTEND_END := 0.20  # 0..0.20 突出阶段结束
const SWORD_THRUST_DWELL_END := 0.75   # 0.20..0.75 dwell, 0.75+ 收回 (主要打击在 dwell)
const SWORD_SWING_DURATION := 0.50     # 剑挥旋转时长 (用户调: 0.5s; 跟 held_item.SWING_DURATION 一致)
var _sword_attack_active: bool = false
var _sword_attack_t: float = 0.0
var _sword_attack_duration: float = 0.0
var _sword_attack_is_sweep: bool = false   # true = 挥 (rotation 转半圆), false = 戳 (position 动)
var _sword_attack_swing_dir: Vector2 = Vector2.RIGHT
var _sword_attack_target_angle: float = 0.0
var _sword_attack_start_rot: float = 0.0   # 挥的起手 rotation (戳不用)
var _sword_attack_facing_right: bool = true
var _sword_attack_damage: int = 0
var _sword_attack_knockback: float = 0.0
var _sword_hit_this_attack: Dictionary = {}  # instance_id → true

# 测试用: 记录最近一次挥剑的命中中心点 (玩家中心 + 鼠标方向 * 半径)
var last_swing_center: Vector2 = Vector2.ZERO
# 测试用: 注入鼠标世界坐标 (null = 真实 get_global_mouse_position)
var mouse_world_override: Variant = null

# 进食状态
const EAT_DURATION_SEC := 2.0   # 进食 2 秒 (按住右键 / F 键持续)
var _eat_t: float = 0.0
var _eat_item_id: String = ""
var _f_was_pressed: bool = false   # F 键上一帧状态 (KEY_F 没有 is_key_just_pressed, 自己 track)


func set_secondary_held_for_test(held: bool) -> void:
	secondary_held_override = held


func _ready() -> void:
	# 切 hotbar 时重置剑的戳/挥序列 (防玩家切镐再切回剑还接着上次的挥)
	# 用 call_deferred 等 PlayerInventory 也 _ready 完
	_connect_hotbar_signal.call_deferred()


func _connect_hotbar_signal() -> void:
	var inv: Node = _inventory_node()
	if inv != null and inv.has_signal("hotbar_selection_changed"):
		if not inv.hotbar_selection_changed.is_connected(_on_hotbar_changed):
			inv.hotbar_selection_changed.connect(_on_hotbar_changed)


# signal handler 同步: 不要加 await (CLAUDE.md feedback_no_async_signal)
func _on_hotbar_changed(_idx: int) -> void:
	_attack_combo_step = 0


func _physics_process(delta: float) -> void:
	# E 一键合成: 工作台旁开 3x3, 否则 2x2; 已开则关
	if Input.is_action_just_pressed("interact"):
		_try_open_workbench_or_close()
	# 其余动作面板开则跳过
	if _crafting_open():
		return
	_attack_cooldown = max(0.0, _attack_cooldown - delta)
	# 持剑 LMB: 按剑的种类选 — 短剑(dagger)永远戳, 阔剑(sword)永远半圆挥. 不再按 tier.
	var kind: String = _current_tool_kind()
	if kind == "sword":
		_reset_mining()
		var primary_pressed: bool = (primary_override == true) if primary_override != null else Input.is_action_pressed("primary")
		if primary_pressed and _attack_cooldown <= 0.0:
			if _current_sword_style_is_thrust():
				_thrust_sword()
			else:
				_sweep_sword()
	elif kind == "pickaxe":
		# 优先级: 鼠标对方块 → 挖矿; 否则 鼠标附近有怪 → 攻击
		if _mouse_on_mineable_tile():
			_update_mining(delta)
		else:
			_reset_mining()
			var primary_pressed_p: bool = (primary_override == true) if primary_override != null else Input.is_action_pressed("primary")
			if primary_pressed_p and _attack_cooldown <= 0.0 and _mouse_has_enemy_nearby():
				_pickaxe_attack()
	elif kind == "axe":
		# 用户改: 斧动作跟镐同款. 鼠标对 LOG → 砍 + spin; 否则 附近怪 → spin (0 伤害, 视觉)
		if _mouse_on_log():
			_update_mining(delta)
		else:
			_reset_mining()
			var primary_pressed_a: bool = (primary_override == true) if primary_override != null else Input.is_action_pressed("primary")
			if primary_pressed_a and _attack_cooldown <= 0.0 and _mouse_has_enemy_nearby():
				_axe_swing()
	elif kind == "bow":
		# 弓: LMB 按下 → 朝鼠标发箭, 消耗 1 wood_arrow. cooldown 0.4s.
		_reset_mining()
		var primary_pressed_b: bool = (primary_override == true) if primary_override != null else Input.is_action_pressed("primary")
		if primary_pressed_b and _attack_cooldown <= 0.0:
			_try_fire_bow()
			_flash_held()   # 射箭时显示弓 (无挥摆动画, 闪一下)
	elif kind == "gun":
		# 枪: LMB 按下 → 朝鼠标射子弹, 消耗 1 bullet. cooldown 0.22s (比弓快).
		_reset_mining()
		var primary_pressed_g: bool = (primary_override == true) if primary_override != null else Input.is_action_pressed("primary")
		if primary_pressed_g and _attack_cooldown <= 0.0:
			_try_fire_gun()
			_aim_held_at_mouse()   # 开枪时枪朝鼠标方向显示
	elif kind == "staff":
		# 法杖: LMB 按下 → 火球 (普通法杖) 或 召唤友方骷髅 (骷髅法杖 summons_minion).
		_reset_mining()
		var primary_pressed_s: bool = (primary_override == true) if primary_override != null else Input.is_action_pressed("primary")
		if primary_pressed_s and _attack_cooldown <= 0.0:
			var sdef: Variant = _current_tool_def()
			if sdef != null and sdef.get("summons_minion", false):
				_summon_friendly()
			else:
				_try_cast_staff()
			_flash_held()   # 施法时显示法杖
	elif kind == "slimeball":
		# 史莱姆球: LMB 按下 → 朝鼠标投弹跳球. cd 0.45s. 无弹药 (Boss 武器).
		_reset_mining()
		var primary_pressed_sb: bool = (primary_override == true) if primary_override != null else Input.is_action_pressed("primary")
		if primary_pressed_sb and _attack_cooldown <= 0.0:
			_try_throw_slimeball()
			_flash_held()   # 投掷时显示
	else:
		_update_mining(delta)
	_update_eat_or_place(delta)
	# 工具 spin 中: 每帧检查 tip 跟怪的距离, 碰到就扣血 (镐 + 斧共用; 斧 damage_mult=0 自动跳过)
	if _pickaxe_spin_active:
		_pickaxe_spin_t += delta
		if _pickaxe_spin_t >= PICKAXE_SPIN_DURATION:
			_pickaxe_spin_active = false
			_pickaxe_hit_this_spin.clear()
		else:
			_check_pickaxe_spin_hits()
	# 剑攻击中 (戳/挥): 同样每帧扫 grip→tip 线段, 跟怪贴近就扣血. 1 攻击 1 只怪 1 击.
	if _sword_attack_active:
		_sword_attack_t += delta
		if _sword_attack_t >= _sword_attack_duration:
			_sword_attack_active = false
			_sword_hit_this_attack.clear()
		else:
			_check_sword_blade_hits()


func _crafting_open() -> bool:
	var cp: CanvasLayer = get_tree().get_first_node_in_group("crafting_panel")
	return cp != null and cp.is_open()


func _toggle_crafting(n: int) -> void:
	var cp: CanvasLayer = get_tree().get_first_node_in_group("crafting_panel")
	if cp == null:
		return
	if cp.is_open():
		cp.close()
	else:
		cp.open(n)


func _try_open_workbench_or_close() -> void:
	# 优先级 2: 鼠标对准 chest tile → 开 chest (E 跟右键同款 — 用户要求)
	var aim_tile: Vector2i = aim_tile_coord()
	if in_reach(aim_tile):
		var terrain := _terrain()
		if terrain != null:
			var aim_tid: int = terrain.get_cell_source_id(aim_tile)
			if aim_tid == Tiles.CHEST or aim_tid == Tiles.GOLD_CHEST or aim_tid == Tiles.DIAMOND_CHEST or aim_tid == Tiles.SHADOW_CHEST:
				var chest_p: CanvasLayer = get_tree().get_first_node_in_group("chest_panel")
				if chest_p == null:
					chest_p = get_tree().root.find_child("ChestPanel", true, false)
				if chest_p != null and chest_p.has_method("open"):
					var inv: Node = _inventory_node()
					chest_p.open(aim_tile, inv)
				return
	# 优先级 2.5: 没对准 chest 时, 找玩家身边 ±2 格里的 chest 开 (用户要求 "靠近就 E")
	var near_chest: Vector2i = _find_chest_nearby()
	if near_chest != Vector2i(-99999, -99999):
		var chest_p2: CanvasLayer = get_tree().get_first_node_in_group("chest_panel")
		if chest_p2 == null:
			chest_p2 = get_tree().root.find_child("ChestPanel", true, false)
		if chest_p2 != null and chest_p2.has_method("open"):
			var inv2: Node = _inventory_node()
			chest_p2.open(near_chest, inv2)
		return
	# 优先级 3: 合成面板 (工作台 → 3x3, 否则 2x2)
	var cp: CanvasLayer = get_tree().get_first_node_in_group("crafting_panel")
	if cp == null:
		return
	if cp.is_open():
		cp.close()
		return
	if _has_workbench_nearby():
		cp.open(3)
	else:
		cp.open(2)


func _has_workbench_nearby() -> bool:
	var terrain := _terrain()
	if terrain == null:
		return false
	var pt: Vector2i = player_tile()
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var tid: int = terrain.get_cell_source_id(pt + Vector2i(dx, dy))
			if tid == Tiles.WORKBENCH:
				return true
	return false


# 找玩家身边 ±2 格里第一个 CHEST/GOLD/DIAMOND/SHADOW tile, 返回 tile 坐标.
# 没找到返 (-99999, -99999) 哨兵.
func _find_chest_nearby() -> Vector2i:
	var terrain := _terrain()
	if terrain == null:
		return Vector2i(-99999, -99999)
	var pt: Vector2i = player_tile()
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var coord: Vector2i = pt + Vector2i(dx, dy)
			var tid: int = terrain.get_cell_source_id(coord)
			if tid == Tiles.CHEST or tid == Tiles.GOLD_CHEST or tid == Tiles.DIAMOND_CHEST or tid == Tiles.SHADOW_CHEST:
				return coord
	return Vector2i(-99999, -99999)


func _update_mining(delta: float) -> void:
	var pressed: bool = (primary_override == true) if primary_override != null else Input.is_action_pressed("primary")
	if not pressed:
		_reset_mining()
		return
	# 锤子: 破坏背景墙 (不挖方块). 独立分支, 创造模式也在里面处理.
	if _current_tool_kind() == "hammer":
		_update_wall_mining(delta)
		return
	# 创造模式: 秒挖 — 对准任意"可挖"方块瞬间破 (不要工具/不管树支撑). 基岩等不可挖的仍挡住.
	if GameSettings != null and GameSettings.creative_mode:
		var ct: Vector2i = aim_tile_coord()
		var cterrain := _terrain()
		if cterrain == null:
			return
		if not in_reach(ct):
			_reset_mining()
			return
		var ctid: int = cterrain.get_cell_source_id(ct)
		if ctid == -1 or not Tiles.is_mineable(ctid):
			_reset_mining()
			return
		_mining_swing_t -= delta
		if _mining_swing_t <= 0.0:   # 挥一下手 (秒挖也给点动作反馈)
			_mining_swing_t = 0.25
			var held: Node = _held_item_node()
			if held != null:
				if held.has_method("play_pickaxe_attack"):
					_start_pickaxe_spin()
				elif held.has_method("play_swing"):
					held.play_swing()
		_finish_mine(ct, ctid, _current_tool_kind(), cterrain)
		_clear_crack(ct)
		_mining_target = INVALID_TILE
		_mining_progress = 0.0
		return
	# 斧只能砍 LOG / 仙人掌, 别的 tile 早 return 不播挖矿摆动 (防 "斧对空气挥" 视觉 bug)
	if _current_tool_kind() == "axe":
		var ax_tile: Vector2i = aim_tile_coord()
		var ax_terrain := _terrain()
		if ax_terrain == null:
			_reset_mining()
			return
		var ax_tid: int = ax_terrain.get_cell_source_id(ax_tile)
		if not _AXE_TARGETS.has(ax_tid):
			_reset_mining()
			return
	# 镐不能挖植物 (叶 / 仙人掌 / 火把). 用户改: "镐只破坏方块"
	if _current_tool_kind() == "pickaxe":
		var pk_tile: Vector2i = aim_tile_coord()
		var pk_terrain := _terrain()
		if pk_terrain != null:
			var pk_tid: int = pk_terrain.get_cell_source_id(pk_tile)
			if _PICKAXE_BLACKLIST.has(pk_tid):
				_reset_mining()
				return
	var tile: Vector2i = aim_tile_coord()
	if not in_reach(tile):
		_reset_mining()
		return
	var terrain := _terrain()
	if terrain == null:
		return
	var tid: int = terrain.get_cell_source_id(tile)
	if tid == -1 or not Tiles.is_mineable(tid):
		_reset_mining()
		return
	# 树支撑块保护: 正上方是"树底 LOG" → 这格在撑着树, 不许挖 (要砍树得砍树干; 别的方块照常)
	if not _TREE_PARTS.has(tid) and _blocks_support_tree(terrain.get_parent(), tile.x, tile.y):
		_reset_mining()
		return
	# 树部件特殊规则: 只有树底 LOG 能直接挖. LOG_TOP/BRANCH/ROOT 不能直接挖,
	# 中段 LOG 也不能 — 必须从最底下砍, 整棵爆.
	if _TREE_PARTS.has(tid):
		var world_node: Node = terrain.get_parent()
		if tid != Tiles.LOG or not _is_tree_base(world_node, tile.x, tile.y):
			_reset_mining()
			return
	var inv: Node = _inventory_node()
	var tool_kind: String = "" if inv == null else inv.current_tool_kind()
	var required: int = Tiles.required_tool_tier(tid, tool_kind)
	if required == -1:
		# 工具不对 → 永远挖不完，进度归零
		_reset_mining()
		_mining_target = tile
		return
	# 工具 tier 不够 → 也不行 (例如木镐挖铁矿)
	if _current_tool_tier() < required:
		_reset_mining()
		_mining_target = tile
		return
	if tile != _mining_target:
		# 切到新目标: 不清旧裂纹 (旧方块半挖状态保留显示), 读出新目标存档进度.
		_mining_target = tile
		var saved: Array = _mine_saved.get(tile, [])
		if saved.size() == 2 and saved[0] == tid:
			_mining_progress = saved[1]   # tid 对得上 → 续上次进度
		else:
			_mining_progress = 0.0        # 那格方块变了 / 没挖过 → 从头
			if saved.size() == 2:
				_clear_crack(tile)        # 清掉过期裂纹
				_mine_saved.erase(tile)
		_mining_swing_t = 0.0
	_mining_progress += _tool_speed(tool_kind, tid) * delta * _buff_mining_mul()
	_mine_saved[tile] = [tid, _mining_progress]   # 存进度: 松手/切目标后还在
	# 防字典无限涨: 半挖后走开不回来的格子会一直留着. 超 64 条丢最早一条 (不丢当前这格).
	if _mine_saved.size() > 64:
		var oldest: Vector2i = _mine_saved.keys()[0]
		if oldest != tile:
			_mine_saved.erase(oldest)
	# 镐 + 斧 (用户改: 斧跟镐同款): 360° 旋转动画 — 每 0.7s 重启一次
	# 其他 (徒手等): ±75° 来回挥 — 每 0.35s 挥一次
	_mining_swing_t -= delta
	if _mining_swing_t <= 0.0:
		var player_node: Node = get_parent()
		var held: Node = null if player_node == null else player_node.get_node_or_null("HeldItem")
		if tool_kind == "pickaxe" or tool_kind == "axe":
			_mining_swing_t = 0.7
			if held != null and held.has_method("play_pickaxe_attack"):
				_start_pickaxe_spin()
		else:
			_mining_swing_t = 0.35
			if held != null and held.has_method("play_swing"):
				held.play_swing()
	# 通知 CrackOverlay 当前进度
	var ratio: float = clamp(_mining_progress / _hardness(tid), 0.0, 1.0)
	_set_crack(tile, ratio)
	if _mining_progress >= _hardness(tid):
		_finish_mine(tile, tid, tool_kind, terrain)
		_clear_crack(tile)
		_mine_saved.erase(tile)   # 挖完了, 清这格存档
		_mining_target = INVALID_TILE
		_mining_progress = 0.0


func _reset_mining() -> void:
	# 松手 / 切走: 不清裂纹、不丢进度 — 半挖的方块进度存在 _mine_saved, 裂纹留着, 回来接着挖.
	_mining_target = INVALID_TILE
	_mining_progress = 0.0


# 锤子破墙. 瞄准格前景必须空 (墙在方块后面, 得先挖掉方块才能砸墙). 该格有墙才砸.
# 进度按 tier 加速; 砸完 → world._set_wall(AIR) + 掉对应墙料.
const WALL_HARDNESS := 1.5
func _update_wall_mining(delta: float) -> void:
	var tile: Vector2i = aim_tile_coord()
	if not in_reach(tile):
		_reset_mining()
		return
	var terrain := _terrain()
	if terrain == null:
		return
	var world: Node = terrain.get_parent()
	var cm = world.get("chunk_manager") if world != null else null
	if cm == null:
		_reset_mining()
		return
	# 前景有方块挡着 → 不能砸墙 (先挖方块)
	if terrain.get_cell_source_id(tile) != -1:
		_reset_mining()
		return
	var wid: int = cm.get_wall(tile.x, tile.y)
	if wid == Tiles.AIR:
		_reset_mining()
		return
	# 创造模式: 秒砸
	if GameSettings != null and GameSettings.creative_mode:
		_break_wall(world, tile, wid)
		_mining_target = INVALID_TILE
		_mining_progress = 0.0
		return
	if tile != _mining_target:
		_mining_target = tile
		_mining_progress = 0.0
		_mining_swing_t = 0.0
	_mining_progress += _hammer_speed(_current_tool_tier()) * delta * _buff_mining_mul()
	# 摆动: 复用镐子 360° 旋转
	_mining_swing_t -= delta
	if _mining_swing_t <= 0.0:
		_mining_swing_t = 0.7
		var held: Node = _held_item_node()
		if held != null and held.has_method("play_pickaxe_attack"):
			_start_pickaxe_spin()
	var ratio: float = clamp(_mining_progress / WALL_HARDNESS, 0.0, 1.0)
	_set_crack(tile, ratio)
	if _mining_progress >= WALL_HARDNESS:
		_break_wall(world, tile, wid)
		_clear_crack(tile)
		_mining_target = INVALID_TILE
		_mining_progress = 0.0


# 真正破墙: 改数据 (持久) + 碎裂特效 + 掉对应墙料.
func _break_wall(world: Node, tile: Vector2i, wid: int) -> void:
	world._set_wall(tile.x, tile.y, Tiles.AIR)
	Effects.spawn_block_break(tile, wid)
	SfxBank.play("break", 0.15)
	var drop_id: String = Tiles.wall_drop_item(wid)
	if drop_id != "":
		_spawn_drop(drop_id, tile)


# 锤子破墙速度 (硬度 1.5). tier 越高越快: tier1 ~1.5s → tier8 ~0.3s.
func _hammer_speed(tier: int) -> float:
	match tier:
		1: return 1.0    # 1.5s
		2: return 1.25   # 1.2s
		3: return 1.5    # 1.0s
		4: return 2.0    # 0.75s
		5: return 2.5    # 0.6s
		6: return 3.0    # 0.5s
		7: return 3.75   # 0.4s
		_: return 5.0    # 0.3s (tier 8 地狱)


func _set_crack(tile: Vector2i, ratio: float) -> void:
	var co: Node = _crack_overlay()
	if co != null:
		co.set_progress(tile, ratio)


func _clear_crack(tile: Vector2i) -> void:
	if tile == INVALID_TILE:
		return
	var co: Node = _crack_overlay()
	if co != null:
		co.clear(tile)


func _crack_overlay() -> Node:
	var terrain := _terrain()
	if terrain == null:
		return null
	var world: Node = terrain.get_parent()
	return world.get_node_or_null("CrackOverlay")


func _finish_mine(tile: Vector2i, tid: int, tool_kind: String, terrain: TileMapLayer) -> void:
	var world: Node = terrain.get_parent()
	# 对战房: 天然/竞技场地形挖不动, 只有玩家放下的格能挖 (挖掉后取消标记).
	if NetworkManager != null and NetworkManager.combat_enabled():
		var cm_pvp = world.get("chunk_manager") if world != null else null
		if cm_pvp != null and cm_pvp.has_method("is_pvp_placed"):
			if not cm_pvp.is_pvp_placed(tile):
				return
			cm_pvp.unmark_pvp_placed(tile)
	# 砍 LOG 时若是树底 (下方是地面而不是树) → 整棵爆掉
	if tid == Tiles.LOG and _is_tree_base(world, tile.x, tile.y):
		_cascade_chop_tree(world, tile, tool_kind)
		return
	# 砍门: 不管开/关, 找到整扇门 (上下连续的门 tile) 一起消, 只掉 1 个 door.
	# (门挨着玩家会自动开成 DOOR_OPEN, 所以挖的多半是开着的门 — 一并处理)
	if tid == Tiles.DOOR or tid == Tiles.DOOR_MID or tid == Tiles.DOOR_TOP or tid == Tiles.DOOR_OPEN:
		if world.has_method("_set_tile"):
			var yy: int = tile.y - 1
			while yy >= tile.y - 3 and _is_door_tile(world, tile.x, yy):   # 往上消
				world._set_tile(tile.x, yy, Tiles.AIR)
				yy -= 1
			yy = tile.y + 1
			while yy <= tile.y + 3 and _is_door_tile(world, tile.x, yy):   # 往下消
				world._set_tile(tile.x, yy, Tiles.AIR)
				yy += 1
		tid = Tiles.DOOR   # 改 tid → 下面掉落流程出 1 个 door (点击那格由通用流程消)
	# 砍 chest (4 个 tier 都一样行为): 内容物先撒出来 (不丢)
	if tid == Tiles.CHEST or tid == Tiles.GOLD_CHEST or tid == Tiles.DIAMOND_CHEST or tid == Tiles.SHADOW_CHEST:
		var contents: Array = ChestStorage.clear(tile)
		for s in contents:
			if s != null:
				for _i in s.count:
					_spawn_drop(s.item_id, tile)
		# 如果该 chest 当前是开着的 (chest_panel.is_open + 同 tile), 关掉 — 防"幽灵箱面板".
		var chest_p3: CanvasLayer = get_tree().get_first_node_in_group("chest_panel")
		if chest_p3 == null:
			chest_p3 = get_tree().root.find_child("ChestPanel", true, false)
		if chest_p3 != null and chest_p3.has_method("is_open") and chest_p3.is_open():
			if "_chest_tile" in chest_p3 and chest_p3._chest_tile == tile:
				chest_p3.close()
	# 砍 mimic_chest: 触发陷阱 (爆炸 + 弹出 Mimic), 跳过普通破方块流程
	if tid == Tiles.MIMIC_CHEST:
		_trigger_mimic_trap(tile, world)
		return
	# 砍床: 2 格宽 (BED 左 + BED_RIGHT 右). 砍任一半 → 联动消另一半 + 清复活点 + 只掉 1 床.
	# (清复活点防老 bug: 不清的话复活时还指着已变空气的床位置, 玩家从天上掉下)
	if tid == Tiles.BED or tid == Tiles.BED_RIGHT:
		var bcm = world.get("chunk_manager")
		if world.has_method("_set_tile") and bcm != null:
			# 左砍消右 (x+1); 右砍消左 (x-1). 先确认那格真是另一半再消 (防误删邻居).
			if tid == Tiles.BED and bcm.get_tile(tile.x + 1, tile.y) == Tiles.BED_RIGHT:
				world._set_tile(tile.x + 1, tile.y, Tiles.AIR)
			elif tid == Tiles.BED_RIGHT and bcm.get_tile(tile.x - 1, tile.y) == Tiles.BED:
				world._set_tile(tile.x - 1, tile.y, Tiles.AIR)
		if "bed_spawn_point" in world:
			world.bed_spawn_point = Vector2i(-99999, -99999)
		tid = Tiles.BED   # 改 tid → 掉落流程出 1 个 bed (点击那格由通用流程消)
	# 普通破: 单格
	if world.has_method("_set_tile"):
		world._set_tile(tile.x, tile.y, Tiles.AIR)
	SkyLightGrid.invalidate_column(tile.x)
	Effects.spawn_block_break(tile, tid)
	SfxBank.play("break", 0.15)
	var drops: Dictionary = Tiles.drops_for(tid, tool_kind)
	for item_id in drops:
		for _i in drops[item_id]:
			_spawn_drop(item_id, tile)
	# 草/植物联动: 挖掉这格后, 上方失去支撑的小草/植物也一起破坏 (+掉自己的东西)
	_drop_unsupported_plants_above(world, tile, tool_kind)


# (x,y) 是不是在撑着一棵树: 正上方是"树底 LOG". 是的话这格不许挖.
func _blocks_support_tree(world: Node, x: int, y: int) -> bool:
	var cm = world.get("chunk_manager")
	if cm == null:
		return false
	if cm.get_tile(x, y - 1) != Tiles.LOG:
		return false
	return _is_tree_base(world, x, y - 1)


# 挖掉 (tile) 后, 上方失去支撑的小草/植物联动消除 + 掉落. 仙人掌可叠 → 往上连消.
func _drop_unsupported_plants_above(world: Node, tile: Vector2i, tool_kind: String) -> void:
	var cm = world.get("chunk_manager")
	if cm == null or not world.has_method("_set_tile"):
		return
	var y: int = tile.y - 1
	while _PLANT_NEEDS_GROUND.has(cm.get_tile(tile.x, y)):
		var ptid: int = cm.get_tile(tile.x, y)
		world._set_tile(tile.x, y, Tiles.AIR)
		Effects.spawn_block_break(Vector2i(tile.x, y), ptid)
		var pdrops: Dictionary = Tiles.drops_for(ptid, tool_kind)
		for item_id in pdrops:
			for _i in pdrops[item_id]:
				_spawn_drop(item_id, Vector2i(tile.x, y))
		y -= 1


# 放置消耗 1 个: 创造模式不消耗 (无限方块); 对战房也不消耗 (消耗品无限); 否则正常扣库存.
func _consume_one(inv: Node) -> void:
	if GameSettings != null and GameSettings.creative_mode:
		return
	if NetworkManager != null and NetworkManager.combat_enabled():
		return   # 对战房: 方块/消耗品无限
	inv.consume_current(1)


# 对战房: 标记"这格是玩家放的" (天然/竞技场地形不标 → 挖不动; 玩家放的才能挖)
func _pvp_mark_placed(world: Node, c: Vector2i) -> void:
	if NetworkManager == null or not NetworkManager.combat_enabled():
		return
	var cm = world.get("chunk_manager") if world != null else null
	if cm != null and cm.has_method("mark_pvp_placed"):
		cm.mark_pvp_placed(c)


# 这格是不是门的一部分 (底/中/顶/开). 砍门时往上下扫连续门 tile 用.
func _is_door_tile(world: Node, x: int, y: int) -> bool:
	var cm = world.get("chunk_manager")
	if cm == null:
		return false
	var t: int = cm.get_tile(x, y)
	return t == Tiles.DOOR or t == Tiles.DOOR_MID or t == Tiles.DOOR_TOP or t == Tiles.DOOR_OPEN


# 树底 = 下面那格不属于树自身的部件. 其他都算 (grass/dirt/AIR/stone/glass 等).
# AIR 也允许 (玩家挖掉了树下方的地基 → 树悬空, 仍是树底可整棵砍).
func _is_tree_base(world: Node, x: int, y: int) -> bool:
	var cm = world.get("chunk_manager")
	if cm == null:
		return false
	var below: int = cm.get_tile(x, y + 1)
	if _TREE_PARTS.has(below):
		return false
	if below == Tiles.LEAVES:
		return false   # 叶子在底下太怪 (玩家自建除外), 暂不视为底
	return true


# 从树底沿树干向上集齐所有 LOG/LOG_TOP/BRANCH/ROOT 和上方的叶子, 一并破掉 + 集中掉物
func _cascade_chop_tree(world: Node, base: Vector2i, tool_kind: String) -> void:
	var cm = world.get("chunk_manager")
	if cm == null:
		return
	# 联机: 把 30+ tile 变化打包一条消息 (防小消息冲爆 PeerJS buffer)
	if world.has_method("begin_tile_batch"):
		world.begin_tile_batch()
	_do_cascade_chop(world, cm, base, tool_kind)
	if world.has_method("end_tile_batch"):
		world.end_tile_batch()


func _do_cascade_chop(world: Node, cm, base: Vector2i, tool_kind: String) -> void:
	# 沿 x 列向上走树干 (LOG → LOG_TOP)
	var trunk_top_y: int = base.y
	var ty: int = base.y
	while ty >= 0:
		var t: int = cm.get_tile(base.x, ty)
		if t == Tiles.LOG:
			trunk_top_y = ty
			ty -= 1
			continue
		if t == Tiles.LOG_TOP:
			trunk_top_y = ty
			break
		break
	# 收集要破的 tile: trunk + ROOT/BRANCH 在每个 y 的左右 + canopy 叶子
	var to_break: Array = []
	for cy in range(trunk_top_y, base.y + 1):
		var t: int = cm.get_tile(base.x, cy)
		if _TREE_PARTS.has(t):
			to_break.append([Vector2i(base.x, cy), t])
		for dx in [-1, 1]:
			var ts: int = cm.get_tile(base.x + dx, cy)
			if _TREE_PARTS.has(ts):
				to_break.append([Vector2i(base.x + dx, cy), ts])
	# canopy 叶子: LOG_TOP 上方 ±3 x, [trunk_top - 6, trunk_top + 1] y 内的 LEAVES
	for cy in range(trunk_top_y - 6, trunk_top_y + 2):
		for dx in range(-3, 4):
			var tx: int = base.x + dx
			var t: int = cm.get_tile(tx, cy)
			if t == Tiles.LEAVES:
				to_break.append([Vector2i(tx, cy), t])
	# 破并掉物
	for entry in to_break:
		var p: Vector2i = entry[0]
		var t: int = entry[1]
		world._set_tile(p.x, p.y, Tiles.AIR)
		Effects.spawn_block_break(p, t)
		var drops: Dictionary = Tiles.drops_for(t, tool_kind)
		for item_id in drops:
			for _i in drops[item_id]:
				_spawn_drop(item_id, p)
	SkyLightGrid.invalidate_column(base.x)
	SfxBank.play("break", 0.25)


func _spawn_drop(item_id: String, tile: Vector2i) -> void:
	var pos := Vector2(
		tile.x * TILE_SIZE + TILE_SIZE / 2.0 + randf_range(-3.0, 3.0),
		tile.y * TILE_SIZE + TILE_SIZE / 2.0
	)
	# 联机 client: 掉落交 host 权威生成 (host 再广播回两边), 否则本地刷出 host 看不到的孤儿掉落
	if NetworkManager != null and NetworkManager.connected() and not NetworkManager.is_host:
		NetworkManager.send_drop_request(item_id, 1, pos.x, pos.y)
		return
	var drop = ItemDropScene.instantiate()
	drop.item_id = item_id
	drop.count = 1
	drop.global_position = pos
	var entities: Node = get_tree().get_first_node_in_group("entities_root")
	if entities == null:
		entities = get_parent().get_parent()
	entities.add_child(drop)


# 返回 true 表示成功放置 (用于测试断言)
func try_place() -> bool:
	var terrain := _terrain()
	var inv: Node = _inventory_node()
	if terrain == null or inv == null:
		return false
	var slot: Variant = inv.current_hotbar_slot()
	if slot == null:
		return false
	if not ItemDB.is_placeable(slot.item_id):
		return false
	var tile: Vector2i = aim_tile_coord()
	if not in_reach(tile):
		return false
	# === 墙 (wall item): 走 world._set_wall (持久化 + autotile + 存档), 不挡走路 ===
	if ItemDB.is_wall(slot.item_id):
		var w_node: Node = terrain.get_parent()
		var cm = w_node.get("chunk_manager") if w_node != null else null
		if cm == null or not w_node.has_method("_set_wall"):
			return false
		# 已经有墙 → 不重叠放
		if cm.get_wall(tile.x, tile.y) != Tiles.AIR:
			return false
		var w_def = ItemDB.get_def(slot.item_id)
		w_node._set_wall(tile.x, tile.y, w_def.placeable_tile_id)
		_consume_one(inv)
		Effects.spawn_place_bounce(tile, w_def.placeable_tile_id)
		SfxBank.play("place", 0.10)
		return true
	# 目标必须为空气 (或水, 水可以被填掉 — 玩家用方块塞水)
	var target_src: int = terrain.get_cell_source_id(tile)
	var is_water: bool = Tiles.is_water(target_src)
	if target_src != -1 and not is_water:
		return false
	# 不与玩家碰撞框重叠（玩家占 2 tile 高：脚底 tile 和上方 tile）
	var pt: Vector2i = player_tile()
	if tile == pt or tile == pt - Vector2i(0, 1):
		return false
	# 支撑判定: 上下左右至少有 1 个相邻"实心方块"才能放 (防隔空放)。
	# 背景墙不算支撑 — 这世界背景墙铺满, 算的话处处能放就没意义了。创造模式随处放。
	var has_support: bool = GameSettings != null and GameSettings.creative_mode
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if terrain.get_cell_source_id(tile + offset) != -1:
			has_support = true
			break
	if not has_support:
		return false
	var def = ItemDB.get_def(slot.item_id)
	var world: Node = terrain.get_parent()
	# 门: 3 格高, 占当前 tile + 上面 2 格. 上面 2 格必须空, 否则放不了.
	if def.placeable_tile_id == Tiles.DOOR:
		var mid: Vector2i = tile + Vector2i(0, -1)
		var top: Vector2i = tile + Vector2i(0, -2)
		if terrain.get_cell_source_id(mid) != -1 or terrain.get_cell_source_id(top) != -1:
			return false
		# 别把门的 3 格 (底/中/顶) 盖进玩家身体 (玩家 2.5 格高占 pt..pt-2): 同列且 y 差≤2 就挡
		if tile.x == pt.x and absi(tile.y - pt.y) <= 2:
			return false
		if world.has_method("_set_tile"):
			world._set_tile(tile.x, tile.y, Tiles.DOOR)        # 底
			world._set_tile(mid.x, mid.y, Tiles.DOOR_MID)      # 中
			world._set_tile(top.x, top.y, Tiles.DOOR_TOP)      # 顶
		_pvp_mark_placed(world, tile)
		_pvp_mark_placed(world, mid)
		_pvp_mark_placed(world, top)
		_consume_one(inv)
		SkyLightGrid.invalidate_column(tile.x)
		Effects.spawn_place_bounce(tile, Tiles.DOOR)
		SfxBank.play("place", 0.10)
		return true
	# 床: 2 格宽, 占当前 tile (左/床头) + 右边 1 格 (右/床尾). 右格必须空 (或水), 否则放不了.
	if def.placeable_tile_id == Tiles.BED:
		var bed_right: Vector2i = tile + Vector2i(1, 0)
		var br_src: int = terrain.get_cell_source_id(bed_right)
		if br_src != -1 and not Tiles.is_water(br_src):
			return false
		if world.has_method("_set_tile"):
			world._set_tile(tile.x, tile.y, Tiles.BED)                  # 左 (床头, 锚点)
			world._set_tile(bed_right.x, bed_right.y, Tiles.BED_RIGHT)  # 右 (床尾)
		_pvp_mark_placed(world, tile)
		_pvp_mark_placed(world, bed_right)
		_consume_one(inv)
		SkyLightGrid.invalidate_column(tile.x)
		SkyLightGrid.invalidate_column(bed_right.x)
		Effects.spawn_place_bounce(tile, Tiles.BED)
		SfxBank.play("place", 0.10)
		return true
	# 铁锅只能叠在炉子正上方 (用户设计: "锅放在炉子上才能煮")
	if slot.item_id == "cooking_pot":
		var below_pot: Vector2i = tile + Vector2i(0, 1)
		if terrain.get_cell_source_id(below_pot) != Tiles.FURNACE:
			SfxBank.play("place", 0.05)   # 轻提示: 放不上去
			return false
	# (移除 terrain.set_cell; world._set_tile 内部刷视觉 + 邻居)
	if world.has_method("_set_tile"):
		world._set_tile(tile.x, tile.y, def.placeable_tile_id)
	_pvp_mark_placed(world, tile)   # 对战房: 记为"玩家放的" → 可挖
	_consume_one(inv)
	SkyLightGrid.invalidate_column(tile.x)
	# P1.5 hook: 放下弹动
	Effects.spawn_place_bounce(tile, def.placeable_tile_id)
	SfxBank.play("place", 0.10)
	return true


# ---- Helpers ----

func _hardness(tid: int) -> float:
	return _HARDNESS.get(tid, 0.5)


func _tool_speed(tool_kind: String, tid: int) -> float:
	# 斧砍 LOG: 7 tier 进阶 (用户改: 整体慢 1.5×, wood 9s, diamond 0.9s)
	# 实际时间 = 硬度 0.6s / speed.
	if tool_kind == "axe" and tid == Tiles.LOG:
		var tier := _current_tool_tier()
		match tier:
			1: return 0.0667  # wood   - 9.0s
			2: return 0.10    # stone  - 6.0s
			3: return 0.133   # copper - 4.5s
			4: return 0.20    # iron   - 3.0s
			5: return 0.267   # silver - 2.25s
			6: return 0.40    # gold   - 1.5s
			7: return 0.667   # diamond - 0.9s
			_: return 1.0     # hell tier 8+ - 0.6s
	# 镐挖 石/深石/矿石: 7 tier 进阶 (用户调: wood 3s 不变, 顶级慢下来到 0.6s)
	# 硬度 3.0s base. 速度 = 3.0 / 想要时间.
	if tool_kind == "pickaxe" and _PICKAXE_STONE_LIKE.has(tid):
		var tier := _current_tool_tier()
		match tier:
			1: return 1.0   # wood    - 3.0s
			2: return 1.2   # stone   - 2.5s
			3: return 1.5   # copper  - 2.0s
			4: return 2.0   # iron    - 1.5s
			5: return 2.5   # silver  - 1.2s
			6: return 3.33  # gold    - 0.9s
			7: return 5.0   # diamond - 0.6s
			_: return 7.5   # hell tier 8+ - 0.4s
	return 1.0


func aim_tile_coord() -> Vector2i:
	if aim_override != null:
		return aim_override as Vector2i
	var terrain := _terrain()
	if terrain == null:
		return INVALID_TILE
	var mouse_world: Vector2 = terrain.get_global_mouse_position()
	return terrain.local_to_map(terrain.to_local(mouse_world))


func _terrain() -> TileMapLayer:
	return get_tree().get_first_node_in_group("terrain_layer") as TileMapLayer


func _current_tool_kind() -> String:
	var inv: Node = _inventory_node()
	return "" if inv == null else inv.current_tool_kind()


func _current_tool_def() -> Variant:
	var inv: Node = _inventory_node()
	if inv == null:
		return null
	var slot = inv.current_hotbar_slot()
	if slot == null:
		return null
	return ItemDB.get_def(slot.item_id)


# 工具的攻击倍率 (剑=1.0, 镐=0.5, 斧=0.0, 其他=0.0). 用 dict get 兜底防旧档.
func _tool_damage_mult() -> float:
	var def = _current_tool_def()
	if def == null:
		return 0.0
	return def.get("damage_mult", 0.0)


# 击退强度 (阶段 2): 按工具 + tier 缩放
const KB_THRUST_BASE := 45.0
const KB_THRUST_TIER := 11.0
const KB_SWEEP_BASE := 60.0
const KB_SWEEP_TIER := 15.0
const KB_PICKAXE_BASE := 22.0
const KB_PICKAXE_TIER := 6.0


func _thrust_knockback() -> float:
	return KB_THRUST_BASE + KB_THRUST_TIER * float(_current_tool_tier())


func _sweep_knockback() -> float:
	return KB_SWEEP_BASE + KB_SWEEP_TIER * float(_current_tool_tier())


func _pickaxe_knockback() -> float:
	return KB_PICKAXE_BASE + KB_PICKAXE_TIER * float(_current_tool_tier())


# 用户改: 武器基础伤害按 tier 1-7 递进, 加速曲线 (钻剑 1 击僵尸 15HP).
# 老公式是 tier 1 → 3, tier 2+ 全 5 (卡 tier 2). 新公式每代都长.
# 史莱姆 10HP / 僵尸 15HP. 钻剑 20 → 1 击.
const _TIER_BASE_DAMAGE := [0, 3, 5, 7, 10, 13, 16, 20, 26]  # index = tier (8 = 地狱)


# 共享 tier→base 伤害表 (剑 ×1.0, 镐 ×0.5, 斧 ×0.0). 通过 _tool_damage_mult 缩放.
func _base_damage_for_tier(tier: int) -> int:
	if tier < 1 or tier >= _TIER_BASE_DAMAGE.size():
		return 0
	return _TIER_BASE_DAMAGE[tier]


func _sword_damage() -> int:
	var inv: Node = _inventory_node()
	if inv == null:
		return 0
	var slot = inv.current_hotbar_slot()
	if slot == null:
		return 0
	var def = ItemDB.get_def(slot.item_id)
	if def == null or def.tool_kind != "sword":
		return 0
	return _base_damage_for_tier(def.tool_tier)


func _current_tool_tier() -> int:
	var inv: Node = _inventory_node()
	if inv == null:
		return 0
	var slot = inv.current_hotbar_slot()
	if slot == null:
		return 0
	var def = ItemDB.get_def(slot.item_id)
	if def == null:
		return 0
	return def.tool_tier


# 当前手持剑该戳还是扫: 读 item 的 sword_style. 短剑=thrust(戳), 阔剑=sweep(扫).
# 老存档/没标 sword_style 的剑 → 按老规则 tier<=2 戳兜底 (不崩).
func _current_sword_style_is_thrust() -> bool:
	var inv: Node = _inventory_node()
	if inv == null:
		return false
	var slot = inv.current_hotbar_slot()
	if slot == null:
		return false
	var style: String = ItemDB.sword_style(slot.item_id)
	if style == "thrust":
		return true
	if style == "sweep":
		return false
	return _current_tool_tier() <= 2   # 兜底


func _effective_sword_damage() -> int:
	var base: int = _sword_damage()
	if base <= 0:
		return 0
	var dmg_mult: float = _tool_damage_mult()
	if dmg_mult <= 0.0:
		return 0
	return max(1, int(round(float(base) * dmg_mult)))


const PLACE_HOLD_INTERVAL := 0.05   # 连续放置时每隔多久放一个 (按住右键)
var _place_hold_cd: float = 0.0


func _update_eat_or_place(delta: float) -> void:
	# 优先级: place_override (测试) → 进食 → 放置
	if place_override:
		if try_place():
			_play_place_anim()   # 放方块: 朝放置点按一下的动画
		place_override = false
		return

	# 右键或 F 键都能吃 (F 给 Mac 触摸板用户的备选)
	var held: bool
	var just: bool
	if secondary_held_override != null:
		held = (secondary_held_override == true)
		just = false
	else:
		var f_now: bool = Input.is_key_pressed(KEY_F)
		# F 键边缘检测: 上一帧没按, 这一帧按了 = just. 老 bug 用 is_key_pressed 当 just → 持续按 F 时
		# 每帧 just=true 导致钩爪连发/种子连种/床 sleep_in_bed 重复重置 anchor 永不醒.
		var f_just: bool = f_now and not _f_was_pressed
		_f_was_pressed = f_now
		held = Input.is_action_pressed("secondary") or f_now
		just = Input.is_action_just_pressed("secondary") or f_just

	var inv: Node = _inventory_node()
	var slot = null if inv == null else inv.current_hotbar_slot()
	var holding_food: bool = slot != null and ItemDB.is_food(slot.item_id)
	# 饱食度已删, 食物直接 PlayerHealth.heal(food_fill). 只有血未满才能吃.
	var hp: Node = get_parent().get_node_or_null("PlayerHealth")

	# 持钩爪 + 右键刚按下 → 朝鼠标发射钩爪 (玩家拉过去)
	if slot != null and slot.item_id == "grappling_hook" and just:
		var player_node: Node = get_parent()
		if player_node != null and player_node.has_method("fire_grappling_hook"):
			player_node.fire_grappling_hook(player_node.get_global_mouse_position())
		return

	# 持鱼竿 + 右键刚按下 → 甩竿 / 收竿 (交给 PlayerFishing 按状态决定)
	if slot != null and slot.item_id == "fishing_rod" and just:
		try_fishing_click()
		return

	# 持召唤道具 (史莱姆王冠) + 右键刚按下 → 召唤 Boss
	if slot != null and ItemDB.is_summon(slot.item_id) and just:
		try_use_summon_item()
		return

	# 持小麦种子 + 右键刚按下 → 鼠标对准 GRASS 上方 AIR → 种 WHEAT_0
	if slot != null and slot.item_id == "wheat_seed" and just:
		var terrain_s := _terrain()
		var aim_t: Vector2i = aim_tile_coord()
		if terrain_s != null and in_reach(aim_t):
			var aim_id: int = terrain_s.get_cell_source_id(aim_t)
			var below: Vector2i = aim_t + Vector2i(0, 1)
			var below_id: int = terrain_s.get_cell_source_id(below)
			# 条件: aim 是 AIR (空气), 下面是 GRASS (草地)
			if aim_id == -1 and below_id == Tiles.GRASS:
				var w_node_s: Node = terrain_s.get_parent()
				if w_node_s != null and w_node_s.has_method("_set_tile"):
					w_node_s._set_tile(aim_t.x, aim_t.y, Tiles.WHEAT_0)
					inv.consume_current(1)
					SfxBank.play("place", 0.10)
		return

	# 持稻种 + 右键刚按下 → 草地上方 AIR → 种 RICE_0 (跟小麦一样)
	if slot != null and slot.item_id == "rice_seed" and just:
		var terrain_r := _terrain()
		var aim_r: Vector2i = aim_tile_coord()
		if terrain_r != null and in_reach(aim_r):
			var aim_ir: int = terrain_r.get_cell_source_id(aim_r)
			var below_r: Vector2i = aim_r + Vector2i(0, 1)
			var below_ir: int = terrain_r.get_cell_source_id(below_r)
			if aim_ir == -1 and below_ir == Tiles.GRASS:
				var w_node_r: Node = terrain_r.get_parent()
				if w_node_r != null and w_node_r.has_method("_set_tile"):
					w_node_r._set_tile(aim_r.x, aim_r.y, Tiles.RICE_0)
					inv.consume_current(1)
					SfxBank.play("place", 0.10)
		return

	# 右键刚按下 + 鼠标对准的 tile 是 CHEST/GOLD_CHEST/DIAMOND_CHEST → 开箱
	# (MIMIC_CHEST 走陷阱分支)
	if just:
		var aim_tile: Vector2i = aim_tile_coord()
		if in_reach(aim_tile):
			var terrain := _terrain()
			if terrain != null:
				var aim_tid: int = terrain.get_cell_source_id(aim_tile)
				if aim_tid == Tiles.CHEST or aim_tid == Tiles.GOLD_CHEST or aim_tid == Tiles.DIAMOND_CHEST or aim_tid == Tiles.SHADOW_CHEST:
					var cp: CanvasLayer = get_tree().get_first_node_in_group("chest_panel")
					if cp == null:
						cp = get_tree().root.find_child("ChestPanel", true, false)
					if cp != null and cp.has_method("open"):
						cp.open(aim_tile, inv)
					return
				elif aim_tid == Tiles.MIMIC_CHEST:
					# 玩家以为是宝箱, 实际是陷阱: 爆炸 + 弹 mimic
					_trigger_mimic_trap(aim_tile, terrain.get_parent())
					return
				elif aim_tid == Tiles.LIFE_CRYSTAL:
					# 生命水晶: 右键吃 → 永久 +20 MAX HP + 同量当前回血 + 消失.
					# 已达 400 上限时不消耗 (避免误吃浪费).
					if hp != null and hp.has_method("try_extend_max"):
						if hp.try_extend_max():
							_consume_crystal_tile(aim_tile, terrain, Color(1.0, 0.4, 0.6))
					return
				elif aim_tid == Tiles.MANA_CRYSTAL:
					# 魔力水晶: 右键吃 → 永久 +20 MAX MANA + 同量当前回魔 + 消失.
					# 已达 200 上限时不消耗.
					var mn: Node = get_parent().get_node_or_null("PlayerMana")
					if mn != null and mn.has_method("try_extend_max"):
						if mn.try_extend_max():
							_consume_crystal_tile(aim_tile, terrain, Color(0.55, 0.45, 1.0))
					return
				elif aim_tid == Tiles.BED or aim_tid == Tiles.BED_RIGHT:
					# 床 (2 格宽): 点任一半都能睡. 锚点归一到左格 (BED), 让玩家躺床中央.
					var bed_anchor: Vector2i = aim_tile
					if aim_tid == Tiles.BED_RIGHT:
						bed_anchor = aim_tile - Vector2i(1, 0)   # 点右半 → 用左格做锚
					var w: Node = terrain.get_parent()
					if w != null and w.has_method("sleep_in_bed"):
						w.sleep_in_bed(bed_anchor)
					return

	# 持魔力药水 + 按住 → 喝下立刻 +30 mana (跟食物同流程, 进度条满后消耗)
	var holding_potion: bool = slot != null and ItemDB.is_mana_potion(slot.item_id)
	var mana_node: Node = get_parent().get_node_or_null("PlayerMana")
	if holding_potion and held and mana_node != null:
		# 满蓝不让喝 (防误点浪费, 跟食物满血不让吃一致)
		if mana_node.current_mana >= mana_node.MAX_MANA:
			if _eat_item_id != "":
				_eat_item_id = ""
				_eat_t = 0.0
				_stop_eat_anim()
			return
		if _eat_item_id != slot.item_id:
			_eat_item_id = slot.item_id
			_eat_t = 0.0
			_start_eat_anim()
		_eat_t += delta
		if _eat_t >= EAT_DURATION_SEC:
			_eat_t = 0.0
			var refill: int = ItemDB.mana_refill(slot.item_id)
			mana_node.current_mana = min(mana_node.MAX_MANA, mana_node.current_mana + refill)
			if mana_node.has_signal("mana_changed"):
				mana_node.mana_changed.emit(mana_node.current_mana, mana_node.MAX_MANA)
			SfxBank.play("eat", 0.10)
			if NetworkManager == null or not NetworkManager.combat_enabled():
				inv.consume_current(1)   # 对战房: 药水无限
			_stop_eat_anim()
		return

	# 持食物 + 按住 → 进入/保持 eating. 食物 food_fill 现在直接当回血量.
	# 普通食物满血不让吃 (防误点浪费); 带 buff 的料理满血也能吃 (为拿 buff).
	if holding_food and held and hp != null:
		var has_buff: bool = ItemDB.food_has_buff(slot.item_id)
		if hp.current_health >= hp.MAX_HEALTH and not has_buff:
			# 满血 + 无 buff: 中断进食状态, 不消耗食物
			if _eat_item_id != "":
				_eat_item_id = ""
				_eat_t = 0.0
				_stop_eat_anim()
			return
		if _eat_item_id != slot.item_id:
			_eat_item_id = slot.item_id
			_eat_t = 0.0
			_start_eat_anim()
		_eat_t += delta
		if _eat_t >= EAT_DURATION_SEC:
			_eat_t = 0.0
			hp.heal(ItemDB.food_fill(slot.item_id))
			# 料理 buff: 吃完触发临时增益
			if has_buff:
				var buffs: Node = get_parent().get_node_or_null("PlayerBuffs")
				if buffs != null:
					buffs.apply(ItemDB.food_buff_kind(slot.item_id), ItemDB.food_buff_secs(slot.item_id))
			SfxBank.play("eat", 0.10)
			if NetworkManager == null or not NetworkManager.combat_enabled():
				inv.consume_current(1)   # 对战房: 食物/生命药水无限
			_stop_eat_anim()  # 吃完一口, 下次按住会重新开始
		return

	# 取消进食 (松开 / 没食物 / 满血)
	if _eat_t > 0.0:
		_eat_t = 0.0
		_eat_item_id = ""
		_stop_eat_anim()

	# 放置: 单击放一个; "连续放置"设置开 + 按住右键 → 隔一小段连续放
	_place_hold_cd = max(0.0, _place_hold_cd - delta)
	if just:
		if try_place():
			_play_place_anim()
		_place_hold_cd = PLACE_HOLD_INTERVAL   # 刚放完, 按住的连放等一个间隔再开始
	elif held and _place_hold_cd <= 0.0 and GameSettings != null and GameSettings.continuous_place:
		if try_place():
			_play_place_anim()
		_place_hold_cd = PLACE_HOLD_INTERVAL   # 放方块: 朝放置点按一下的动画


# 进食动画: 食物在玩家手里 上下抖动 + 微微旋转, 像在啃咬
func _start_eat_anim() -> void:
	var held = _held_item_node()
	if held != null and held.has_method("start_eat"):
		held.start_eat()


func _stop_eat_anim() -> void:
	var held = _held_item_node()
	if held != null and held.has_method("stop_eat"):
		held.stop_eat()


func _held_item_node() -> Node:
	var player_node: Node = get_parent()
	if player_node == null:
		return null
	return player_node.get_node_or_null("HeldItem")


# 让手持物品短暂"闪一下"显示 (射箭/施法/投掷等没专门动画的"使用"). 工具只在使用时显示.
func _flash_held() -> void:
	var held: Node = _held_item_node()
	if held != null and held.has_method("flash"):
		held.flash()


# 枪: 显示 + 整把朝鼠标方向 (枪面向鼠标). 没有 aim_gun 方法就退回 flash.
func _aim_held_at_mouse() -> void:
	var held: Node = _held_item_node()
	if held == null:
		return
	var parent: Node2D = get_parent() as Node2D
	if parent == null or not held.has_method("aim_gun"):
		if held.has_method("flash"):
			held.flash()
		return
	var hand: Vector2 = parent.global_position + Vector2(0, -8)
	var target: Vector2 = mouse_world_override if mouse_world_override != null else parent.get_global_mouse_position()
	var angle: float = (target - hand).angle() if hand.distance_to(target) > 0.01 else 0.0
	held.aim_gun(angle)


# 放方块动画: 手里的方块朝放置点"按"出去一下 (方块也只在使用时显示).
func _play_place_anim() -> void:
	var held: Node = _held_item_node()
	if held == null or not held.has_method("play_place"):
		return
	var player := get_parent() as Node2D
	if player == null:
		return
	var tile: Vector2i = aim_tile_coord()
	var ang: float
	if tile == INVALID_TILE:
		ang = 0.0 if _facing_right_guess() else PI   # 没瞄准就朝面对方向
	else:
		var tc := Vector2((tile.x + 0.5) * TILE_SIZE, (tile.y + 0.5) * TILE_SIZE)
		ang = (tc - player.global_position).angle()
	held.play_place(ang)


# 玩家当前面朝 (放方块动画兜底用): 看 sprite scale.x 正负
func _facing_right_guess() -> bool:
	var player := get_parent() as Node2D
	if player == null:
		return true
	var spr = player.get_node_or_null("AnimatedSprite2D")
	return spr == null or spr.scale.x >= 0.0


# 挥的弧度: 前方 ±45° = 总 90° 弧
const SWEEP_ARC_HALF_DEG := 90.0  # 用户改: 半圆挥 180° (Terraria 风), 老 90° 弧
# 镐攻击的常量
# cooldown = spin 时长 — 一次完整旋转后才能再攻击 (用户改 0.7→1.0 同步慢)
const PICKAXE_ATTACK_COOLDOWN := 1.0
const PICKAXE_MOUSE_NEAR_RADIUS_MULT := 1.5  # 触发判定圆心 = 鼠标位置


# 鼠标对准的 tile 是否可挖 (用来决定镐走挖矿模式还是攻击模式)
func _mouse_on_mineable_tile() -> bool:
	var tile: Vector2i = aim_tile_coord()
	var terrain := _terrain()
	if terrain == null:
		return false
	var tid: int = terrain.get_cell_source_id(tile)
	if tid == -1 or not Tiles.is_mineable(tid):
		return false
	# 持镐对准镐挖不动的植物 (叶/仙人掌/火把/小草) → 不算"可挖", 让左键落到攻击模式
	# (否则镐进挖矿分支却啥也挖不动, 旁边有怪也打不到 = 卡住)
	if _current_tool_kind() == "pickaxe" and _PICKAXE_BLACKLIST.has(tid):
		return false
	return true


# 鼠标对的 tile 是不是斧能砍的目标 (LOG / 仙人掌). 用来分发斧的"砍" vs "空挥"
func _mouse_on_log() -> bool:
	var tile: Vector2i = aim_tile_coord()
	var terrain := _terrain()
	if terrain == null:
		return false
	return _AXE_TARGETS.has(terrain.get_cell_source_id(tile))


# 鼠标位置周围 SWORD_RANGE_PX * 1.5 半径内是否有可攻击目标
func _mouse_has_enemy_nearby() -> bool:
	var player: Node2D = get_parent() as Node2D
	if player == null:
		return false
	var mouse_world: Vector2 = mouse_world_override if mouse_world_override != null else player.get_global_mouse_position()
	var radius: float = SWORD_RANGE_PX * PICKAXE_MOUSE_NEAR_RADIUS_MULT
	for group in ["slimes", "animals"]:
		for s in get_tree().get_nodes_in_group(group):
			var sn := s as Node2D
			if sn != null and mouse_world.distance_to(sn.global_position) <= radius:
				return true
	return false


# 镐基础伤害: 跟 _sword_damage 同 tier 表, 后面 _tool_damage_mult ×0.5 缩放.
# (老公式 tier ≥ 2 → 5, else 3 已淘汰 — 新表 7 tier 都不同.)
func _pickaxe_base_damage() -> int:
	var def = _current_tool_def()
	if def == null:
		return 0
	if def.tool_kind != "pickaxe":
		return 0
	return _base_damage_for_tier(def.tool_tier)


# 镐攻击: 触发 360° spin. 伤害判定不再 AoE — 走 _check_pickaxe_spin_hits
# 每帧检查 pickaxe tip 是否碰到怪 (用户改: "怪要碰到镐子才扣血").
func _pickaxe_attack() -> void:
	_attack_cooldown = PICKAXE_ATTACK_COOLDOWN
	var player: Node2D = get_parent() as Node2D
	if player == null:
		return
	_start_pickaxe_spin()
	_pickaxe_spin_damages = true   # 这是"攻击"(鼠标对着怪不是方块), spin 才扣血
	SfxBank.play("swing", 0.10)
	if player.has_method("shake"):
		player.shake(2.0)


# 斧挥: 跟镐 _pickaxe_attack 同套路, 走 spin + collision. 但 damage_mult=0 自动
# 让 _check_pickaxe_spin_hits 跳过扣血 (return early). 纯视觉动作.
func _axe_swing() -> void:
	_attack_cooldown = PICKAXE_ATTACK_COOLDOWN
	var player: Node2D = get_parent() as Node2D
	if player == null:
		return
	_start_pickaxe_spin()
	SfxBank.play("swing", 0.10)


# 开始一次 360° 旋转 (动画 + 标记 spin 期 + 清空已击中表).
# 挖矿循环和单次攻击都调这个. 期间 _physics_process 每帧检查 tip 跟怪的距离.
# 用户改: spin 起始朝鼠标 (不再总从上). 算 mouse_angle 传给 held + 存起来给 hit 检测.
func _start_pickaxe_spin() -> void:
	_pickaxe_spin_damages = false   # 默认纯视觉 (挖矿石头/斧砍树时不误伤怪); _pickaxe_attack 才设 true
	var player: Node2D = get_parent() as Node2D
	if player == null:
		return
	# 鼠标方向 (测试用 override > 真实输入)
	var mouse_world: Vector2 = mouse_world_override if mouse_world_override != null else player.get_global_mouse_position()
	var to_mouse: Vector2 = mouse_world - player.global_position
	var mouse_angle: float = to_mouse.angle() if to_mouse.length() > 0.001 else -PI / 2.0
	# 跟 held_item.play_pickaxe_attack 同公式算 start_rot
	_pickaxe_spin_facing_right = cos(mouse_angle) >= 0.0
	var s: float = 1.0 if _pickaxe_spin_facing_right else -1.0
	_pickaxe_spin_start_rot = wrapf(s * (mouse_angle + PI / 2.0), -PI, PI)
	var held: Node = player.get_node_or_null("HeldItem")
	if held != null and held.has_method("play_pickaxe_attack"):
		held.play_pickaxe_attack(mouse_angle)
	elif held != null and held.has_method("play_swing"):
		held.play_swing()
	_pickaxe_spin_active = true
	_pickaxe_spin_t = 0.0
	_pickaxe_hit_this_spin.clear()


# spin 期间每帧调: 算 pickaxe tip 世界位置, 检查跟怪的距离.
# 怪距 ≤ HIT_RADIUS 且这次 spin 还没被打 → 扣血 + 记入 hit set 防重复.
func _check_pickaxe_spin_hits() -> void:
	var player: Node2D = get_parent() as Node2D
	if player == null:
		return
	var held: Node2D = player.get_node_or_null("HeldItem") as Node2D
	if held == null or not held.visible:
		return
	if not _pickaxe_spin_damages:
		return   # 挖矿/斧 的旋转: 纯视觉, 不扣血 (修"挖石头误伤旁边怪")
	# tip 旋转角度自己算 (跟 held_item Tween 同步 — start_rot + 360° over duration),
	# 不读 held.rotation — tween 在 _process 更新, _physics_process 这里读可能滞后.
	var rot_delta: float = (_pickaxe_spin_t / PICKAXE_SPIN_DURATION) * TAU
	var dir: float = 1.0 if _pickaxe_spin_facing_right else -1.0
	var held_rot: float = _pickaxe_spin_start_rot + rot_delta * dir
	# facing left 时 sprite scale.x=-1 镜像 X, tip 在世界坐标用 -held_rot 算 (等价 X 翻转)
	var rot_for_tip: float = held_rot if _pickaxe_spin_facing_right else -held_rot
	var tip_world: Vector2 = held.global_position + Vector2(0, PICKAXE_TIP_LOCAL_Y).rotated(rot_for_tip)
	var base: int = _pickaxe_base_damage()
	if base <= 0:
		return
	var dmg_mult: float = _tool_damage_mult()
	if dmg_mult <= 0.0:
		return
	var damage: int = max(1, int(round(float(base) * dmg_mult)))
	for group in ["slimes", "animals"]:
		for s in get_tree().get_nodes_in_group(group):
			var sn := s as Node2D
			if sn == null:
				continue
			var id: int = sn.get_instance_id()
			if _pickaxe_hit_this_spin.has(id):
				continue
			# 大怪给身子半径 (跟剑一致), 镐转碰到大身子就算命中; 普通怪没此方法 = 0
			var radius: float = sn.melee_hit_radius() if sn.has_method("melee_hit_radius") else 0.0
			# tip 碰到 OR 贴着手(贴身怪): 任一即命中 (修贴身怪在 tip 轨道死角打不到)
			var to_tip: float = tip_world.distance_to(sn.global_position)
			var to_hand: float = held.global_position.distance_to(sn.global_position)
			if to_tip > PICKAXE_HIT_RADIUS + radius and to_hand > PICKAXE_HIT_RADIUS + radius:
				continue
			_pickaxe_hit_this_spin[id] = true
			_deal_enemy_damage(sn, damage, tip_world, _pickaxe_knockback())


# 对怪造成伤害的统一入口.
# 联机 client: 远程怪是 host 权威的, 不在本地扣血(否则砍死的是本地副本, host 不知道又被刷回来),
# 改成发"伤害消息"给 host, host 在真怪上扣血并广播结果. 本地怪(单机/host)直接 take_damage.
func _deal_enemy_damage(target: Node2D, amount: int, src: Vector2, knockback: float) -> void:
	if target.has_meta("is_remote"):
		if NetworkManager != null and NetworkManager.connected():
			var rid: int = int(target.get_meta("remote_id", 0))
			if rid != 0:
				NetworkManager.send_entity_damage(rid, amount, knockback, src.x, src.y)
		return
	if target.has_method("take_damage"):
		target.take_damage(amount, src, knockback)


# 攻击开始时调一次. 接下来 duration 秒内每帧 _check_sword_blade_hits 扫击中.
func _start_sword_blade_attack(is_sweep: bool, swing_dir: Vector2, damage: int, knockback: float) -> void:
	_sword_attack_active = true
	_sword_attack_t = 0.0
	_sword_attack_duration = SWORD_SWING_DURATION if is_sweep else SWORD_THRUST_DURATION
	_sword_attack_is_sweep = is_sweep
	_sword_attack_swing_dir = swing_dir
	_sword_attack_target_angle = swing_dir.angle()
	_sword_attack_facing_right = cos(_sword_attack_target_angle) >= 0.0
	# 挥 (sweep) 起手旋转: 跟 held_item.play_swing_directional 同公式 (含瞄左反向, 否则左挥变"挑").
	# 瞄右 half=+110°: start=base-110, 扫 +220°; 瞄左 half=-110°: start=base+110, 扫 -220° (镜像)。
	if is_sweep:
		var base: float = wrapf(_sword_attack_target_angle + PI / 2.0, -PI, PI)
		var half: float = deg_to_rad(110.0) if _sword_attack_facing_right else -deg_to_rad(110.0)
		_sword_attack_start_rot = base - half
	_sword_attack_damage = max(1, damage)
	_sword_attack_knockback = knockback
	_sword_hit_this_attack.clear()


# 每帧调: 算剑身 (grip→tip) 在世界里位置, 看哪只怪贴近. 1 击 1 只怪 (hit set 去重).
# 不读 held.rotation/position — 自己按 _sword_attack_t 跟动画公式同步, headless 测试也能跑.
func _check_sword_blade_hits() -> void:
	var player: Node2D = get_parent() as Node2D
	if player == null:
		return
	var t: float = _sword_attack_t
	var blade_rot: float = 0.0
	var hand_x: float = SWORD_HAND_OFFSET_X if _sword_attack_facing_right else -SWORD_HAND_OFFSET_X
	var grip_local: Vector2 = Vector2(hand_x, SWORD_HAND_OFFSET_Y)
	if _sword_attack_is_sweep:
		# 半圆挥: rotation 从 start_a 线性插值过 ±220° over SWORD_SWING_DURATION.
		# 瞄左扫向反过来 (-220°), 跟视觉/起手 half 一致 → 命中弧线跟看到的一致, 不是"挑"。
		var progress: float = clamp(t / SWORD_SWING_DURATION, 0.0, 1.0)
		var total: float = deg_to_rad(220.0) if _sword_attack_facing_right else -deg_to_rad(220.0)
		blade_rot = _sword_attack_start_rot + total * progress
	else:
		# 戳: rotation 静止指向鼠标 (target_angle + PI/2). position 三段式动.
		blade_rot = wrapf(_sword_attack_target_angle + PI / 2.0, -PI, PI)
		var progress: float = clamp(t / SWORD_THRUST_DURATION, 0.0, 1.0)
		var thrust_amount: float = 0.0
		if progress <= SWORD_THRUST_EXTEND_END:
			# 0..0.20 突出: linear (近似 EASE_OUT)
			thrust_amount = progress / SWORD_THRUST_EXTEND_END
		elif progress <= SWORD_THRUST_DWELL_END:
			# 0.20..0.75 dwell: 维持在最前
			thrust_amount = 1.0
		else:
			# 0.75..1.0 收回: 1 → 0 linear (近似 EASE_IN)
			thrust_amount = 1.0 - (progress - SWORD_THRUST_DWELL_END) / (1.0 - SWORD_THRUST_DWELL_END)
		grip_local += _sword_attack_swing_dir * (SWORD_THRUST_OFFSET * thrust_amount)
	var grip_world: Vector2 = player.global_position + grip_local
	# 剑尖在 sprite 中心列, 不受 facing 翻转影响, 直接用 blade_rot 算 tip 偏移.
	# 阔剑(tier3+)半圆挥剑身更长够得更远; 短剑(戳)用基础长度 (SWORD_TIP_LOCAL_Y<0, 减 bonus = 更长).
	var tip_len: float = SWORD_TIP_LOCAL_Y - SWORD_SWEEP_REACH_BONUS if _sword_attack_is_sweep else SWORD_TIP_LOCAL_Y + DAGGER_BLADE_SHORTEN
	var tip_world: Vector2 = grip_world + Vector2(0, tip_len).rotated(blade_rot)
	# 短剑(戳)命中半径比阔剑小 → 命中更"贴", 不糊到远处怪 (用户: 戳得太远)
	var hit_r: float = SWORD_HIT_RADIUS if _sword_attack_is_sweep else DAGGER_HIT_RADIUS
	# 挥(sweep): 半圆扫过的怪全打 (群伤是阔剑的卖点)。
	# 戳(thrust): 一击只穿 1 只 (最近的), 不会顺着剑指方向连远处的也戳到。
	var is_thrust: bool = not _sword_attack_is_sweep
	if is_thrust and not _sword_hit_this_attack.is_empty():
		return   # 这一戳已经命中过 1 只, 后续帧不再补刀
	var thrust_target: Node2D = null
	var thrust_best_dist: float = 1.0e20
	for group in ["slimes", "animals"]:
		for s in get_tree().get_nodes_in_group(group):
			var sn := s as Node2D
			if sn == null:
				continue
			var id: int = sn.get_instance_id()
			if _sword_hit_this_attack.has(id):
				continue
			# 大怪 (如史莱姆王) 给身子半径, 剑碰到大身子就算命中 (不只认中心一点); 普通怪没此方法 = 0
			var radius: float = sn.melee_hit_radius() if sn.has_method("melee_hit_radius") else 0.0
			# 贴脸保险: 怪在玩家 ≤ 22.5px(+身子半径) 内一律算命中 (剑指远处也保住近身怪)
			var to_player_dist: float = sn.global_position.distance_to(player.global_position)
			var hit: bool = to_player_dist <= SWORD_POINT_BLANK_DIST + radius
			if not hit:
				hit = _dist_point_to_segment(sn.global_position, grip_world, tip_world) <= hit_r + radius
			if not hit:
				continue
			if is_thrust:
				# 戳: 先记下最近的, 循环结束后只打它一只
				if to_player_dist < thrust_best_dist:
					thrust_best_dist = to_player_dist
					thrust_target = sn
			else:
				# 挥: 扫到的全打
				_sword_hit_this_attack[id] = true
				_deal_enemy_damage(sn, _sword_attack_damage, tip_world, _sword_attack_knockback)
	if is_thrust and thrust_target != null:
		_sword_hit_this_attack[thrust_target.get_instance_id()] = true
		_deal_enemy_damage(thrust_target, _sword_attack_damage, tip_world, _sword_attack_knockback)
	# PvP: 对战房里剑也能扫到远程玩家
	if NetworkManager != null and NetworkManager.combat_enabled():
		var player2: Node2D = get_parent() as Node2D
		for s in get_tree().get_nodes_in_group("remote_player"):
			var rp := s as Node2D
			if rp == null:
				continue
			var rid2: int = rp.get_instance_id()
			if _sword_hit_this_attack.has(rid2):
				continue
			var radius2: float = rp.melee_hit_radius() if rp.has_method("melee_hit_radius") else 8.0
			var to_p: float = rp.global_position.distance_to(player2.global_position)
			var hit2: bool = to_p <= SWORD_POINT_BLANK_DIST + radius2
			if not hit2:
				hit2 = _dist_point_to_segment(rp.global_position, grip_world, tip_world) <= hit_r + radius2
			if not hit2:
				continue
			_sword_hit_this_attack[rid2] = true
			_hit_remote_player(rp, _sword_attack_damage, tip_world, _sword_attack_knockback)


# PvP: 命中某远程玩家 → 发伤害消息 (对方那端扣自己的血) + 本地闪红反馈。
func _hit_remote_player(rp: Node2D, dmg: int, src: Vector2, kb: float) -> void:
	if NetworkManager == null or not NetworkManager.combat_enabled():
		return
	var pid: String = String(rp.peer_id) if "peer_id" in rp else ""
	if pid == "":
		return
	NetworkManager.send_player_damage(pid, dmg, kb, src.x, src.y)
	if rp.has_method("flash_hit"):
		rp.flash_hit()


# 点到线段最近距离. clamp t ∈ [0,1] 让计算落在线段内, 端点外的算到端点.
static func _dist_point_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var ab_len_sq: float = ab.length_squared()
	if ab_len_sq < 0.001:
		return p.distance_to(a)
	var t: float = clamp((p - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)


# 弧形判定: 目标在 origin → dir 弧内 (距 ≤ SWORD_RANGE_PX 且夹角 ≤ ±45°)
func _is_in_swing_arc(target_pos: Vector2, origin: Vector2, dir: Vector2) -> bool:
	var to_target := target_pos - origin
	var dist := to_target.length()
	if dist > SWORD_RANGE_PX:
		return false
	if dist < 4.0:
		return true   # 贴脸总命中
	var diff: float = wrapf(to_target.angle() - dir.angle(), -PI, PI)
	return abs(diff) <= deg_to_rad(SWEEP_ARC_HALF_DEG)


# 戳的常量
const THRUST_COOLDOWN := 0.38   # 短剑(戳)出手快, 但要 > 动画 0.30 (SWORD_THRUST_DURATION), 否则戳没收回就重触发→抽搐
const THRUST_LENGTH_MULT := 1.2      # 戳长 = SWORD_RANGE_PX * 1.2 ≈ 43px (比挥更远)
const THRUST_HALF_WIDTH := 4.5       # 戳带半宽 6px (总宽 12), 鼠标偏一点也命中
# 注: 短剑弱由 item 的 damage_mult=0.8 决定 (阔剑 1.2), 戳不再额外乘削弱系数


# 戳: 直线突刺, 范围远 / 伤害 0.8x / 只命中最近 1 个目标
func _thrust_sword() -> void:
	_attack_cooldown = THRUST_COOLDOWN
	var player: Node2D = get_parent() as Node2D
	if player == null:
		return
	var mouse_world: Vector2 = mouse_world_override if mouse_world_override != null else player.get_global_mouse_position()
	var to_mouse: Vector2 = mouse_world - player.global_position
	if to_mouse.length() < 0.001:
		to_mouse = Vector2(1.0 if player.has_method("facing_dir") and player.facing_dir() > 0 else -1.0, 0)
	var swing_dir: Vector2 = to_mouse.normalized()
	var max_len: float = SWORD_RANGE_PX * THRUST_LENGTH_MULT
	last_swing_center = player.global_position + swing_dir * max_len * 0.5
	# 动画: 工具沿 swing_dir 突刺再收回
	var held: Node = player.get_node_or_null("HeldItem")
	if held != null and held.has_method("play_thrust"):
		held.play_thrust(swing_dir.angle())
	elif held != null and held.has_method("play_swing"):
		held.play_swing()
	# 用户改: 删剑挥/戳音效 (只留命中怪的打击音, 见 effects.spawn_damage_number)
	# 伤害 = sword_damage * damage_mult * 0.8
	var base: int = _sword_damage()
	if base <= 0:
		return
	var dmg_mult: float = _tool_damage_mult()
	if dmg_mult <= 0.0:
		return
	var damage: int = max(1, int(round(float(base) * dmg_mult)))
	# 用户改: 不再瞬时矩形 AoE, 改成 SWORD_THRUST_DURATION 内每帧扫剑身线段命中.
	# 戳动画 held.position 三段式 (extend + dwell + retract), 我们 sync 算位置打怪.
	_start_sword_blade_attack(false, swing_dir, damage, _thrust_knockback())
	# 用户改: 删剑攻击的屏幕抖动


func _sweep_sword() -> void:
	_attack_cooldown = SWORD_COOLDOWN
	var player: Node2D = get_parent() as Node2D
	if player == null:
		return
	# 鼠标方向 (测试用 override > 真实输入)
	var mouse_world: Vector2 = mouse_world_override if mouse_world_override != null else player.get_global_mouse_position()
	var to_mouse: Vector2 = (mouse_world - player.global_position)
	if to_mouse.length() < 0.001:
		to_mouse = Vector2(1.0 if player.has_method("facing_dir") and player.facing_dir() > 0 else -1.0, 0)
	var swing_dir: Vector2 = to_mouse.normalized()
	# 命中中心点 = 玩家中心 + 方向 × 半个射程
	var center: Vector2 = player.global_position + swing_dir * SWORD_RANGE_PX * 0.5
	last_swing_center = center
	# 手持物品挥摆动画 (角度跟随鼠标; Task 2 实现)
	var held: Node = player.get_node_or_null("HeldItem")
	if held != null:
		if held.has_method("play_swing_directional"):
			held.play_swing_directional(swing_dir.angle())
		elif held.has_method("play_swing"):
			held.play_swing()
	# 用户改: 删剑挥/戳音效 (只留命中怪的打击音)
	var damage: int = _effective_sword_damage()
	if damage <= 0:
		return
	# 用户改: 不再瞬时弧 AoE, 改成 SWORD_SWING_DURATION 内每帧扫剑身线段命中.
	# 挥半圆 180° rotation, 剑尖按 progress 扫弧 — 实际碰才扣血.
	_start_sword_blade_attack(true, swing_dir, damage, _sweep_knockback())
	# 用户改: 删剑攻击的屏幕抖动 (之前留着, 现在用户要求删)


func _inventory_node() -> Node:
	var parent: Node = get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("PlayerInventory")


func player_tile() -> Vector2i:
	var parent: Node2D = get_parent() as Node2D
	var foot: Vector2 = parent.global_position
	return Vector2i(int(floor(foot.x / TILE_SIZE)), int(floor(foot.y / TILE_SIZE)))


func in_reach(tile: Vector2i) -> bool:
	if tile == INVALID_TILE:
		return false
	var pt: Vector2i = player_tile()
	return abs(tile.x - pt.x) <= REACH_TILES and abs(tile.y - pt.y) <= REACH_TILES


const ArrowScene = preload("res://scenes/entities/arrow.tscn")
const BulletScene = preload("res://scenes/entities/bullet.tscn")
const FireballScene = preload("res://scenes/entities/fireball.tscn")
const SlimeBallScene = preload("res://scenes/entities/slime_ball.tscn")
const FriendlySkeletonScene = preload("res://scenes/entities/friendly_skeleton.tscn")
const BOW_COOLDOWN := 0.4
const BOW_ARROW_DAMAGE := 5    # base, 后续乘 tier multiplier
const GUN_COOLDOWN := 0.22     # 比弓快 (连发感)
const GUN_BULLET_DAMAGE := 9   # base, 比箭(5)狠; 后续乘 tier multiplier
const STAFF_COOLDOWN := 0.5    # 法杖 cd (mana 限制为主, cd 防自动连发)
const SUMMON_STAFF_COOLDOWN := 0.6   # 骷髅法杖召唤 cd
const FRIENDLY_CAP := 3              # 场上最多几个友方骷髅
const SLIMEBALL_COOLDOWN := 0.45
const SLIMEBALL_DAMAGE := 16   # 高于 iron 剑 (tier4 ≈ 10)

# 弓发箭: 找 inventory 里第 1 个 wood_arrow → 消耗 1 → spawn Arrow Area2D 朝鼠标飞
# 没箭 → 不发, 也不进 cooldown (玩家随便点没惩罚)
func _try_fire_bow() -> void:
	var inv: Node = _inventory_node()
	if inv == null:
		return
	# 找到任意 wood_arrow 槽并消耗 1 (对战房: 箭无限, 不扣也能射)
	var consumed: bool = false
	if NetworkManager != null and NetworkManager.combat_enabled():
		consumed = true
	elif inv.has_method("consume_first"):
		consumed = inv.consume_first("wood_arrow", 1)
	else:
		# 兜底: 直接查 hotbar / main inv 槽位
		consumed = _consume_arrow_fallback(inv)
	if not consumed:
		# TODO: 加"没箭"音效
		return
	_attack_cooldown = BOW_COOLDOWN
	# spawn 箭
	var parent: Node2D = get_parent() as Node2D
	if parent == null:
		return
	var start: Vector2 = parent.global_position + Vector2(0, -8)   # 玩家身体中部
	var target: Vector2 = mouse_world_override if mouse_world_override != null else parent.get_global_mouse_position()
	var arrow = ArrowScene.instantiate()
	var entities: Node = get_tree().get_first_node_in_group("entities_root")
	if entities == null:
		entities = parent.get_parent()
	entities.add_child(arrow)
	var dmg: int = BOW_ARROW_DAMAGE
	# 弓 tier 加伤: tier1 ×1.0, 后续 tier 加 (留口子未来 add bow tier 2-7)
	dmg = int(round(float(dmg) * _tool_damage_mult()))
	arrow.setup(start, target, dmg, parent)
	# 让手里的弓转向鼠标 (修 bug: 之前箭朝鼠标飞, 但弓一直竖着不转 = 看着没瞄准)
	var held: Node = _held_item_node()
	if held != null and held.has_method("play_bow_shoot"):
		held.play_bow_shoot((target - parent.global_position).angle())
	if NetworkManager != null and NetworkManager.connected():
		NetworkManager.send_projectile("arrow", start.x, start.y, target.x, target.y)
	SfxBank.play("break", 0.10)  # 暂用破方块声当弓弦声; 以后加专属


# 枪射子弹: 找 inventory 里第 1 个 bullet → 消耗 1 → spawn Bullet 朝鼠标直飞.
# 没子弹 → 不发, 也不进 cooldown (跟弓一样, 随便点没惩罚). 照 _try_fire_bow 结构.
func _try_fire_gun() -> void:
	var inv: Node = _inventory_node()
	if inv == null:
		return
	# 先读 def 决定弹药来源: 魔法枪 (有 mana_cost) 耗魔力不耗子弹; 普通枪耗 1 发子弹.
	var def: Variant = _current_tool_def()
	var mana_cost: int = int(def.get("mana_cost", 0)) if def != null else 0
	if mana_cost > 0:
		var mana_n: Node = get_parent().get_node_or_null("PlayerMana")
		if mana_n == null or not mana_n.has_method("try_consume"):
			return
		if not mana_n.try_consume(mana_cost):
			return   # 魔力不够 → 不发, 不进 cooldown
	else:
		var consumed: bool = false
		if inv.has_method("consume_first"):
			consumed = inv.consume_first("bullet", 1)   # 一次扣 1 发 (霰弹也只 1 发, 出 N 弹丸, 划算)
		if not consumed:
			return
	# 每把枪自带参数 (从 item def 读); 没配的用手枪默认值. 加新枪只改 item_db, 不动这里.
	var cd: float = float(def.get("gun_cooldown", GUN_COOLDOWN)) if def != null else GUN_COOLDOWN
	var base_dmg: int = int(def.get("gun_damage", GUN_BULLET_DAMAGE)) if def != null else GUN_BULLET_DAMAGE
	var pellets: int = int(def.get("gun_pellets", 1)) if def != null else 1
	var spread_deg: float = float(def.get("gun_spread_deg", 0.0)) if def != null else 0.0
	var speed: float = float(def.get("bullet_speed", 0.0)) if def != null else 0.0  # 0 = 子弹默认速度
	# 特殊枪机制 (激光穿透 / 冰冻减速 / 火焰外观+短寿命); 普通枪这些字段都没配 → opts 空.
	var opts: Dictionary = {}
	if def != null:
		if bool(def.get("gun_pierce", false)):
			opts["pierce"] = true
		if def.has("gun_slow_factor"):
			opts["slow_factor"] = float(def.get("gun_slow_factor"))
			opts["slow_dur"] = float(def.get("gun_slow_dur", 2.0))
		if def.has("gun_visual"):
			opts["visual"] = String(def.get("gun_visual"))
		if def.has("bullet_lifetime"):
			opts["lifetime"] = float(def.get("bullet_lifetime"))
		# 魔法机制: 追踪 / 毒 / 连锁 / 反弹 / 重力
		if def.has("gun_homing"):
			opts["homing"] = float(def.get("gun_homing"))
		if def.has("gun_dot_dps"):
			opts["dot_dps"] = int(def.get("gun_dot_dps"))
			opts["dot_dur"] = float(def.get("gun_dot_dur", 3.0))
		if def.has("gun_chain"):
			opts["chain"] = int(def.get("gun_chain"))
			opts["chain_radius"] = float(def.get("gun_chain_radius", 60.0))
		if def.has("gun_bounce"):
			opts["bounce"] = int(def.get("gun_bounce"))
		if def.has("gun_gravity"):
			opts["gravity"] = float(def.get("gun_gravity"))
	_attack_cooldown = cd
	var parent: Node2D = get_parent() as Node2D
	if parent == null:
		return
	var start: Vector2 = parent.global_position + Vector2(0, -8)   # 玩家身体中部
	var target: Vector2 = mouse_world_override if mouse_world_override != null else parent.get_global_mouse_position()
	var base_dir: Vector2 = target - start
	base_dir = base_dir.normalized() if base_dir.length() > 0.01 else Vector2.RIGHT
	var dmg: int = int(round(float(base_dmg) * _tool_damage_mult()))
	var entities: Node = get_tree().get_first_node_in_group("entities_root")
	if entities == null:
		entities = parent.get_parent()
	# 多弹丸: 霰弹枪一次喷 N 颗, 每颗在 ±spread/2 内随机偏角 → 扇形. 普通枪 pellets=1.
	for _i in max(1, pellets):
		var dir: Vector2 = base_dir
		if spread_deg > 0.0:
			dir = base_dir.rotated(deg_to_rad(randf_range(-spread_deg * 0.5, spread_deg * 0.5)))
		var aim: Vector2 = start + dir * 100.0   # 沿偏角给个瞄点, bullet 自己按方向算速度
		var bullet = BulletScene.instantiate()
		entities.add_child(bullet)
		bullet.setup(start, aim, dmg, parent, speed, opts)
		if NetworkManager != null and NetworkManager.connected():
			NetworkManager.send_projectile("bullet", start.x, start.y, aim.x, aim.y)
	SfxBank.play("gunshot", 0.08)


# 法杖发火球: 检查 mana 够 → 扣 → spawn fireball 朝鼠标飞.
# damage 跟 mana_cost 由 ItemDB.get_def() 配置 (hell_staff: 22 dmg / 20 mana).
func _try_cast_staff() -> void:
	var def: Variant = _current_tool_def()
	if def == null:
		return
	var mana_cost: int = def.get("mana_cost", 20)
	var spell_dmg: int = def.get("spell_damage", 14)
	var element: String = String(def.get("spell_element", "fire"))
	var player: Node2D = get_parent() as Node2D
	if player == null:
		return
	var mana: Node = player.get_node_or_null("PlayerMana")
	if mana == null:
		return
	if not mana.has_method("try_consume"):
		return
	if not mana.try_consume(mana_cost):
		# mana 不够
		return
	_attack_cooldown = STAFF_COOLDOWN
	var start: Vector2 = player.global_position + Vector2(0, -8)
	var target: Vector2 = mouse_world_override if mouse_world_override != null else player.get_global_mouse_position()
	var fb = FireballScene.instantiate()
	var entities: Node = get_tree().get_first_node_in_group("entities_root")
	if entities == null:
		entities = player.get_parent()
	entities.add_child(fb)
	# damage_mult 让未来高 tier 法杖加伤
	var final_dmg: int = int(round(float(spell_dmg) * _tool_damage_mult()))
	fb.setup(start, target, final_dmg, true, element)   # true = player_cast, element = 元素弹
	if NetworkManager != null and NetworkManager.connected():
		# kind 带上元素 (fireball_nature/ice/fire), 对端按后缀还原弹色
		NetworkManager.send_projectile("fireball_" + element, start.x, start.y, target.x, target.y)
	SfxBank.play("break", 0.12)


# 骷髅法杖: 消耗 mana → 在玩家旁召唤 1 个友方骷髅 (上限 FRIENDLY_CAP). 不发火球。
func _summon_friendly() -> void:
	var def: Variant = _current_tool_def()
	if def == null:
		return
	var player: Node2D = get_parent() as Node2D
	if player == null:
		return
	# 上限: 场上友方骷髅别太多
	if get_tree().get_nodes_in_group("friendly_minions").size() >= FRIENDLY_CAP:
		return
	# 扣 mana (不够就不召)
	var mana: Node = player.get_node_or_null("PlayerMana")
	var cost: int = int(def.get("mana_cost", 18))
	if mana != null and mana.has_method("try_consume"):
		if not mana.try_consume(cost):
			return
	_attack_cooldown = SUMMON_STAFF_COOLDOWN
	var fs = FriendlySkeletonScene.instantiate()
	var entities: Node = get_tree().get_first_node_in_group("entities_root")
	if entities == null:
		entities = player.get_parent()
	entities.add_child(fs)
	fs.global_position = player.global_position + Vector2(randf_range(-16.0, 16.0), -4.0)
	SfxBank.play("place", 0.15)


# 手持召唤道具 (slime_crown) 使用 → 在玩家附近召唤 Boss, 成功则消耗 1.
func try_use_summon_item() -> bool:
	var inv: Node = _inventory_node()
	if inv == null:
		return false
	var slot = inv.current_hotbar_slot()
	if slot == null or not ItemDB.is_summon(slot.item_id):
		return false
	var player: Node2D = get_parent() as Node2D
	if player == null:
		return false
	var world: Node = _find_world()
	if world == null or not world.has_method("spawn_boss"):
		return false
	# 召谁由召唤道具的 summon_boss 字段定 (slime_crown→king_slime, skull_summon→skeleton_king)
	var def: Variant = ItemDB.get_def(slot.item_id)
	var boss_id: String = String(def.get("summon_boss", "king_slime")) if def != null else "king_slime"
	var spawn_pos: Vector2 = player.global_position + Vector2(40, -24)
	if not world.spawn_boss(boss_id, spawn_pos):
		return false
	inv.consume_current(1)
	SfxBank.play("break", 0.2)
	return true


# 找 World 节点 (terrain 的父节点; 跟 _consume_crystal_tile / _trigger_mimic_trap 同款路径)
func _find_world() -> Node:
	var t := _terrain()
	return t.get_parent() if t != null else null


func _try_throw_slimeball() -> void:
	_attack_cooldown = SLIMEBALL_COOLDOWN
	var parent: Node2D = get_parent() as Node2D
	if parent == null:
		return
	var start: Vector2 = parent.global_position + Vector2(0, -8)
	var target: Vector2 = mouse_world_override if mouse_world_override != null else parent.get_global_mouse_position()
	var ball = SlimeBallScene.instantiate()
	var entities: Node = get_tree().get_first_node_in_group("entities_root")
	if entities == null:
		entities = parent.get_parent()
	entities.add_child(ball)
	var dmg: int = int(round(float(SLIMEBALL_DAMAGE) * _tool_damage_mult()))
	ball.setup(start, target, dmg, parent)
	SfxBank.play("break", 0.10)


func _consume_arrow_fallback(inv: Node) -> bool:
	# 老接口兜底: 直接读 hotbar + main slots, 找 wood_arrow 减 1
	for fn in ["consume", "remove_item"]:
		if inv.has_method(fn):
			var ok = inv.call(fn, "wood_arrow", 1)
			if ok == true or ok == 1:
				return true
	return false


# 死人箱触发: 玩家右键 / 砍 → 爆炸 + 弹出 Mimic 怪物.
# 1) 删掉 tile (变 AIR)
# 2) 爆炸粒子 + 砸方块 SFX
# 3) 玩家近距离 (≤2 tile) 扣 12 血 + knockback
# 4) world.spawn_mimic_at_tile 召唤 Mimic 实体
func _trigger_mimic_trap(tile: Vector2i, world: Node) -> void:
	# 1) 删 tile
	if world.has_method("_set_tile"):
		world._set_tile(tile.x, tile.y, Tiles.AIR)
	# 2) 爆炸 FX + 音效
	var center := Vector2(tile.x * TILE_SIZE + TILE_SIZE / 2.0, tile.y * TILE_SIZE + TILE_SIZE / 2.0)
	Effects.spawn_explosion(center)
	SfxBank.play("break", 0.35)  # 暂用破方块声 (响一点); 以后可加专属爆炸 SFX
	# 3) 玩家在范围内扣血 (玩家既然右键了, 肯定在 reach 内)
	var player: Node = get_parent()
	if player != null:
		var hp: Node = player.get_node_or_null("PlayerHealth")
		if hp != null:
			hp.take_damage(12, center, 250.0)
	# 4) 召唤 Mimic
	if world != null and world.has_method("spawn_mimic_at_tile"):
		world.spawn_mimic_at_tile(tile)


# 玩家吃了水晶 (生命 / 魔力): tile 变 AIR + 飘字 + 爆炸粒子 + "ding" 音效.
# (try_extend_max 已经更新 HP/MANA, 这里只处理视觉/世界 side effect)
# color 飘字颜色 (生命 → 粉, 魔力 → 蓝紫)
func _consume_crystal_tile(tile: Vector2i, terrain: TileMapLayer, color: Color = Color(1.0, 0.4, 0.6)) -> void:
	var world: Node = terrain.get_parent()
	if world != null and world.has_method("_set_tile"):
		world._set_tile(tile.x, tile.y, Tiles.AIR)
	var center := Vector2(tile.x * TILE_SIZE + TILE_SIZE / 2.0, tile.y * TILE_SIZE + TILE_SIZE / 2.0)
	# "+20 MAX" 飘字 + 爆炸粒子
	Effects.spawn_damage_number(center + Vector2(0, -10), 20, color)
	Effects.spawn_explosion(center)
	SfxBank.play("pickup", 0.25)  # 暂用拾取 SFX 表示"获得"


# buff 倍数: 没 PlayerBuffs 时返回 1.0 (挖矿速度不受影响).
func _buff_mining_mul() -> float:
	var b: Node = get_parent().get_node_or_null("PlayerBuffs")
	return 1.0 if b == null else b.mining_mul()


# 鱼竿右键: 把"瞄准格是不是水(且够得着)"算好, 交给 PlayerFishing 按状态决定甩竿/收竿.
# 公开 (测试直接调, 不必在 headless 模拟真实右键).
func try_fishing_click() -> void:
	var pf: Node = get_parent().get_node_or_null("PlayerFishing")
	if pf == null or not pf.has_method("on_rod_click"):
		return
	var aim_t: Vector2i = aim_tile_coord()
	var terrain := _terrain()
	var is_water: bool = false
	if terrain != null and in_reach(aim_t):
		var tid: int = terrain.get_cell_source_id(aim_t)
		is_water = Tiles.is_water(tid)
	pf.on_rod_click(aim_t, is_water)
