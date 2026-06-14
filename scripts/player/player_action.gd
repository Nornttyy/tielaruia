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
var _sword_attack_reach_bonus: float = 0.0   # 这把武器额外伸长多少剑身 (长矛/链锤够更远; 普通剑=0)
var _sword_attack_lifesteal: float = 0.0     # 噬魂: 命中按伤害百分比回血 (0=不吸)
var _sword_attack_meteor: int = 0            # 星陨: 命中召唤几颗陨星砸下 (0=不召)
var _sword_attack_void: float = 0.0          # 虚空: 命中按概率秒杀小怪 (0=不秒, Boss 免疫)
var _sword_attack_magnet: float = 0.0        # 磁极: 命中把半径内掉落物吸向玩家 (0=不吸)
var _sword_attack_echo: float = 0.0          # 回响: 命中后隔几秒原地再炸一次 (0=不炸)
var _sword_attack_combo_haste: bool = false  # 赤霄: 连击越多挥得越快
var _sword_attack_chain: int = 0             # 雷神锤: 命中后闪电在附近怪之间连跳几次 (0=不连)
var _sword_attack_blast: float = 0.0         # 炼狱/巨力锤: 命中即在原地爆一圈, 这是半径 (0=不爆)
var _sword_attack_blast_color: Color = Color(1, 1, 1, 1)  # 即爆特效颜色 (按元素)
var _sword_attack_pull: bool = false         # 深渊锤: 命中把怪吸向玩家 (而不是击退)
const COMBO_MAX := 5                          # 连击最多叠 5 层
const COMBO_HASTE_PER := 0.08                 # 每层减 8% 攻击间隔
const COMBO_RESET_SEC := 1.2                  # 超过 1.2 秒没命中, 连击清零
var _combo_stacks: int = 0                    # 当前连击层数 (赤霄用)
var _combo_idle: float = 0.0                  # 距上次命中过了多久 (用于清零)
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
	# 赤霄连击: 太久没命中就清零 (这样停手后挥速回到正常)
	_combo_idle += delta
	if _combo_idle > COMBO_RESET_SEC:
		_combo_stacks = 0
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
	elif kind == "flail":
		# 链锤神兵: 按住 → 球绕玩家转蓄力; 松开 → 甩向鼠标再飞回 (带链子)。
		_reset_mining()
		var primary_pressed_f: bool = (primary_override == true) if primary_override != null else Input.is_action_pressed("primary")
		_update_flail(primary_pressed_f)
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
		_aim_bow_at_mouse()   # 持弓时弓一直朝鼠标方向 (用户: 别只朝玩家朝向)
		var primary_pressed_b: bool = (primary_override == true) if primary_override != null else Input.is_action_pressed("primary")
		if primary_pressed_b and _attack_cooldown <= 0.0:
			_try_fire_bow()
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
				# 对战房禁用召唤 (骷髅法杖太轮椅: 放完小兵就能摆烂). 只在单机/生存房能召唤。
				if NetworkManager != null and NetworkManager.combat_enabled():
					pass
				else:
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
	elif kind == "thrown":
		# 投掷武器: LMB 按下 → 朝鼠标扔 (手里剑/炸弹/回旋镖). cd 由武器 throw_cooldown 定. 无弹药.
		_reset_mining()
		var primary_pressed_t: bool = (primary_override == true) if primary_override != null else Input.is_action_pressed("primary")
		if primary_pressed_t and _attack_cooldown <= 0.0:
			_try_throw_weapon()
			_aim_held_at_mouse()   # 投掷时武器朝鼠标方向显示
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
	# 战斗房: 删掉合成功能, 这个键 (E / 触屏"包") 改成开/关"切换武器"面板 (用户要求)。
	# 用 room_mode=="pvp" 而非 combat_enabled() (后者要 connected()): 切模式时会断开重连,
	# 那一瞬 connected()=false → E 会漏到合成界面 (用户报"有时变合成"). 跟 pvp_mode_panel 同款门控。
	if NetworkManager != null and NetworkManager.room_mode == "pvp":
		var mp: Node = get_tree().get_first_node_in_group("pvp_mode_panel")
		if mp != null and mp.has_method("toggle_weapon_switch"):
			mp.toggle_weapon_switch()
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
func try_place(force_tile: Variant = null) -> bool:
	var terrain := _terrain()
	var inv: Node = _inventory_node()
	if terrain == null or inv == null:
		return false
	var slot: Variant = inv.current_hotbar_slot()
	if slot == null:
		return false
	if not ItemDB.is_placeable(slot.item_id):
		return false
	# force_tile: 连续放置补路径时指定格; 否则用鼠标对准格
	var tile: Vector2i = (force_tile as Vector2i) if force_tile != null else aim_tile_coord()
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
	# 支撑判定: 4 邻有结实方块/木平台, 或 背后有背景墙 → 能放 (防隔空放)。创造模式随处放。
	var has_support: bool = GameSettings != null and GameSettings.creative_mode
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var ntid: int = terrain.get_cell_source_id(tile + offset)
		# 结实方块 OR 木平台 都能当支撑 (站得住的都行); 水/草/火把不算。
		if ntid != -1 and (Tiles.is_solid(ntid) or ntid == Tiles.WOOD_PLATFORM):
			has_support = true
			break
	# 背景墙也算支撑 (泰拉瑞亚风: 墙前能贴方块 — 矿洞/墙边能放, 用户要求)。
	# 对战房是空世界没墙 → 那边仍需相邻方块, 不会隔空放。
	if not has_support:
		var wn: Node = terrain.get_parent()
		var wcm = wn.get("chunk_manager") if wn != null else null
		if wcm != null and wcm.has_method("get_wall") and wcm.get_wall(tile.x, tile.y) != Tiles.AIR:
			has_support = true
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
var _last_place_tile: Vector2i = Vector2i.ZERO   # 连续放置上次放的格 (补路径用)
var _has_last_place: bool = false


