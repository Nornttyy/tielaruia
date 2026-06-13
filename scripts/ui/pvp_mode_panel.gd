# 对战房模式选择面板 + 常驻"切换模式"按钮 (击杀榜左边)。两种视图:
#   ① 模式选择 (进游戏自动弹 / M 键 / 切换模式按钮): 只选经典/魔法/枪械 → 发默认装备 + 重连到
#      该模式的公共房。每个模式一个房间 (经典 PVP / 魔法 PVP-MAGIC / 枪械 PVP-GUN), 互不同步。
#      这个视图会暂停游戏 (强制先选 + 滚轮不缩放)。
#   ② 切武器 (战斗房按 E/包键打开, 见 player_action._try_open_workbench_or_close): 列当前模式全部武器, 点一下
#      换上, 不换房不暂停 (战斗中快速换装)。骷髅法杖不列。
# 退出 = "关闭"按钮只关面板回游戏 (离开整个房间走暂停菜单)。非对战房永不弹、按钮也不显示。
#
# 注意: CanvasLayer 本身一直 visible (否则常驻按钮也被藏); 只切里面 _panel 的 visible。
extends CanvasLayer

const UIStyle = preload("res://scripts/ui/ui_style.gd")
const MpRooms = preload("res://scripts/net/mp_rooms.gd")
const PvpArena = preload("res://scripts/world/pvp_arena.gd")   # 切模式重置竞技场 (清掉搭的方块)

const _MODE_TAG := {"classic": "PVP", "magic": "PVP-MAGIC", "gun": "PVP-GUN"}
const _COMMON := [["dirt", 64], ["iron_pickaxe", 1], ["health_potion", 5]]
# 骷髅法杖 + 雀宝宝法杖故意不列 (召唤类: 对战房太轮椅 + 召唤动作在 player_action 里已被对战房屏蔽 → 列了也放不出)
const _STAFFS := [
	# 第二批 (用户加, 排最上面方便找): 追踪/穿透 · 冰霜控制 · 华丽大招 · 辅助
	["homing_staff", "追踪魔弹杖"], ["beam_staff", "穿透激光杖"], ["frost_staff", "冰冻减速杖"],
	["bounce_star_staff", "弹跳星杖"], ["meteor_staff", "流星雨杖"], ["penta_staff", "五重魔弹杖"],
	["greater_heal_staff", "强化治疗杖"], ["shield_staff", "护盾杖"],
	# 第一批
	["wood_staff", "木魔草杖"], ["iron_staff", "铁蓝晶杖"],
	["hell_staff", "地狱魔火法杖"],
	["lightning_staff", "闪电法杖"], ["poison_staff", "毒液法杖"], ["multi_staff", "多重魔弹法杖"],
	["explosive_staff", "爆裂火球法杖"], ["water_staff", "水之法杖"], ["wind_staff", "狂风法杖"],
	["heal_staff", "治疗法杖"], ["crack_staff", "地裂法杖"],
]
const _GUNS := [
	# 第二批 (用户加, 排最上面方便找)
	["minigun", "加特林"], ["twin_magic_gun", "双管魔枪"], ["rocket_gun", "追踪火箭枪"],
	["slime_smg", "史莱姆冲锋枪"], ["tesla_gun", "闪电枪"], ["cryo_gun", "寒冰炮"],
	["venom_gun", "剧毒枪"], ["railgun", "电磁炮"],
	# 第一批
	["pistol", "手枪"], ["smg", "冲锋枪"], ["assault_rifle", "突击步枪"], ["shotgun", "霰弹枪"],
	["sniper", "狙击枪"], ["laser_gun", "激光枪"], ["flamethrower", "火焰喷射器"], ["freeze_ray", "冰冻枪"],
	["arcane_gun", "追踪魔弹枪"], ["poison_gun", "毒液枪"], ["lightning_gun", "闪电链枪"], ["star_gun", "星星炮"],
	["slime_gun", "史莱姆枪"], ["frost_gun", "冰雪枪"], ["leaf_gun", "绿叶枪"],
]

var _panel: Panel = null
var _content: VBoxContainer = null
var _title: Label = null
var _switch_btn: Button = null
var _opened_once: bool = false
# 默认在"中转房"PVP-LOBBY (菜单进对战房先连这里). 选任意模式 (含经典 PVP) 都 != LOBBY → 都会搬房,
# 所以经典玩家也离开中转房, 三个对战房里只剩主动选了该模式的人 (用户: 不同模式互不干扰)。
var _current_tag: String = "PVP-LOBBY"
var _current_mode_key: String = "classic"   # 当前对战模式 (切武器面板按它列武器)


