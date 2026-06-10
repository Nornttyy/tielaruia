# 手持物品视觉. 跟着 hotbar 选中的物品显示在玩家手里, 攻击/挖矿时挥摆动画.
# 由 player_controller 在 _ready 绑定 inventory + 每帧 set_facing; 由 player_action 在
# 挥剑/挖矿时调 play_swing.
#
# 关键点: sprite 的旋转/缩放支点 = 玩家手部. 用 centered=false + offset 把贴图的
# 底部中心对齐到 position 这个"手"点, 这样挥摆时手柄不离手, 像真的握住一样.
extends Sprite2D

const HAND_OFFSET_X := 5.0     # 手相对玩家中心 x 偏移 (玩家 1.25x 放大后跟着外移)
const HAND_OFFSET_Y := -10.0   # y (玩家中部胸口位置, 1.25x)
const TOOL_SIZE := 1.25        # 工具 (剑/镐/斧) 跟玩家 1.25x 一起放大
const BLOCK_SIZE := 0.6875     # 方块/材料 = TOOL_SIZE × 0.55 (~11px)
const SWING_ANGLE_DEG := 75.0
const SWING_DURATION := 0.50   # 用户调: 剑挥转速降低 (挥得更慢更有分量, 现 0.5s)

var _player_inventory: Node = null
var _facing_right: bool = true
var _tween: Tween = null
var _current_size: float = TOOL_SIZE
var _eating: bool = false
var _eat_phase: float = 0.0   # 进食动画时间累积 (秒)
# 工具只在"使用时"才显示 (用户要求): 平时藏起来, 挥/挖/戳/放/射/吃时才冒出来, 用完自动收.
var _has_item: bool = false   # 当前 hotbar 槽有可显示物品 (有贴图)
var _use_timer: float = 0.0   # 还要显示多少秒; 用一下刷新, 归零自动收起
const _HIDE_GRACE := 0.35     # 动作结束后再多显示这么久 (防连挥/连挖时闪烁)
# 攻击期间锁 facing: player_controller 每帧 set_facing 跟玩家走路方向,
# 攻击中翻 facing 会让 sprite 镜像但旋转值还是攻击时算的 → 朝向乱套. 锁住期间忽略.
var _attack_locked: bool = false
var _aiming_gun: bool = false   # 枪瞄准态: 临时用居中支点绕枪中心转 (跟剑底端支点不同)


func _ready() -> void:
	# 支点放在贴图底部中心: 玩家手抓在物品底端 (剑柄 / 方块底沿)
	centered = false
	offset = Vector2(-8, -16)
	position = Vector2(HAND_OFFSET_X, HAND_OFFSET_Y)
	visible = false
	z_index = 1  # 画在玩家身体前面


func bind_inventory(inv: Node) -> void:
	_player_inventory = inv
	if inv.has_signal("hotbar_selection_changed"):
		inv.hotbar_selection_changed.connect(_on_changed)
	if inv.has_signal("inventory_changed"):
		inv.inventory_changed.connect(_on_changed)
	_refresh()


# 用一下 → 显示 (只在有物品时); 持续 anim_dur + 宽限期后, _process 自动收起.
func _show_for(anim_dur: float) -> void:
	if not _has_item:
		return
	_reset_aim_transform()   # 任何普通显示都先退出枪瞄准态 (恢复底端支点); aim_gun 不走这
	visible = true
	_use_timer = maxf(_use_timer, anim_dur + _HIDE_GRACE)


# 从枪瞄准态切回普通显示 (恢复 centered=false + 底端支点 offset + 解锁 facing).
func _reset_aim_transform() -> void:
	if not _aiming_gun:
		return
	_aiming_gun = false
	_attack_locked = false
	centered = false
	offset = Vector2(-8, -16)
	rotation = 0.0
	_apply_scale()


# 枪: 整把朝鼠标方向. angle = 鼠标相对玩家的角度 (rad, 0=右). 贴图朝右(+X),
# 朝左半边竖直翻转 (scale.y 取负) 防止枪倒置 (握把始终朝下).
func aim_gun(angle: float) -> void:
	if not _has_item:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_aiming_gun = true
	_attack_locked = true
	visible = true
	_use_timer = maxf(_use_timer, 0.18 + _HIDE_GRACE)
	centered = true          # 绕枪中心转 (不是底端)
	offset = Vector2.ZERO
	var on_right: bool = cos(angle) >= 0.0
	var sz: float = _current_size
	scale = Vector2(sz, sz if on_right else -sz)
	rotation = angle
	position = Vector2(HAND_OFFSET_X if on_right else -HAND_OFFSET_X, HAND_OFFSET_Y)