# 两格之间的整数直线 (Bresenham), 含端点. 连续放置补满划过的路径防跳格留空。
static func _line_tiles(a: Vector2i, b: Vector2i) -> Array:
	var out: Array = []
	var dx: int = abs(b.x - a.x)
	var dy: int = -abs(b.y - a.y)
	var sx: int = 1 if a.x < b.x else -1
	var sy: int = 1 if a.y < b.y else -1
	var err: int = dx + dy
	var x: int = a.x
	var y: int = a.y
	while true:
		out.append(Vector2i(x, y))
		if x == b.x and y == b.y:
			break
		if out.size() > 64:   # 安全上限 (防一次填太长)
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
	return out


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

	# 放置: 单击放一个; "连续放置"开 + 按住右键 → 沿划过的路径补满 (防跳格留空)
	_place_hold_cd = max(0.0, _place_hold_cd - delta)
	if just:
		if try_place():
			_play_place_anim()
		_last_place_tile = aim_tile_coord()
		_has_last_place = true
		_place_hold_cd = PLACE_HOLD_INTERVAL
	elif held and GameSettings != null and GameSettings.continuous_place:
		if _place_hold_cd <= 0.0:
			var cur: Vector2i = aim_tile_coord()
			var placed_any: bool = false
			if _has_last_place and _last_place_tile != cur:
				# 沿 上次格→当前格 直线补放, 跳过起点 (上次已放)
				var path: Array = _line_tiles(_last_place_tile, cur)
				for ti in range(1, path.size()):
					if try_place(path[ti]):
						placed_any = true
			elif try_place(cur):
				placed_any = true
			if placed_any:
				_play_place_anim()
			_last_place_tile = cur
			_has_last_place = true
			_place_hold_cd = PLACE_HOLD_INTERVAL
	else:
		_has_last_place = false   # 松开右键 → 下次重新起点 (不跨段连线)   # 放方块: 朝放置点按一下的动画


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


# 弓: 持弓时弓一直朝鼠标方向 (每帧调; 没射也朝着). 没 aim_bow 方法就退回 flash.
func _aim_bow_at_mouse() -> void:
	var held: Node = _held_item_node()
	if held == null:
		return
	var parent: Node2D = get_parent() as Node2D
	if parent == null or not held.has_method("aim_bow"):
		if held.has_method("flash"):
			held.flash()
		return
	var hand: Vector2 = parent.global_position + Vector2(0, -8)
	var target: Vector2 = mouse_world_override if mouse_world_override != null else parent.get_global_mouse_position()
	var angle: float = (target - hand).angle() if hand.distance_to(target) > 0.01 else 0.0
	held.aim_bow(angle)


# 放方块动画: 手里的方块朝放置点"按"出去一下 (方块也只在使用时显示).
# 通知玩家身体做动作姿势 (挥击 swing / 放置 place). player_action 是 player 子节点。
func _body_action(anim: String, dur: float) -> void:
	var p: Node = get_parent()
	if p != null and p.has_method("play_action_anim"):
		p.play_action_anim(anim, dur)


func _play_place_anim() -> void:
	_body_action("place", 0.22)   # 身体放置姿势 (伸手放方块)
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
	_body_action("swing", 0.3)   # 短剑/阔剑 挥/戳: 身体也挥一下
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
	tip_len -= _sword_attack_reach_bonus   # 武器自带额外射程 (长矛/链锤伸更长; tip_len 越负越远)
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
				_sword_on_hit(sn.global_position, sn)   # 噬魂/星陨/虚空/磁极/回响/赤霄
	if is_thrust and thrust_target != null:
		_sword_hit_this_attack[thrust_target.get_instance_id()] = true
		_deal_enemy_damage(thrust_target, _sword_attack_damage, tip_world, _sword_attack_knockback)
		_sword_on_hit(thrust_target.global_position, thrust_target)
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
	var mdef: Variant = _current_tool_def()
	_attack_cooldown = float(mdef.get("melee_cooldown", THRUST_COOLDOWN)) if mdef != null else THRUST_COOLDOWN
	_sword_attack_reach_bonus = float(mdef.get("melee_reach_bonus", 0.0)) if mdef != null else 0.0   # 长矛戳更远
	_set_sword_special_fields(mdef)
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
	# 动画: 工具沿 swing_dir 突刺再收回. 矛(reach 大)刺得更远才像个刺, 不然只是小抖.
	var held: Node = player.get_node_or_null("HeldItem")
	var lunge_px: float = SWORD_THRUST_OFFSET + _sword_attack_reach_bonus * 0.45   # 矛 reach32 → ~22px
	if held != null and held.has_method("play_thrust"):
		held.play_thrust(swing_dir.angle(), lunge_px)
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
	var tkb: float = float(mdef.get("melee_knockback", -1.0)) if mdef != null else -1.0
	_start_sword_blade_attack(false, swing_dir, damage, tkb if tkb >= 0.0 else _thrust_knockback())
	# 用户改: 删剑攻击的屏幕抖动


func _sweep_sword() -> void:
	var mdef: Variant = _current_tool_def()
	_attack_cooldown = float(mdef.get("melee_cooldown", SWORD_COOLDOWN)) if mdef != null else SWORD_COOLDOWN
	_sword_attack_reach_bonus = float(mdef.get("melee_reach_bonus", 0.0)) if mdef != null else 0.0   # 链锤/战锤抡更大
	_set_sword_special_fields(mdef)
	# 赤霄: 连击越高, 这次挥的攻击间隔越短 (越打越快, 上限减 40%)
	if _sword_attack_combo_haste:
		_attack_cooldown *= (1.0 - COMBO_HASTE_PER * float(_combo_stacks))
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
	# 手持物品挥摆动画 (角度跟随鼠标). 双刀(swing_fast): 挥快+左右交替, 跟它 0.18s 间隔对齐, 不抽搐.
	var held: Node = player.get_node_or_null("HeldItem")
	var fast_swing: bool = mdef != null and bool(mdef.get("swing_fast", false))
	var swing_dur: float = float(mdef.get("melee_cooldown", 0.5)) if fast_swing else 0.5
	if held != null:
		if held.has_method("play_swing_directional"):
			held.play_swing_directional(swing_dir.angle(), swing_dur, fast_swing)
		elif held.has_method("play_swing"):
			held.play_swing()
	# 用户改: 删剑挥/戳音效 (只留命中怪的打击音)
	var damage: int = _effective_sword_damage()
	if damage <= 0:
		return
	# 用户改: 不再瞬时弧 AoE, 改成 SWORD_SWING_DURATION 内每帧扫剑身线段命中.
	# 挥半圆 180° rotation, 剑尖按 progress 扫弧 — 实际碰才扣血.
	var skb: float = float(mdef.get("melee_knockback", -1.0)) if mdef != null else -1.0
	_start_sword_blade_attack(true, swing_dir, damage, skb if skb >= 0.0 else _sweep_knockback())
	# 代号神兵: 挥剑时额外射一发元素弹 (蓝月/火神/绿叶/冰雪剑/天陨)
	if mdef != null and bool(mdef.get("swing_proj", false)):
		_fire_swing_projectile(mdef, player, swing_dir)
	# 用户改: 删剑攻击的屏幕抖动 (之前留着, 现在用户要求删)