# 某模式整套物品 [[id,count],...] (武器在前 + 共用; 不含盔甲)。纯数据, 供测试 + grant 复用。
static func mode_loadout(key: String, weapon_id: String = "") -> Array:
	var out: Array = []
	match key:
		"magic":
			out.append([weapon_id if weapon_id != "" else "iron_staff", 1])
			out.append(["mana_potion", 10])
		"gun":
			out.append([weapon_id if weapon_id != "" else "pistol", 1])
			out.append(["bullet", 200])
		_:
			out.append(["iron_sword", 1])
			out.append(["wood_bow", 1])
			out.append(["wood_arrow", 99])
	for c in _COMMON:
		out.append(c)
	return out


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS   # 暂停时面板仍能点 + 网络仍跑
	add_to_group("pvp_mode_panel")            # 战斗房合成键据此找到本面板 → 开"切武器"
	_build()
	_panel.visible = false   # 只藏 panel, 不藏整个 CanvasLayer (否则按钮也没了)


func _build() -> void:
	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", UIStyle.panel())
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(380, 440)
	_panel.size = Vector2(380, 440)
	_panel.position = Vector2(-190, -220)
	add_child(_panel)
	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = 18
	outer.offset_top = 18
	outer.offset_right = -18
	outer.offset_bottom = -18
	outer.add_theme_constant_override("separation", 10)
	_panel.add_child(outer)
	_title = Label.new()
	_title.text = "选择对战模式"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color(0.949, 0.761, 0.396))
	outer.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)
	# 常驻"切换模式"按钮: 击杀榜在右上 (左边沿距右 636px), 按钮放它左边一点。
	_switch_btn = Button.new()
	_switch_btn.text = "切换模式"
	UIStyle.style_button(_switch_btn)
	_switch_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_switch_btn.offset_right = -642.0
	_switch_btn.offset_left = -762.0
	_switch_btn.offset_top = 12.0
	_switch_btn.offset_bottom = 42.0
	_switch_btn.pressed.connect(_open_modes)
	add_child(_switch_btn)
	_switch_btn.visible = false


