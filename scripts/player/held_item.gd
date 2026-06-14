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
const SWEEP_HELD_SCALE := 1.4  # 阔剑/双刀等 sweep 近战手持再放大 (用户嫌太小)
const GUN_HELD_SCALE := 0.8    # 枪图标画宽到 20px 了, 手持缩回原比例 (用户嫌太大)
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
	offset = _grip_offset()
	position = Vector2(HAND_OFFSET_X, HAND_OFFSET_Y)
	visible = false
	z_index = 1  # 画在玩家身体前面


# 握把支点 = 贴图底部中心 (按当前贴图大小算, 支持任意画布大小, 不再写死 16×16)。
func _grip_offset() -> Vector2:
	if texture != null:
		return Vector2(-texture.get_width() / 2.0, -float(texture.get_height()))
	return Vector2(-8, -16)


# 挥砍/戳/施法时武器本体亮一下 (用户要"挥动时闪光")。modulate 提亮再渐回。
func _swing_flash() -> void:
	modulate = Color(1.7, 1.7, 1.7, 1.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.2)


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
	offset = _grip_offset()
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


var _after_t: float = 0.0       # 残影剩余时间 (>0 时挥砍中, 每隔几帧留个残影)
var _after_accum: float = 0.0   # 距上次留残影过了多久


# 留一个当前姿势的淡蓝半透残影 (Sprite2D 复制, 自己淡出消失)。
func _spawn_afterimage() -> void:
	if texture == null:
		return
	var g := Sprite2D.new()
	g.texture = texture
	g.texture_filter = texture_filter   # 保持像素 (NEAREST)
	g.centered = centered
	g.offset = offset
	var parent: Node = get_parent()
	if parent == null:
		return
	parent.add_child(g)
	g.global_transform = global_transform   # 抄当前位置/旋转/翻转
	g.z_index = z_index - 1
	g.modulate = Color(0.7, 0.85, 1.0, 0.5)   # 淡蓝半透
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.18)
	tw.tween_callback(g.queue_free)


func _process(delta: float) -> void:
	# 不在吃东西时: 用完计时归零 → 收起来 (工具只在使用时显示)
	if not _eating and _use_timer > 0.0:
		_use_timer -= delta
		if _use_timer <= 0.0:
			visible = false
	# 残影: 挥砍期间每 ~0.04s 复制一个淡蓝半透贴图 (留在原地淡出 = 拖影)
	if _after_t > 0.0 and visible and _has_item:
		_after_t -= delta
		_after_accum += delta
		if _after_accum >= 0.04:
			_after_accum = 0.0
			_spawn_afterimage()
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
# 通知玩家身体也做挥击动作 (held_item 是 player 的子节点)。
func _notify_body_swing() -> void:
	var p: Node = get_parent()
	if p != null and p.has_method("play_action_anim"):
		p.play_action_anim("swing", 0.28)


func play_pickaxe_attack(target_angle: float = -PI / 2.0) -> void:
	if not _has_item:
		return
	_notify_body_swing()   # 镐/斧 挥击 (挖矿 + 战斗): 身体也挥一下
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


# 戳 (剑/矛): 朝鼠标方向向前突再收回, 不旋转 (跟挥不同, 挥是转圈弧)。
# lunge_px: 往前突多远 (短剑小, 长矛大 — 矛长就要刺得远才像个刺, 不然只是小抖 = 抽搐)。
func play_thrust(target_angle: float, lunge_px: float = THRUST_OFFSET_PX) -> void:
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
	var thrust_pos := base_pos + dir_vec * lunge_px
	# 剑尖朝鼠标. sword sprite 默认尖朝上 (-y), 尖朝 target_angle 得旋转 target_angle + PI/2.
	rotation = wrapf(target_angle + PI / 2.0, -PI, PI)
	position = base_pos
	_swing_flash()   # 出刀闪一下
	_tween = create_tween()
	# 三段式: 突出 → dwell (保持 thrust_pos) → 收回. 主要 hit 窗口在 dwell.
	_tween.tween_property(self, "position", thrust_pos, THRUST_DURATION * THRUST_EXTEND_RATIO).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(THRUST_DURATION * THRUST_HOLD_RATIO)
	_tween.tween_property(self, "position", base_pos, THRUST_DURATION * THRUST_RETRACT_RATIO).set_ease(Tween.EASE_IN)
	# 收回后不再把 rotation 归 0 (之前每戳完弹回竖直 = 连戳时上下抽)。保持指向鼠标,
	# 下一戳无缝接上; 武器收起 (visible=false) 时自然失效, 不影响别的姿势。
	_tween.tween_callback(func(): _attack_locked = false)


var _dual_flip: bool = false   # 双刀: 每次挥交替左右, 看着像左一刀右一刀的连斩