# 代号神兵挥剑射的元素弹: 复用 bullet (gun_* 字段决定穿透/追踪/减速/爆炸 + 命中招牌特效)。
# swing_proj_random (天陨) → 每挥一次随机一种元素。
func _fire_swing_projectile(def: Variant, player: Node2D, base_dir: Vector2) -> void:
	var entities: Node = get_tree().get_first_node_in_group("entities_root")
	if entities == null:
		entities = player.get_parent()
	var start: Vector2 = player.global_position + Vector2(0, -8)
	var target: Vector2 = mouse_world_override if mouse_world_override != null else player.get_global_mouse_position()
	var dir: Vector2 = target - start
	dir = dir.normalized() if dir.length() > 0.01 else base_dir
	var opts: Dictionary = _proj_opts_from_def(def)
	var vis: String = String(def.get("gun_visual", "magic"))
	if bool(def.get("swing_proj_random", false)):
		vis = ["fire", "ice", "leaf", "lightning", "poison"][randi() % 5]   # 天陨: 随机元素
		opts["visual"] = vis
	opts["impact_fx"] = _spell_impact_fx(vis)
	opts["impact_color"] = _spell_fx_color(vis)
	var dmg: int = int(round(float(def.get("swing_proj_damage", 8)) * _tool_damage_mult()))
	var speed: float = float(def.get("bullet_speed", 460.0))
	var aim: Vector2 = start + dir * 100.0
	var b = BulletScene.instantiate()
	entities.add_child(b)
	b.setup(start, aim, dmg, player, speed, opts)
	if NetworkManager != null and NetworkManager.connected():
		NetworkManager.send_projectile("bullet", start.x, start.y, aim.x, aim.y)


# 一次性把这把剑的特殊字段读进成员变量 (挥/戳开始时调)。
func _set_sword_special_fields(mdef: Variant) -> void:
	if mdef == null:
		_sword_attack_lifesteal = 0.0; _sword_attack_meteor = 0; _sword_attack_void = 0.0
		_sword_attack_magnet = 0.0; _sword_attack_echo = 0.0; _sword_attack_combo_haste = false
		_sword_attack_chain = 0; _sword_attack_blast = 0.0; _sword_attack_pull = false
		return
	_sword_attack_lifesteal = float(mdef.get("lifesteal", 0.0))
	_sword_attack_meteor = int(mdef.get("meteor_on_hit", 0))
	_sword_attack_void = float(mdef.get("void_chance", 0.0))
	_sword_attack_magnet = float(mdef.get("magnet_radius", 0.0))
	_sword_attack_echo = float(mdef.get("echo_delay", 0.0))
	_sword_attack_combo_haste = bool(mdef.get("combo_haste", false))
	_sword_attack_chain = int(mdef.get("chain_lightning", 0))
	_sword_attack_blast = float(mdef.get("blast_on_hit", 0.0))
	_sword_attack_blast_color = _spell_fx_color(String(mdef.get("blast_visual", "fire")))
	_sword_attack_pull = bool(mdef.get("pull_in", false))


# 近战命中后的特殊触发。每命中一只怪调一次。target 是被打的怪 (虚空秒杀要用)。
func _sword_on_hit(hit_pos: Vector2, target: Node2D) -> void:
	var player: Node2D = get_parent() as Node2D
	if player == null:
		return
	# 噬魂: 按这次伤害的百分比给玩家回血 (至少 1 滴)
	if _sword_attack_lifesteal > 0.0:
		var hp: Node = player.get_node_or_null("PlayerHealth")
		if hp != null and hp.has_method("heal"):
			hp.heal(max(1, int(round(float(_sword_attack_damage) * _sword_attack_lifesteal))))
	# 星陨: 从命中点上方天降几颗会爆的陨星
	if _sword_attack_meteor > 0:
		_spawn_meteors(hit_pos, _sword_attack_meteor, player)
	# 虚空: 概率秒杀, 但 Boss 免疫 (不然太破坏平衡)
	if _sword_attack_void > 0.0 and target != null and is_instance_valid(target) \
			and not target.is_in_group("boss") and randf() < _sword_attack_void:
		Effects.spawn_spell_impact("gas", target.global_position, Color8(120, 60, 200))   # 紫色虚空吞噬
		_deal_enemy_damage(target, 99999, hit_pos, 0.0)   # 海量伤害 = 秒杀小怪
	# 磁极: 把半径内的掉落物嗖地拉向玩家 (反复命中能把一地东西吸光)
	if _sword_attack_magnet > 0.0:
		_magnet_pull(player.global_position, _sword_attack_magnet)
	# 回响: 命中点过 echo_delay 秒后原地再爆一次 (额外一波 AoE)
	if _sword_attack_echo > 0.0:
		var echo_dmg: int = max(1, int(round(float(_sword_attack_damage) * 0.5)))
		# create_timer + connect (不 await): 到点回调 _echo_blast, 不卡当前帧
		get_tree().create_timer(_sword_attack_echo).timeout.connect(
			_echo_blast.bind(hit_pos, echo_dmg))
	# 赤霄: 命中刷新连击 (越打越快); 别的剑也会重置 idle 但 stacks 只对赤霄涨
	if _sword_attack_combo_haste:
		_combo_idle = 0.0
		_combo_stacks = min(COMBO_MAX, _combo_stacks + 1)
	# 雷神锤: 闪电从被打的怪往附近怪连跳
	if _sword_attack_chain > 0 and target != null and is_instance_valid(target):
		_chain_lightning(target, _sword_attack_chain)
	# 炼狱/巨力锤: 命中点立刻爆一圈 AoE
	if _sword_attack_blast > 0.0:
		var blast_dmg: int = max(1, int(round(float(_sword_attack_damage) * 0.5)))
		_aoe_blast(hit_pos, blast_dmg, _sword_attack_blast, _sword_attack_blast_color)
	# 深渊锤: 把怪往玩家这边拉 (代替击退)
	if _sword_attack_pull and target != null and is_instance_valid(target):
		target.global_position = target.global_position.move_toward(player.global_position, 60.0)