# 短暂闪一下 (射箭 / 施法 等没有专门动画的"使用"给点反馈)
func flash() -> void:
	_show_for(0.0)


const PLACE_DURATION := 0.22       # 放方块动画: 短促有力 (按一下)
const PLACE_REACH_PX := 7.0        # 方块朝放置点伸出去多少 px

# 放方块: 手里的方块朝放置点"按"出去一下再弹回 (像把方块按进去). 不旋转 — 方块不转.
func play_place(target_angle: float) -> void:
	if not _has_item:
		return
	_show_for(PLACE_DURATION)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_attack_locked = false
	var mouse_on_right: bool = cos(target_angle) >= 0.0
	set_facing(mouse_on_right)
	_attack_locked = true     # 锁 facing, 别让走路方向跟动画打架
	rotation = 0.0
	var base_pos := Vector2(HAND_OFFSET_X if _facing_right else -HAND_OFFSET_X, HAND_OFFSET_Y)
	var reach_pos := base_pos + Vector2(cos(target_angle), sin(target_angle)) * PLACE_REACH_PX
	position = base_pos
	_tween = create_tween()
	_tween.tween_property(self, "position", reach_pos, PLACE_DURATION * 0.4).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", base_pos, PLACE_DURATION * 0.6).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func(): _attack_locked = false)


func set_facing(right: bool) -> void:
	# 攻击中: 忽略 player_controller 的 facing 更新, 否则跟 play_thrust/swing 算的
	# 旋转值打架 (sprite 翻面但旋转还是攻击方向 → 朝向反了)
	if _attack_locked:
		return
	if right == _facing_right:
		return
	_facing_right = right
	_apply_scale()
	position.x = HAND_OFFSET_X if right else -HAND_OFFSET_X


# 进食动画开始: 食物上下抖动 + 微微旋转, 模拟"啃咬"
func start_eat() -> void:
	if not _has_item:
		return
	_eating = true
	visible = true   # 吃东西时显示食物
	_eat_phase = 0.0
	# 把潜在的挥摆 tween 杀掉, 避免冲突
	if _tween != null and _tween.is_valid():
		_tween.kill()


# 进食动画结束: 食物归位
func stop_eat() -> void:
	_eating = false
	_eat_phase = 0.0
	position = Vector2(HAND_OFFSET_X if _facing_right else -HAND_OFFSET_X, HAND_OFFSET_Y)
	rotation = 0.0
	visible = false   # 吃完收起来


func _process(delta: float) -> void:
	# 不在吃东西时: 用完计时归零 → 收起来 (工具只在使用时显示)
	if not _eating and _use_timer > 0.0:
		_use_timer -= delta
		if _use_timer <= 0.0:
			visible = false
	if not _eating or not visible:
		return
	_eat_phase += delta
	# 每 0.4 秒一次"啃咬" 循环 (2 秒共 5 口的节奏)
	var t: float = fmod(_eat_phase, 0.4) / 0.4   # 0..1 循环
	# 食物上下抖: 嘴边 (y - 6) ↔ 手里 (y + 0), 用正弦曲线让上下平滑
	var lift: float = sin(t * PI) * 7.5   # 0 → 7.5 → 0 (玩家 1.25x)
	position = Vector2(
		HAND_OFFSET_X if _facing_right else -HAND_OFFSET_X,
		HAND_OFFSET_Y - lift
	)
	# 食物轻微转一下, 看起来在咬
	var dir: float = 1.0 if _facing_right else -1.0
	rotation = sin(t * PI) * 0.25 * dir   # 最多 ±0.25 rad ≈ 14 度


func play_swing() -> void:
	# 节奏性挥摆 (挖矿/砍木用): 朝当前 facing 摆 ±75°
	if not _has_item:
		return
	_show_for(SWING_DURATION)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	rotation = 0.0
	_tween = create_tween()
	var dir: float = 1.0 if _facing_right else -1.0
	_tween.tween_property(self, "rotation", deg_to_rad(-30.0 * dir), SWING_DURATION * 0.25)
	_tween.tween_property(self, "rotation", deg_to_rad(SWING_ANGLE_DEG * dir), SWING_DURATION * 0.35)
	_tween.tween_property(self, "rotation", 0.0, SWING_DURATION * 0.40)


