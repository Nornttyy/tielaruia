# Boss 专属血条: 屏幕顶部中央一条大血条 + Boss 名字.
# 有 boss (group "boss") 活着就显示, 死了/消失就隐藏. 跟普通怪头顶小血条区分.
# 联机两端都从 boss.current_health 读 → 各自显对端真实血量.
extends Control

const BAR_W := 260.0
const BAR_H := 16.0
const BAR_Y := 28.0          # 血条顶距屏幕顶
const NAME_Y := 22.0         # 名字基线 (在血条上方)

const BG := Color8(8, 6, 12, 230)
const BORDER := Color8(235, 225, 200, 255)
const FILL_FULL := Color8(120, 220, 80)   # 满血绿
const FILL_MID := Color8(245, 200, 70)    # 中血黄
const FILL_LOW := Color8(220, 60, 50)     # 残血红
const TEXT := Color(0.98, 0.96, 0.9)
const SHADOW := Color(0, 0, 0, 0.9)

var _boss: Node = null


func _process(_delta: float) -> void:
	var b: Node = _pick_boss()
	if b != null:
		_boss = b
		visible = true
		queue_redraw()
	elif visible:
		_boss = null
		visible = false


# 选要显示血条的 boss: 活着的里挑离本地玩家最近的那个.
# (同时有俩 boss — 比如史莱姆王 + 骷髅王 — 时显示你正在打的那个, 而不是先生成的那个)
func _pick_boss() -> Node:
	# 本地玩家 (联机对端的影子玩家有 is_remote meta, 跳过)
	var player: Node2D = null
	for p in get_tree().get_nodes_in_group("player"):
		if p is Node2D and not p.has_meta("is_remote"):
			player = p
			break
	var best: Node = null
	var best_d: float = INF
	for boss in get_tree().get_nodes_in_group("boss"):
		if not is_instance_valid(boss) or not ("current_health" in boss) or int(boss.current_health) <= 0:
			continue
		if player != null and boss is Node2D:
			var d: float = player.global_position.distance_squared_to((boss as Node2D).global_position)
			if d < best_d:
				best_d = d
				best = boss
		elif best == null:
			best = boss   # 没玩家参照 → 退回"第一个活着的"
	return best


func _draw() -> void:
	if _boss == null or not is_instance_valid(_boss):
		return
	var cur: int = int(_boss.current_health)
	var mx: int = int(_boss.max_health) if "max_health" in _boss else cur
	if mx <= 0:
		return
	var cx: float = size.x * 0.5
	var x: float = cx - BAR_W * 0.5
	var font: Font = ThemeDB.fallback_font
	# 名字
	if font != null:
		var bname: String = _boss.boss_display_name() if _boss.has_method("boss_display_name") else "Boss"
		var fs := 16
		var sz: Vector2 = font.get_string_size(bname, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var nx: float = cx - sz.x * 0.5
		draw_string(font, Vector2(nx + 1, NAME_Y + 1), bname, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, SHADOW)
		draw_string(font, Vector2(nx, NAME_Y), bname, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TEXT)
	# 血条底 + 边框
	draw_rect(Rect2(x - 2, BAR_Y - 2, BAR_W + 4, BAR_H + 4), BG, true)
	draw_rect(Rect2(x - 2, BAR_Y - 2, BAR_W + 4, BAR_H + 4), BORDER, false, 2.0)
	# 填充 (绿→黄→红)
	var frac: float = clamp(float(cur) / float(mx), 0.0, 1.0)
	var fill_color: Color
	if frac > 0.5:
		fill_color = FILL_FULL.lerp(FILL_MID, (1.0 - frac) * 2.0)
	else:
		fill_color = FILL_MID.lerp(FILL_LOW, (0.5 - frac) * 2.0)
	draw_rect(Rect2(x, BAR_Y, BAR_W * frac, BAR_H), fill_color, true)
	# 血量数字 居中
	if font != null:
		var txt: String = "%d / %d" % [cur, mx]
		var fs2 := 11
		var sz2: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2)
		var tx: float = cx - sz2.x * 0.5
		var ty: float = BAR_Y + BAR_H * 0.5 + sz2.y * 0.32
		draw_string(font, Vector2(tx + 1, ty + 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, SHADOW)
		draw_string(font, Vector2(tx, ty), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, TEXT)