# 磁极拉取: 半径内非远程掉落物每次往玩家挪一大步, 配合自动拾取吸进背包。
func _magnet_pull(player_pos: Vector2, radius: float) -> void:
	for d in get_tree().get_nodes_in_group("item_drops"):
		var drop := d as Node2D
		if drop == null or drop.has_meta("is_remote"):
			continue
		if drop.global_position.distance_to(player_pos) <= radius:
			drop.global_position = drop.global_position.move_toward(player_pos, 140.0)


# 一圈 AoE 爆: 在 pos 半径内的怪都吃 dmg + 一个爆炸特效 (颜色按调用方给)。
func _aoe_blast(pos: Vector2, dmg: int, radius: float, color: Color) -> void:
	if not is_inside_tree():
		return
	Effects.spawn_spell_impact("explosion", pos, color)
	for group in ["slimes", "animals"]:
		for s in get_tree().get_nodes_in_group(group):
			var sn := s as Node2D
			if sn == null or not is_instance_valid(sn):
				continue
			if sn.global_position.distance_to(pos) <= radius:
				_deal_enemy_damage(sn, dmg, pos, 60.0)


# 回响延时爆: 紫光一圈 AoE。被 SceneTreeTimer 回调。
func _echo_blast(pos: Vector2, dmg: int) -> void:
	_aoe_blast(pos, dmg, 30.0, Color8(180, 120, 255))


# 雷神锤连锁闪电: 从 origin 怪开始, 一跳跳到最近的没打过的怪, 连 jumps 次。
func _chain_lightning(origin: Node2D, jumps: int) -> void:
	var dmg: int = max(1, int(round(float(_sword_attack_damage) * 0.6)))
	var hit_ids: Dictionary = {origin.get_instance_id(): true}
	var from: Node2D = origin
	for j in jumps:
		var nxt: Node2D = _nearest_enemy_not_in(from.global_position, hit_ids, 90.0)
		if nxt == null:
			break
		hit_ids[nxt.get_instance_id()] = true
		Effects.spawn_spell_impact("spark", nxt.global_position, Color8(150, 200, 255))   # 蓝白电火花
		_deal_enemy_damage(nxt, dmg, from.global_position, 40.0)
		from = nxt


# 找离 pos 最近、还没被 hit_ids 记过、在 max_dist 内的怪. 没有返回 null。
func _nearest_enemy_not_in(pos: Vector2, hit_ids: Dictionary, max_dist: float) -> Node2D:
	var best: Node2D = null
	var best_d: float = max_dist
	for group in ["slimes", "animals"]:
		for s in get_tree().get_nodes_in_group(group):
			var sn := s as Node2D
			if sn == null or not is_instance_valid(sn) or hit_ids.has(sn.get_instance_id()):
				continue
			var d: float = sn.global_position.distance_to(pos)
			if d < best_d:
				best_d = d
				best = sn
	return best


# 星陨陨星: n 颗 bullet 从目标上方带重力砸下, 落地/碰怪爆炸 (橙黄火光)。
func _spawn_meteors(pos: Vector2, n: int, player: Node2D) -> void:
	var entities: Node = get_tree().get_first_node_in_group("entities_root")
	if entities == null:
		entities = player.get_parent()
	var dmg: int = max(1, int(round(float(_sword_attack_damage) * 0.6 * _tool_damage_mult())))
	for i in n:
		# 每颗左右错开一点, 从上方不同高度落下 (用 i 散开, 不靠随机也能错位)
		var off_x: float = float(i - n / 2) * 18.0 + randf_range(-8.0, 8.0)
		var start: Vector2 = Vector2(pos.x + off_x, pos.y - 90.0 - float(i) * 14.0)
		var aim: Vector2 = Vector2(pos.x + off_x, pos.y + 40.0)   # 朝下砸
		var opts: Dictionary = {
			"gravity": 520.0,            # 越落越快, 像真的陨石
			"explode_radius": 26.0,
			"explode_dmg": max(1, int(round(float(dmg) * 0.7))),
			"impact_fx": "explosion",
			"impact_color": Color8(255, 170, 80),
			"fx_color": Color8(255, 210, 120),
			"visual": "fire",
		}
		var b = BulletScene.instantiate()
		entities.add_child(b)
		b.setup(start, aim, dmg, player, 150.0, opts)


var _active_flail: Node = null   # 当前在场的链锤球 (一次只一个)
const FlailScene = preload("res://scenes/entities/flail.tscn")


# 链锤神兵控制: 按住生成绕转的球, 松开甩出去。
func _update_flail(pressed: bool) -> void:
	var alive: bool = _active_flail != null and is_instance_valid(_active_flail)
	if pressed:
		# 按住且场上没球且冷却好了 → 生成一个绕玩家转的球
		if not alive and _attack_cooldown <= 0.0:
			_spawn_flail()
	else:
		# 松手且球还在绕 → 甩向鼠标
		if alive and _active_flail.is_orbiting():
			_release_flail()