const THRUST_DURATION := 0.30           # 用户调: 戳要在前端"停"一下 (本来 0.15 闪过去太快)
const THRUST_EXTEND_RATIO := 0.20       # 前 20% = 突出去 (0.06s)
const THRUST_HOLD_RATIO := 0.55         # 中 55% = 在前面 dwell (0.165s, 主要打击窗口)
const THRUST_RETRACT_RATIO := 0.25      # 后 25% = 收回来 (0.075s)
const THRUST_OFFSET_PX := 8.0    # 工具向前突进的距离 (用户: 短剑戳得太远 → 12.5 调到 8)
const PICKAXE_ATTACK_DURATION := 1.0   # 用户改 0.7→1.0 转慢一点


# 镐攻击: 工具全周转 360°. 用户改: 起始朝鼠标 (target_angle), 不再总从上方开始.
# target_angle: 鼠标相对玩家的角度 (radians, 0 = 右). 默认 -PI/2 = 上 (兼容老调用).
func play_pickaxe_attack(target_angle: float = -PI / 2.0) -> void:
	if not _has_item:
		return
	_show_for(PICKAXE_ATTACK_DURATION)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_attack_locked = false
	# 跟着鼠标 facing (跟剑 sweep 同套路, 不靠玩家走路方向)
	var mouse_on_right: bool = cos(target_angle) >= 0.0
	set_facing(mouse_on_right)
	_attack_locked = true
	# sprite 默认朝上 (tip 在 -y), 要让 tip 起步朝 target_angle 得 + PI/2.
	# facing_left 时 sprite 已水平翻转, 旋转要反向.
	var s: float = 1.0 if _facing_right else -1.0
	var start_rot: float = wrapf(s * (target_angle + PI / 2.0), -PI, PI)
	rotation = start_rot
	_tween = create_tween()
	var dir: float = 1.0 if _facing_right else -1.0
	_tween.tween_property(self, "rotation", start_rot + deg_to_rad(360.0 * dir), PICKAXE_ATTACK_DURATION)
	_tween.tween_callback(func():
		rotation = 0.0
		_attack_locked = false
	)


# 戳 (剑): 朝鼠标方向向前突再收回, 不旋转 (跟挥不同, 挥是转圈弧)
func play_thrust(target_angle: float) -> void:
	if not _has_item:
		return
	_show_for(THRUST_DURATION)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_attack_locked = false   # 先解锁, set_facing 才能跟着鼠标转
	var mouse_on_right: bool = cos(target_angle) >= 0.0
	set_facing(mouse_on_right)
	_attack_locked = true    # 锁住, 后续 player_controller set_facing 被忽略
	var dir_vec := Vector2(cos(target_angle), sin(target_angle))
	var base_pos := Vector2(HAND_OFFSET_X if _facing_right else -HAND_OFFSET_X, HAND_OFFSET_Y)
	var thrust_pos := base_pos + dir_vec * THRUST_OFFSET_PX
	# 剑尖朝鼠标. sword sprite 默认尖朝上 (-y), 要尖朝 target_angle 得旋转 target_angle + PI/2.
	# 剑尖在 sprite 中心列 (x≈8), 水平翻转 (set_facing 的 scale.x=-1) 不改变剑尖方向, 所以这里
	# 不需要按 facing 反向 — 之前用 s * 反向是 bug, 导致鼠标在左时剑尖指到镜像方向.
	rotation = wrapf(target_angle + PI / 2.0, -PI, PI)
	position = base_pos
	_tween = create_tween()
	# 三段式: 突出 → dwell (保持 thrust_pos) → 收回. 主要 hit 窗口在 dwell.
	_tween.tween_property(self, "position", thrust_pos, THRUST_DURATION * THRUST_EXTEND_RATIO).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(THRUST_DURATION * THRUST_HOLD_RATIO)
	_tween.tween_property(self, "position", base_pos, THRUST_DURATION * THRUST_RETRACT_RATIO).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func():
		rotation = 0.0
		_attack_locked = false
	)