# 定向挥击 (挥剑用): 沿 target_angle 方向划 180° 半圆 (Terraria 风)。
# swing_dur: 这一挥转多久 (双刀很快, 要跟它的攻击间隔对齐, 否则被打断从头转 = 抽搐)。
# fast: 双刀连斩模式 — 不归位到 0 (省得弹回), 改成每刀从另一边起手, 自然来回扫。
func play_swing_directional(target_angle: float, swing_dur: float = SWING_DURATION, fast: bool = false) -> void:
	if not _has_item:
		return
	_show_for(swing_dur * (1.3 if fast else 1.7))   # 挥 (+ 归位) 全程都显示
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_attack_locked = false
	var mouse_on_right: bool = cos(target_angle) >= 0.0
	set_facing(mouse_on_right)  # 跟鼠标走, 不跟玩家走路方向
	_attack_locked = true
	# 不乘 facing 符号: 剑尖在中心列, 水平翻转不改变剑尖方向; 乘 s 会让"瞄左""瞄右"算出同一个 base.
	var base: float = wrapf(target_angle + PI / 2.0, -PI, PI)
	# 弧线方向随朝向镜像: 瞄右从上往右下劈, 瞄左从上往左下劈 (剑尖在中心列, 翻转不影响剑尖朝向)。
	var half: float = deg_to_rad(110.0) if mouse_on_right else -deg_to_rad(110.0)
	var start_a: float = base - half
	var end_a:   float = base + half
	if fast:
		# 双刀: 这一刀从哪边起手交替着来 — 上一刀停在 end, 这一刀就从 end 往 start 扫, 不会瞬弹。
		_dual_flip = not _dual_flip
		if _dual_flip:
			var tmp: float = start_a; start_a = end_a; end_a = tmp
	rotation = start_a
	_swing_flash()              # 出刀闪一下
	_after_t = swing_dur        # 挥砍全程留残影
	_after_accum = 0.04         # 立刻先留一个
	_tween = create_tween()
	# 挥 (打击窗口, 跟 player_action 命中判定的 180°/SWING_DURATION 同步)
	_tween.tween_property(self, "rotation", end_a, swing_dur)
	if not fast:
		# 普通剑: 挥完归位到 0 (休息位), 别卡在 end_a — 否则连挥下一刀从 end_a 瞬弹回 = 抽搐。
		_tween.tween_property(self, "rotation", 0.0, swing_dur * 0.7)
	_tween.tween_callback(func(): _attack_locked = false)


const BOW_SHOOT_DURATION := 0.35   # 放箭后弓朝鼠标保持 + 回正的总时长 (略长过冷却才看得到瞄准姿势)
const BOW_RECOIL_PX := 4.0         # 放箭瞬间弓沿瞄准方向小幅前冲再收回 (松弦反冲感)

# 射箭姿势: 让手里的弓转向鼠标 (之前 bug: 箭朝鼠标飞但弓一直竖着不转, 看着没瞄准).
# target_angle: 鼠标相对玩家的角度 (radians, 0 = 右).
# 持弓时每帧调: 弓一直朝 angle 方向 (绕握把转, 居中支点). 不带后坐力 tween — 纯瞄准.
# (射箭的后坐力由 play_bow_shoot 管; 它跑 tween 时这里不抢 position, 让后坐力放完。)
func aim_bow(angle: float) -> void:
	if not _has_item:
		return
	visible = true
	_use_timer = maxf(_use_timer, _HIDE_GRACE)   # 持弓期间一直显示 (松手/换手才收)
	var mouse_on_right: bool = cos(angle) >= 0.0
	_attack_locked = false
	set_facing(mouse_on_right)
	_attack_locked = true
	_aiming_gun = true       # 复用居中支点标志 → 切别的物品时 _reset_aim_transform 还原底端支点
	centered = true
	offset = Vector2.ZERO
	# 朝向公式同 play_bow_shoot: 瞄右 sx=+1 → rotation=angle-PI; 瞄左 sx=-1 → rotation=angle.
	rotation = wrapf(angle - (PI if mouse_on_right else 0.0), -PI, PI)
	if _tween == null or not _tween.is_valid():   # 没在放后坐力 → 把弓放回手部基准位
		position = Vector2(HAND_OFFSET_X if _facing_right else -HAND_OFFSET_X, HAND_OFFSET_Y)


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
	# 弓绕"握把"(贴图中心) 转, 不是绕底端 — 否则一旋转弓就甩到手外, 看着位置不对 (照枪 aim_gun).
	# 复用居中支点标志: 下次普通显示 _show_for 会 _reset_aim_transform 还原成底端支点 (剑/方块用).
	_aiming_gun = true
	centered = true
	offset = Vector2.ZERO
	# 弓图标的"射击口"朝 -x (左: 弓臂在左鼓出, 弦在右, 箭往弓臂那侧飞出). 要让射击口朝鼠标:
	# 没镜像 (瞄右 sx=+1) 时屏幕射向 = rotation + PI → rotation = target_angle - PI;
	# 镜像了 (瞄左 sx=-1) 时屏幕射向 = rotation → rotation = target_angle. (之前 bug: 两分支接反 = 方向反了)
	# 注: rotation 公式不受支点影响 — 支点只改弓画在哪, 不改弓指向.
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
		_reset_aim_transform()   # 射完还原底端支点 (别在收起前用居中支点显示, 防位置跳一下)
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
	# 阔剑/双刀 (sweep 类近战) 拿在手里放大一点 — 用户嫌太小
	var def = ItemDB.get_def(slot.item_id)
	if def != null and String(def.get("sword_style", "")) == "sweep":
		_current_size *= SWEEP_HELD_SCALE
	if def != null and String(def.get("tool_kind", "")) == "gun":
		_current_size *= GUN_HELD_SCALE   # 枪画宽了, 缩回去不显大
	offset = _grip_offset()   # 贴图大小可能变 (大画布武器), 支点跟着算
	_apply_scale()


func _is_tool(item_id: String) -> bool:
	var def = ItemDB.get_def(item_id)
	return def != null and def.tool_kind != ""


func _apply_scale() -> void:
	var sx: float = _current_size if _facing_right else -_current_size
	scale = Vector2(sx, _current_size)