func _spawn_flail() -> void:
	var player: Node2D = get_parent() as Node2D
	var mdef: Variant = _current_tool_def()
	if player == null or mdef == null:
		return
	_set_sword_special_fields(mdef)   # 让 _sword_on_hit 能跑 chain/blast/pull/吸血 等
	# 链锤伤害: 按 tier 基础 × damage_mult (flail 不是 sword, _sword_damage 取不到, 这里自己算)
	var base: int = _base_damage_for_tier(int(mdef.get("tool_tier", 5)))
	_sword_attack_damage = max(1, int(round(float(base) * float(mdef.get("damage_mult", 1.0)))))
	var entities: Node = get_tree().get_first_node_in_group("entities_root")
	if entities == null:
		entities = player.get_parent()
	var f = FlailScene.instantiate()
	entities.add_child(f)
	f.setup(player, self, _sword_attack_damage, mdef)
	_active_flail = f


func _release_flail() -> void:
	if _active_flail == null or not is_instance_valid(_active_flail):
		return
	var player: Node2D = get_parent() as Node2D
	var target: Vector2 = mouse_world_override if mouse_world_override != null else player.get_global_mouse_position()
	_active_flail.release(target)
	_active_flail = null   # 球之后自己飞回 + 消失
	_attack_cooldown = float((_current_tool_def() if _current_tool_def() != null else {}).get("melee_cooldown", 0.5))