func play_swing_directional(target_angle: float) -> void:
	# 定向挥击 (挥剑用): 沿 target_angle 方向划 180° 半圆 (用户改: Terraria 风).
	# 攻击时把 sprite 朝向锁到鼠标方向, 避免移动中翻面让剑乱飞.
	if not _has_item:
		return
	_show_for(SWING_DURATION * 1.7)   # 挥 + 归位全程都显示
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_attack_locked = false
	var mouse_on_right: bool = cos(target_angle) >= 0.0
	set_facing(mouse_on_right)  # 跟鼠标走, 不跟玩家走路方向
	_attack_locked = true
	# 不乘 facing 符号: 剑尖在中心列, 水平翻转不改变剑尖方向; 乘 s 会让"瞄左"和"瞄右"算出同一个
	# base → 永远往同一边挥 (= 用户报的"瞄左却往右挥" bug, 跟 play_thrust 早先修过的同款 s 反向 bug).
	var base: float = wrapf(target_angle + PI / 2.0, -PI, PI)
	# 弧线方向随朝向镜像: 瞄右从上往右下劈, 瞄左从上往左下劈。剑尖在中心列, 翻转不影响剑尖方向,
	# 所以瞄左若跟瞄右同向扫 → 剑尖会从下往上走 = "挑" (用户报的 bug)。瞄左把扫向反过来。
	var half: float = deg_to_rad(110.0) if mouse_on_right else -deg_to_rad(110.0)
	var start_a: float = base - half
	var end_a:   float = base + half
	rotation = start_a
	_tween = create_tween()
	# 挥 (打击窗口, 跟 player_action 命中判定的 180°/SWING_DURATION 同步)
	_tween.tween_property(self, "rotation", end_a, SWING_DURATION)
	# 挥完归位到 0 (休息位), 别卡在 end_a — 否则连挥时下一刀从 end_a 瞬弹回 start_a = 抽搐.
	# 归位在打击窗口之后跑 (冷却间隙内), 不影响命中判定; facing 锁也顺延到归位完才松.
	_tween.tween_property(self, "rotation", 0.0, SWING_DURATION * 0.7)
	_tween.tween_callback(func(): _attack_locked = false)


const BOW_SHOOT_DURATION := 0.35   # 放箭后弓朝鼠标保持 + 回正的总时长 (略长过冷却才看得到瞄准姿势)
const BOW_RECOIL_PX := 4.0         # 放箭瞬间弓沿瞄准方向小幅前冲再收回 (松弦反冲感)

# 射箭姿势: 让手里的弓转向鼠标 (之前 bug: 箭朝鼠标飞但弓一直竖着不转, 看着没瞄准).
# target_angle: 鼠标相对玩家的角度 (radians, 0 = 右).
func play_bow_shoot(target_angle: float) -> void:
	if not _has_item:
		return
	_show_for(BOW_SHOOT_DURATION)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_attack_locked = false
	var mouse_on_right: bool = cos(target_angle) >= 0.0
	set_facing(mouse_on_right)
	_attack_locked = true
	# 弓图标的"射击口"朝 -x (左: 弓臂在左鼓出, 弦在右, 箭往弓臂那侧飞出). 要让射击口朝鼠标:
	# 没镜像 (瞄右 sx=+1) 时屏幕射向 = rotation + PI → rotation = target_angle - PI;
	# 镜像了 (瞄左 sx=-1) 时屏幕射向 = rotation → rotation = target_angle. (之前 bug: 两分支接反 = 方向反了)
	rotation = wrapf(target_angle - (PI if mouse_on_right else 0.0), -PI, PI)
	var base_pos := Vector2(HAND_OFFSET_X if _facing_right else -HAND_OFFSET_X, HAND_OFFSET_Y)
	position = base_pos
	var nudge := Vector2(cos(target_angle), sin(target_angle)) * BOW_RECOIL_PX
	_tween = create_tween()
	_tween.tween_property(self, "position", base_pos + nudge, BOW_SHOOT_DURATION * 0.25).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(BOW_SHOOT_DURATION * 0.35)
	_tween.tween_property(self, "position", base_pos, BOW_SHOOT_DURATION * 0.40).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func():
		rotation = 0.0
		_attack_locked = false
	)


func _on_changed(_arg = null) -> void:
	_refresh()


func _refresh() -> void:
	if _player_inventory == null:
		_has_item = false
		visible = false
		return
	var slot = _player_inventory.current_hotbar_slot()
	if slot == null:
		_has_item = false
		visible = false
		return
	var tex: Texture2D = ArtCache.get_inventory_icon(slot.item_id)
	if tex == null:
		_has_item = false
		visible = false
		return
	texture = tex
	_has_item = true
	# 注意: 不再常驻 visible=true. 只更新贴图/缩放; 显隐交给"使用时"逻辑 (_show_for/flash/_process).
	# 切 hotbar 不会让工具凭空冒出来 — 下次挥/挖/放/射/吃才显示.
	# 工具用原大小, 其他物品缩小
	_current_size = TOOL_SIZE if _is_tool(slot.item_id) else BLOCK_SIZE
	_apply_scale()


func _is_tool(item_id: String) -> bool:
	var def = ItemDB.get_def(item_id)
	return def != null and def.tool_kind != ""


func _apply_scale() -> void:
	var sx: float = _current_size if _facing_right else -_current_size
	scale = Vector2(sx, _current_size)