func _add_choice(label: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIStyle.style_button(b)
	b.pressed.connect(cb)
	_content.add_child(b)


func _clear_content() -> void:
	for c in _content.get_children():
		c.queue_free()


# ---- 模式选择视图 (进游戏自动弹 / M 键 / "切换模式"按钮): 只选模式, 不选武器 ----
# allow_close=false: 首次进战斗房必须选一个模式才开始 (不给"关闭"); 之后用按钮重开才给关闭。
func _show_modes(allow_close: bool = true) -> void:
	if _title != null:
		_title.text = "选择对战模式"
	_clear_content()
	_add_choice("经典对战 (剑 + 弓)", _pick_mode.bind("classic"))
	_add_choice("魔法对战 (法杖)", _pick_mode.bind("magic"))
	_add_choice("枪械对战 (枪)", _pick_mode.bind("gun"))
	if allow_close:
		_add_choice("关闭 (返回游戏)", _close)   # 用户: 退出只关面板回游戏 (离开整个房间走暂停菜单)


# 选一个模式: 发该模式默认装备 + (换了模式才) 重连到那模式的房间。
# 切模式不再清方块 (用户改主意: 搭的东西要留着). 清场只发生在: 赢了重开 (pvp_scoreboard)
# 或 房间没别人满 1 分钟 (pvp_scoreboard 空房计时)。_reset_arena 函数保留给那些用。
func _pick_mode(mode_key: String) -> void:
	_current_mode_key = mode_key
	_grant_loadout(mode_key, "")   # 默认武器 (魔法=铁杖, 枪=手枪, 经典=剑+弓)
	_close()
	var new_tag: String = String(_MODE_TAG.get(mode_key, "PVP"))
	# 用 in_public_room (进房同步置位) 而非 is_public_room() — 后者要 connected()=true, 但进房自动弹
	# 面板时 bridge 还没连上 (connected 慢一两秒). 那会儿选模式会漏掉 reroute → 换了武器没换房 (用户报)。
	if new_tag != _current_tag and NetworkManager != null and NetworkManager.in_public_room:
		_current_tag = new_tag
		_reroute(new_tag)   # 每个模式一个房间, 互不同步 (用户要求)


# 重置竞技场: 重新 stamp 干净竞技场 (PvpArena.build 会先清整片再铺) → 把玩家搭的方块清掉,
# 顺手清 pvp 放置记录 + 把玩家挪回出生台. 跟"局结束重开"(pvp_scoreboard) 同款。
func _reset_arena() -> void:
	var w: Node = get_tree().get_first_node_in_group("world")
	if w == null or not w.has_method("_set_tile"):
		return
	PvpArena.build(w)
	var cm = w.get("chunk_manager")
	if cm != null and cm.has_method("clear_pvp_placed"):
		cm.clear_pvp_placed()
	var player: Node = get_tree().get_first_node_in_group("player")
	if player is Node2D:
		(player as Node2D).global_position = PvpArena.random_spawn()


# 面板 (选模式 / 切武器) 是否开着. player_inventory 据此挡滚轮 (开着时滚轮不缩放摄像机)。
func is_open() -> bool:
	return _panel != null and _panel.visible


# ---- 切武器视图 (战斗房按 E/包键打开, 见 player_action._try_open_workbench_or_close) ----
# 列出当前模式全部武器, 点一下换上, 不换房。E 再按一下关掉 (开关键)。
func toggle_weapon_switch() -> void:
	if _panel != null and _panel.visible:
		_close()
	else:
		open_weapon_switch()


func open_weapon_switch() -> void:
	if NetworkManager == null or NetworkManager.room_mode != "pvp":
		return
	if _local_inventory() == null:
		return
	_show_weapon_switch()
	_set_open(true, false)   # 不暂停 (战斗中换武器, 别冻住别人/自己)


func _show_weapon_switch() -> void:
	if _title != null:
		_title.text = "切换武器"
	_clear_content()
	_add_choice("← 切换模式", _open_modes)   # 想换模式 → 回模式选择 (会暂停)
	for pair in _weapons_for(_current_mode_key):
		_add_choice(String(pair[1]), _switch_weapon.bind(String(pair[0])))
	_add_choice("关闭 (返回游戏)", _close)


# 当前模式可换的武器 [[id, 中文],...]。经典只有剑+弓 (换哪个都是发整套, weapon_id 被忽略)。
func _weapons_for(mode_key: String) -> Array:
	match mode_key:
		"magic": return _STAFFS
		"gun":   return _GUNS
		_:       return [["iron_sword", "铁剑"], ["wood_bow", "木弓"]]


func _switch_weapon(weapon_id: String) -> void:
	_grant_loadout(_current_mode_key, weapon_id)   # 同模式同房, 只换装备
	_close()


func _process(_delta: float) -> void:
	# 用 room_mode=="pvp" 而非 is_pvp(): 切模式转房断开重连期间 connected()=false, 但 room_mode
	# 仍 pvp → 切换模式键不会消失一阵 (用户反馈). 击杀榜同款修在 pvp_scoreboard。
	var in_pvp: bool = NetworkManager != null and NetworkManager.room_mode == "pvp"
	var picking: bool = _panel != null and _panel.visible
	if _switch_btn != null:
		_switch_btn.visible = in_pvp and not picking
	# 进对战房自动弹一次模式选择 (用户: 进游戏才选哪个战斗). 首次不给"关闭" — 必须选一个才开始。
	if not _opened_once and not picking and in_pvp and _local_inventory() != null:
		_open_modes(false)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_M and (_panel == null or not _panel.visible) \
			and NetworkManager != null and NetworkManager.room_mode == "pvp":
		_open_modes()


# open=显示面板; pause=是否暂停游戏 (模式选择暂停 / 切武器不暂停)
func _set_open(open: bool, pause: bool = true) -> void:
	if _panel != null:
		_panel.visible = open
	if _switch_btn != null and open:
		_switch_btn.visible = false
	get_tree().paused = open and pause


func _open_modes(allow_close: bool = true) -> void:
	_opened_once = true
	_show_modes(allow_close)
	_set_open(true, true)   # 模式选择: 暂停 (滚轮不缩放 + 看清选项)


func _close() -> void:
	_set_open(false, false)   # 关面板, 解除暂停, 回游戏


func _reroute(tag: String) -> void:
	if NetworkManager == null:
		return
	NetworkManager.disconnect_room()
	NetworkManager.enter_public(tag, MpRooms.PUBLIC_SV_SEED, MpRooms.PUBLIC_SV_SIZE, MpRooms.PUBLIC_SV_DIFF)


func _local_inventory() -> Node:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	var inv_node: Node = player.get_node_or_null("PlayerInventory")
	if inv_node == null or inv_node.inventory == null:
		return null
	return inv_node


# 清空背包 + 重发该模式整套装备 (武器在前 → 选中 slot 0) + 铁甲。
# inv_arg 仅供测试注入; 正常传 null 自动找本地玩家。
func _grant_loadout(mode_key: String, weapon_id: String, inv_arg: Node = null) -> bool:
	var inv_node: Node = inv_arg if inv_arg != null else _local_inventory()
	if inv_node == null or inv_node.inventory == null:
		return false
	for i in inv_node.inventory.slots.size():
		inv_node.inventory.slots[i] = null
	for pair in mode_loadout(mode_key, weapon_id):
		inv_node.pickup(String(pair[0]), int(pair[1]))
	inv_node.set_armor("helmet", {"item_id": "iron_helmet", "count": 1})
	inv_node.set_armor("chest", {"item_id": "iron_chest", "count": 1})
	inv_node.set_armor("pants", {"item_id": "iron_pants", "count": 1})
	if inv_node.has_method("set_hotbar_selection"):
		inv_node.set_hotbar_selection(0)
	if inv_node.has_signal("inventory_changed"):
		inv_node.inventory_changed.emit()
	return true