# 链锤球命中怪时回调: 扣血 + 跑这把锤的特殊效果 (雷链/爆炸/吸怪/吸血...)。
func flail_hit(target: Node2D, pos: Vector2, kb: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	_deal_enemy_damage(target, _sword_attack_damage, pos, kb)
	_sword_on_hit(pos, target)


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
const BoomerangScene = preload("res://scenes/entities/boomerang.tscn")   # 回旋镖 (投掷武器)
const ShurikenScene = preload("res://scenes/entities/shuriken.tscn")     # 手里剑 (物理飞镖, 非魔法)
const FriendlySkeletonScene = preload("res://scenes/entities/friendly_skeleton.tscn")
const FriendlyBirdScene = preload("res://scenes/entities/friendly_bird.tscn")   # 雀宝宝法杖召唤
const EarthCrackScene = preload("res://scenes/entities/earth_crack.tscn")        # 地裂法杖
const BOW_COOLDOWN := 0.4
const BOW_ARROW_DAMAGE := 5    # base, 后续乘 tier multiplier
const GUN_COOLDOWN := 0.22     # 比弓快 (连发感)
const GUN_BULLET_DAMAGE := 9   # base, 比箭(5)狠; 后续乘 tier multiplier
const STAFF_COOLDOWN := 0.5    # 法杖 cd (mana 限制为主, cd 防自动连发)
const STAFF_BULLET_LIFETIME := 2.5   # 法杖球默认寿命 (秒) → 射程; 比枪弹 1.2 长一倍多 (用户要求加大距离)
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
# 没子弹反馈: 响一声空枪"哔" + 头顶飘"没子弹了" + 节流 0.4s (防按住时每帧刷). 用户要求 (枪没子弹别静默)。
func _no_ammo_feedback() -> void:
	_attack_cooldown = 0.4
	if SfxBank != null:
		SfxBank.play("gun_empty", 0.05)
	var parent: Node = get_parent()
	var fp: Node = get_tree().get_first_node_in_group("floating_prompt")
	if fp != null and fp.has_method("show_prompt") and parent is Node2D:
		fp.show_prompt((parent as Node2D).global_position + Vector2(0, -30), "没子弹了! 合成台造子弹")


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
		# 魔法枪跟法杖同款折扣 (修不一致: 之前法杖半价、魔法枪全价)
		var in_combat_gun: bool = NetworkManager != null and NetworkManager.combat_enabled()
		if not mana_n.try_consume(staff_mana_cost(mana_cost, in_combat_gun)):
			return   # 魔力不够 → 不发, 不进 cooldown
	else:
		var consumed: bool = false
		if NetworkManager != null and NetworkManager.combat_enabled():
			consumed = true   # 对战房: 子弹无限 (照箭)
		elif inv.has_method("consume_first"):
			consumed = inv.consume_first("bullet", 1)   # 一次扣 1 发 (霰弹也只 1 发, 出 N 弹丸, 划算)
		if not consumed:
			_no_ammo_feedback()   # 没子弹: 哔一声 + 飘提示 (别静默 → 不让玩家以为枪坏了)
			return
	# 每把枪自带参数 (从 item def 读); 没配的用手枪默认值. 加新枪只改 item_db, 不动这里.
	var cd: float = float(def.get("gun_cooldown", GUN_COOLDOWN)) if def != null else GUN_COOLDOWN
	var base_dmg: int = int(def.get("gun_damage", GUN_BULLET_DAMAGE)) if def != null else GUN_BULLET_DAMAGE
	var pellets: int = int(def.get("gun_pellets", 1)) if def != null else 1
	var spread_deg: float = float(def.get("gun_spread_deg", 0.0)) if def != null else 0.0
	var speed: float = float(def.get("bullet_speed", 0.0)) if def != null else 0.0  # 0 = 子弹默认速度
	# 枪系颜色: 枪口形状/子弹命中爆闪/打墙火星都用它 (普通子弹枪 = 暖黄白)
	var fam_color: Color = Color8(255, 220, 140)
	if def != null and def.has("gun_visual"):
		fam_color = _spell_fx_color(String(def.get("gun_visual")))
	# opts 统一走 _proj_opts_from_def (跟机制法杖共用, 一处维护; 之前这里手搓一遍重复 25 行)
	var opts: Dictionary = _proj_opts_from_def(def)
	opts["fx_color"] = fam_color   # 子弹小命中特效 (打怪爆闪/打墙火星) 跟枪系色走
	# 强力枪命中特效: 慢而狠的枪 (gun_impact) 命中还放大招牌特效; 快枪不配 (防刷屏)
	if def != null and bool(def.get("gun_impact", false)):
		var iv: String = String(def.get("gun_visual", ""))
		opts["impact_fx"] = _spell_impact_fx(iv) if iv != "" else "spark"
		opts["impact_color"] = _spell_fx_color(iv) if iv != "" else Color8(255, 230, 150)
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
	# 大威力枪开火震屏 (gun_shake 字段; 快枪不配 = 不震, 防晕)
	var shake_amt: float = float(def.get("gun_shake", 0.0)) if def != null else 0.0
	if shake_amt > 0.0 and parent.has_method("shake"):
		parent.shake(shake_amt)
	# 枪口火光: 每个枪系一种招牌形状 (星闪/扇楔/光束/火锥...), 多弹丸也只闪一次;
	# 大威力枪形状更大 (跟 gun_shake 挂钩)
	if Effects != null and Effects.has_method("spawn_muzzle_flash"):
		Effects.spawn_muzzle_flash(start + base_dir * 10.0, base_dir, fam_color, _muzzle_fx_kind(def), 1.0 + shake_amt * 0.25)
	# 每把枪自己的声音 (gun_sfx 字段; 没配 = 默认砰)
	SfxBank.play(String(def.get("gun_sfx", "gunshot")) if def != null else "gunshot", 0.08)


# 法杖发火球: 检查 mana 够 → 扣 → spawn fireball 朝鼠标飞.
# damage 跟 mana_cost 由 ItemDB.get_def() 配置 (hell_staff: 22 dmg / 20 mana).
# 法杖魔力消耗: 正常局 ×0.5 (减半), 对战房 ×0.2 (减 80%). 至少花 1 点. 纯函数, 供测试。
static func staff_mana_cost(base: int, combat: bool) -> int:
	var mult: float = 0.2 if combat else 0.5
	return maxi(1, int(round(float(base) * mult)))


func _try_cast_staff() -> void:
	var def: Variant = _current_tool_def()
	if def == null:
		return
	# 魔力消耗调低 (用户: 法杖太费魔力): 正常局减半, 对战房减 80% (随便放).
	var in_combat: bool = NetworkManager != null and NetworkManager.combat_enabled()
	var mana_cost: int = staff_mana_cost(int(def.get("mana_cost", 20)), in_combat)
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
	# 治疗法杖: 不发弹, 耗魔力给自己回血 (mana 已扣).
	if def.has("heal_amount"):
		var hp: Node = player.get_node_or_null("PlayerHealth")
		if hp != null and hp.has_method("heal"):
			hp.heal(int(def.get("heal_amount")))
		# 治疗特效: 玩家身上飘散一圈绿色魔法星 + 绿色回血数字 (一眼看出"我在回血")
		if Effects != null:
			if Effects.has_method("spawn_spell_impact"):
				Effects.spawn_spell_impact("sparkle", player.global_position + Vector2(0, -8), Color8(120, 230, 110))
			if Effects.has_method("spawn_damage_number"):
				Effects.spawn_damage_number(player.global_position + Vector2(0, -18), int(def.get("heal_amount")), Color8(120, 230, 110))
		SfxBank.play("pickup", 0.1)
		return
	# 护盾法杖: 不发弹, 给自己几秒无敌护盾 (mana 已扣).
	if def.has("shield_sec"):
		var hp2: Node = player.get_node_or_null("PlayerHealth")
		if hp2 != null and hp2.has_method("grant_shield"):
			hp2.grant_shield(float(def.get("shield_sec")))
		if Effects != null and Effects.has_method("spawn_spell_impact"):
			Effects.spawn_spell_impact("sparkle", player.global_position + Vector2(0, -8), Color8(120, 180, 255))
		SfxBank.play("pickup", 0.12)
		return
	var start: Vector2 = player.global_position + Vector2(0, -8)
	var target: Vector2 = mouse_world_override if mouse_world_override != null else player.get_global_mouse_position()
	var entities: Node = get_tree().get_first_node_in_group("entities_root")
	if entities == null:
		entities = player.get_parent()
	# 地裂法杖: 在目标地面生成一道伤害裂缝 (站上面的怪持续受伤), 不发弹.
	# 瞄到虚空 (下方没地面) 不放 → 退还魔力 + 取消冷却 (用户: 地裂不能放在虚空)。
	if def.has("ground_crack"):
		if not _cast_ground_crack(def, start, target, player, entities):
			if mana.has_method("refund"):
				mana.refund(mana_cost)
			_attack_cooldown = 0.0
		return
	# 新机制法杖 (spell_kind=="bullet"): 发"带机制的魔法弹"(复用枪的 bullet: 连锁/毒/多重等);
	# 老元素法杖 (fire/ice/nature) 还是发元素火球.
	if String(def.get("spell_kind", "fireball")) == "bullet":
		_cast_bullet_spell(def, start, target, player, entities)
		return
	var fb = FireballScene.instantiate()
	entities.add_child(fb)
	# damage_mult 让未来高 tier 法杖加伤
	var final_dmg: int = int(round(float(spell_dmg) * _tool_damage_mult()))
	fb.setup(start, target, final_dmg, true, element)   # true = player_cast, element = 元素弹
	# 火球法杖施法闪: 杖头按元素喷一下 (之前 wood/iron/hell 法杖发射无视觉 — 用户报"没特效")
	if Effects != null and Effects.has_method("spawn_muzzle_flash"):
		var fdir: Vector2 = (target - start)
		fdir = fdir.normalized() if fdir.length() > 0.01 else Vector2.RIGHT
		var ecol: Color = _spell_fx_color("poison") if element == "nature" else _spell_fx_color(element)
		var ekind: String = "frost" if element == "ice" else ("leaves" if element == "nature" else "flame")
		Effects.spawn_muzzle_flash(start + fdir * 10.0, fdir, ecol, ekind)
	if NetworkManager != null and NetworkManager.connected():
		# kind 带上元素 (fireball_nature/ice/fire), 对端按后缀还原弹色
		NetworkManager.send_projectile("fireball_" + element, start.x, start.y, target.x, target.y)
	SfxBank.play("cast", 0.12)


# 从 def 的 gun_*/bullet_* 字段构建 bullet opts (枪 + 新法杖共用; 字段名沿用 gun_*,
# bullet 不在乎名字, 都是"投射物机制": 穿透/减速/毒/连锁/反弹/重力/追踪/外观/寿命).
func _proj_opts_from_def(def: Variant) -> Dictionary:
	var opts: Dictionary = {}
	if def == null:
		return opts
	if bool(def.get("gun_pierce", false)):
		opts["pierce"] = true
	if def.has("gun_slow_factor"):
		opts["slow_factor"] = float(def.get("gun_slow_factor"))
		opts["slow_dur"] = float(def.get("gun_slow_dur", 2.0))
	if def.has("gun_visual"):
		opts["visual"] = String(def.get("gun_visual"))
	if def.has("bullet_lifetime"):
		opts["lifetime"] = float(def.get("bullet_lifetime"))
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
	# B 波法杖: 爆炸范围伤害 / 击飞
	if def.has("gun_explode_radius"):
		opts["explode_radius"] = float(def.get("gun_explode_radius"))
		opts["explode_dmg"] = int(def.get("gun_explode_dmg", 0))
	# 水之法杖: 只落地(撞实心方块)才炸, 空中穿过怪不引爆 → 球一直飞到落到方块 (用户要求)
	if bool(def.get("gun_explode_on_land_only", false)):
		opts["explode_on_land_only"] = true
	if def.has("gun_knockback"):
		opts["knockback"] = float(def.get("gun_knockback"))
	if bool(def.get("gun_launch", false)):
		opts["launch"] = true
	return opts


# 机制法杖发弹: 跟枪同一套 bullet (含多重 gun_pellets / 扇形 gun_spread_deg). 已扣 mana.
func _cast_bullet_spell(def: Variant, start: Vector2, target: Vector2, parent: Node2D, entities: Node) -> void:
	var dmg: int = int(round(float(def.get("spell_damage", 10)) * _tool_damage_mult()))
	var speed: float = float(def.get("bullet_speed", 0.0))
	var pellets: int = int(def.get("gun_pellets", 1))
	var spread_deg: float = float(def.get("gun_spread_deg", 0.0))
	var opts: Dictionary = _proj_opts_from_def(def)
	# 法杖特效: 命中时按 visual 放对应形状的粒子 (闪电星/毒云/魔法星/风条/火爆/水花), 颜色也按 visual。
	# 不再发射时闪 (用户: 别的法杖也别在发射就触发) — 飞行弹本身就看得见, 命中才放特效。
	var vis: String = String(def.get("gun_visual", "magic"))
	opts["impact_fx"] = _spell_impact_fx(vis)
	opts["impact_color"] = _spell_fx_color(vis)
	opts["fx_color"] = _spell_fx_color(vis)   # 小命中特效 (打怪爆闪/打墙火星) 同色
	# 法杖球射程: 没单独设 bullet_lifetime 的, 用更长的默认寿命 (用户: 加大法球距离上限)
	if not opts.has("lifetime"):
		opts["lifetime"] = STAFF_BULLET_LIFETIME
	var base_dir: Vector2 = target - start
	base_dir = base_dir.normalized() if base_dir.length() > 0.01 else Vector2.RIGHT
	for _i in max(1, pellets):
		var dir: Vector2 = base_dir
		if spread_deg > 0.0:
			dir = base_dir.rotated(deg_to_rad(randf_range(-spread_deg * 0.5, spread_deg * 0.5)))
		var aim: Vector2 = start + dir * 100.0
		var b = BulletScene.instantiate()
		entities.add_child(b)
		b.setup(start, aim, dmg, parent, speed, opts)
		if NetworkManager != null and NetworkManager.connected():
			NetworkManager.send_projectile("bullet", start.x, start.y, aim.x, aim.y)
	# 施法时法杖头闪一下招牌形状 (跟枪口火光同套路; 用户: 法杖头没闪光)
	if Effects != null and Effects.has_method("spawn_muzzle_flash"):
		Effects.spawn_muzzle_flash(start + base_dir * 8.0, base_dir, _spell_fx_color(vis), _muzzle_fx_kind(def), 1.0)
	SfxBank.play("cast", 0.12)


# 枪系 → 枪口招牌形状 (照法杖招牌特效思路, 每个枪系开火形状不同, 不再全是粒子)
func _muzzle_fx_kind(def: Variant) -> String:
	if def == null:
		return "star"
	match String(def.get("gun_visual", "")):
		"laser":     return "beam"    # 激光/电磁炮: 短光束
		"fire":      return "flame"   # 火焰/火箭: 火锥
		"ice":       return "frost"   # 冰系: 冰晶刺
		"lightning": return "arc"     # 闪电/特斯拉: 小电弧
		"magic":     return "rune"    # 魔法枪: 旋转符文环
		"poison":    return "drip"    # 毒系: 喷液珠
		"slimeblob": return "splat"   # 史莱姆: 果冻溅开
		"leaf":      return "leaves"  # 绿叶: 叶片回旋
		"star":      return "star"    # 星星/弹跳: 金色星闪
	# 无属性枪: 多弹丸 (霰弹) 用扇楔, 其余经典枪口星
	return "fan" if int(def.get("gun_pellets", 1)) > 1 else "star"


# 法杖弹的 visual → 命中特效的"形状" (每把法杖不同, 不再全是同一种爆炸)
func _spell_impact_fx(visual: String) -> String:
	match visual:
		"lightning": return "spark"      # 闪电: 星形快火花
		"poison":    return "gas"        # 毒: 慢散毒云
		"magic":     return "sparkle"    # 多重: 飘散魔法星
		"fire":      return "explosion"  # 爆裂: 大爆炸
		"ice":       return "splash"     # 水之: 溅水花
		"wind":      return "gust"       # 狂风: 横向风条
		"laser":     return "spark"      # 激光/电磁炮: 星形快火花
		"star":      return "sparkle"    # 星星: 魔法星
		"slimeblob": return "gas"        # 史莱姆: 黏液团散开
		"leaf":      return "sparkle"    # 绿叶: 叶屑飘散
		_:           return "sparkle"


# 法杖弹的 visual → 施法/命中火花的颜色 (跟弹色一致, 一眼能认是哪把法杖)
func _spell_fx_color(visual: String) -> Color:
	match visual:
		"lightning": return Color8(255, 235, 90)   # 黄电
		"poison":    return Color8(120, 200, 60)    # 绿毒
		"fire":      return Color8(255, 150, 40)    # 橙火
		"ice":       return Color8(90, 180, 240)    # 冰蓝
		"wind":      return Color8(210, 240, 255)   # 白青
		"laser":     return Color8(255, 90, 80)     # 激光红
		"star":      return Color8(255, 215, 90)    # 星金
		"slimeblob": return Color8(110, 220, 90)    # 黏液绿
		"leaf":      return Color8(120, 200, 80)    # 叶绿
		_:           return Color8(180, 100, 235)   # 紫 (多重/魔法弹默认)


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
	# summon_kind 决定召谁: "bird" → 雀宝宝 (飞), 默认 → 友方骷髅 (走)
	var summon_kind: String = String(def.get("summon_kind", "skeleton"))
	var minion = FriendlyBirdScene.instantiate() if summon_kind == "bird" else FriendlySkeletonScene.instantiate()
	var entities: Node = get_tree().get_first_node_in_group("entities_root")
	if entities == null:
		entities = player.get_parent()
	entities.add_child(minion)
	# 鸟从头顶冒出来, 骷髅从脚边
	var spawn_off: Vector2 = Vector2(randf_range(-16.0, 16.0), -28.0 if summon_kind == "bird" else -4.0)
	minion.global_position = player.global_position + spawn_off
	# 召唤特效: 召出点炸一圈魔法星 (之前召唤法杖只有声音, 没视觉 — 用户报"没特效")
	if Effects != null and Effects.has_method("spawn_spell_impact"):
		var summon_col: Color = Color8(255, 230, 120) if summon_kind == "bird" else Color8(190, 160, 235)
		Effects.spawn_spell_impact("sparkle", minion.global_position, summon_col)
	SfxBank.play("place", 0.15)


# 地裂法杖: 从瞄准点向下找地面, 在地表生成一道裂缝 (earth_crack). 已扣 mana.
# 在瞄准点下方的地面生成裂缝。返回 true=放好了; false=瞄到虚空(下方没地面)没放,
# 调用方据此退还魔力 (用户: 地裂不能放在虚空)。
func _cast_ground_crack(def: Variant, _start: Vector2, target: Vector2, player: Node2D, entities: Node) -> bool:
	var terrain: TileMapLayer = _terrain()
	if terrain == null:
		return false
	# 从瞄准点所在格往下扫, 找到第一块实心方块 → 裂缝放在它顶上
	var tile: Vector2i = terrain.local_to_map(terrain.to_local(target))
	var ground_y: int = -9999
	for dy in range(0, 20):   # 最多往下找 20 格
		var c: Vector2i = tile + Vector2i(0, dy)
		if terrain.get_cell_source_id(c) != -1:
			ground_y = c.y
			break
	if ground_y == -9999:
		return false   # 瞄准点下方 20 格内没地面 = 虚空, 不放 (魔力由调用方退还)
	# 实心格顶部 = 该格中心上移半格
	var crack_pos: Vector2 = terrain.to_global(terrain.map_to_local(Vector2i(tile.x, ground_y))) + Vector2(0, -8)
	var crack = EarthCrackScene.instantiate()
	entities.add_child(crack)
	crack.global_position = crack_pos
	if crack.has_method("setup"):
		crack.setup(int(round(float(def.get("spell_damage", 6)) * _tool_damage_mult())), player)
	SfxBank.play("break", 0.18)
	return true


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


# 投掷武器: 手里剑/炸弹走 bullet (复用枪/法杖那套机制+特效); 回旋镖走自定义 boomerang。
func _try_throw_weapon() -> void:
	var def: Variant = _current_tool_def()
	if def == null:
		return
	var player: Node2D = get_parent() as Node2D
	if player == null:
		return
	var start: Vector2 = player.global_position + Vector2(0, -8)
	var target: Vector2 = mouse_world_override if mouse_world_override != null else player.get_global_mouse_position()
	var entities: Node = get_tree().get_first_node_in_group("entities_root")
	if entities == null:
		entities = player.get_parent()
	var dmg: int = int(round(float(def.get("thrown_damage", 6)) * _tool_damage_mult()))
	_attack_cooldown = float(def.get("throw_cooldown", 0.4))
	var tkind: String = String(def.get("throw_kind", "bullet"))
	if tkind == "boomerang":
		var bm = BoomerangScene.instantiate()
		entities.add_child(bm)
		bm.setup(start, target, dmg, player)
		SfxBank.play("break", 0.10)
		return
	if tkind == "shuriken":
		# 手里剑: 物理金属飞镖 (旋转图标 + 穿透 + 小火星), 不走魔法弹 → 没星星贴图/没魔法拖尾 (用户报)
		var shk = ShurikenScene.instantiate()
		entities.add_child(shk)
		shk.setup(start, target, dmg, player)
		SfxBank.play("break", 0.10)
		return
	# 手里剑/炸弹: 复用 bullet (炸弹靠 gun_gravity+gun_explode_*, 手里剑靠 gun_pierce) + 命中招牌特效
	var opts: Dictionary = _proj_opts_from_def(def)
	var vis: String = String(def.get("gun_visual", "star"))
	opts["impact_fx"] = _spell_impact_fx(vis)
	opts["impact_color"] = _spell_fx_color(vis)
	var speed: float = float(def.get("bullet_speed", 480.0))
	var base_dir: Vector2 = target - start
	base_dir = base_dir.normalized() if base_dir.length() > 0.01 else Vector2.RIGHT
	var aim: Vector2 = start + base_dir * 100.0
	var b = BulletScene.instantiate()
	entities.add_child(b)
	b.setup(start, aim, dmg, player, speed, opts)
	if NetworkManager != null and NetworkManager.connected():
		NetworkManager.send_projectile("bullet", start.x, start.y, aim.x, aim.y)
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
