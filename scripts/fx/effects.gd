# 粒子工厂 (autoload)。spawn_* 方法实例化对应场景到 effects_root 组下的 Node。
# 找不到 effects_root 则丢到当前场景根 (兜底)。
extends Node

const BlockBreakParticleScene = preload("res://scenes/fx/block_break_particle.tscn")
const SpellImpactFxScene = preload("res://scenes/fx/spell_impact_fx.tscn")  # 法杖招牌形状特效 (电弧/环/云...)
const DustParticleScene = preload("res://scenes/fx/dust_particle.tscn")
const PlaceBounceScene = preload("res://scenes/fx/place_bounce.tscn")
const WaterGrainScene = preload("res://scenes/fx/water_grain_particle.tscn")
const BlocksArt = preload("res://scripts/art/blocks_art.gd")
const TILE_SIZE := 12
const CHIPS_PER_BREAK := 6
const MAX_WATER_GRAINS := 250        # 全局存活水珠硬上限 (网页安全)
var _grain_count: int = 0            # 当前存活水珠数 (发 +1, 回池 -1)
var grains_emitted: int = 0          # 调试/测试计数: 累计成功发射次数 (只增)


func _root() -> Node:
	var n: Node = get_tree().get_first_node_in_group("effects_root")
	if n != null:
		return n
	var scene: Node = get_tree().current_scene
	if scene != null:
		return scene
	return self


func spawn_block_break(tile_coord: Vector2i, tile_id: int) -> void:
	var center := Vector2(
		tile_coord.x * TILE_SIZE + TILE_SIZE / 2.0,
		tile_coord.y * TILE_SIZE + TILE_SIZE / 2.0
	)
	var palette: Array = BlocksArt.get_palette(tile_id)
	var parent: Node = _root()
	for i in CHIPS_PER_BREAK:
		var chip = BlockBreakParticleScene.instantiate()
		parent.add_child(chip)
		var angle: float = randf_range(-PI, 0.0)  # 向上半圆
		var speed: float = randf_range(60.0, 140.0)
		var vel := Vector2(cos(angle), sin(angle)) * speed
		var color: Color = palette[i % palette.size()]
		chip.setup(center + Vector2(randf_range(-4, 4), randf_range(-4, 4)), color, vel)


func spawn_place_bounce(tile_coord: Vector2i, tile_id: int = -1) -> void:
	if tile_id == -1:
		return
	var pb = PlaceBounceScene.instantiate()
	_root().add_child(pb)
	pb.setup(tile_coord, tile_id)


func spawn_jump_dust(world_pos: Vector2) -> void:
	var pool: Node = get_tree().get_first_node_in_group("dust_pool")
	for i in 4:
		var pos: Vector2 = world_pos + Vector2(randf_range(-5, 5), randf_range(-2, 2))
		var scl: float = randf_range(0.7, 1.0)
		# 池: 几乎零开销复用. 兜底 instantiate (池满 / 池没建)
		if pool != null and pool.request_dust(pos, scl):
			continue
		var d = DustParticleScene.instantiate()
		_root().add_child(d)
		d.setup(pos, scl)


func spawn_land_dust(world_pos: Vector2) -> void:
	var pool: Node = get_tree().get_first_node_in_group("dust_pool")
	for i in 6:
		var pos: Vector2 = world_pos + Vector2(randf_range(-8, 8), randf_range(-1, 1))
		var scl: float = randf_range(1.0, 1.4)
		if pool != null and pool.request_dust(pos, scl):
			continue
		var d = DustParticleScene.instantiate()
		_root().add_child(d)
		d.setup(pos, scl)


func spawn_steam_puff(world_pos: Vector2) -> void:
	# 水碰岩浆冒一小撮蒸汽 (复用尘埃粒子, 向上飘散)
	var pool: Node = get_tree().get_first_node_in_group("dust_pool")
	for i in 5:
		var pos: Vector2 = world_pos + Vector2(randf_range(-4, 4), randf_range(-3, 1))
		var scl: float = randf_range(0.8, 1.2)
		if pool != null and pool.request_dust(pos, scl):
			continue
		var d = DustParticleScene.instantiate()
		_root().add_child(d)
		d.setup(pos, scl)


func spawn_splash(world_pos: Vector2) -> void:
	# 落水溅水花: 8 颗蓝色水滴向上扇形飞散 + 落回 (复用 block_break 粒子, 够明显)
	var parent: Node = _root()
	var drops := [Color(0.55, 0.8, 0.96, 0.95), Color(0.72, 0.9, 1.0, 0.95), Color(0.38, 0.64, 0.92, 0.92)]
	for i in 8:
		var chip = BlockBreakParticleScene.instantiate()
		parent.add_child(chip)
		var angle: float = randf_range(-PI * 0.85, -PI * 0.15)  # 向上扇形 (含两侧)
		var speed: float = randf_range(70.0, 150.0)
		var vel := Vector2(cos(angle), sin(angle)) * speed
		chip.setup(world_pos + Vector2(randf_range(-3, 3), -2.0), drops[i % drops.size()], vel)


# 法杖命中特效分发: 每种法杖 = 一个"招牌形状"(画出来的电弧/环/云) + 一撮配套粒子。
# kind: spark(闪电弧) / gas(毒云) / sparkle(符文环) / gust(旋风) / explosion(冲击波) / splash(涟漪)
func spawn_spell_impact(kind: String, world_pos: Vector2, base: Color = Color(1, 1, 1, 1)) -> void:
	# 招牌形状: 不是粒子, 是 _draw 画的线/环/云 (给每种法术辨识度)
	var fx = SpellImpactFxScene.instantiate()
	_root().add_child(fx)
	fx.global_position = world_pos
	if fx.has_method("setup"):
		fx.setup(kind, base)
	# 再补一撮配套粒子增加质感
	match kind:
		"splash":
			spawn_splash(world_pos)
		"spark":
			# 闪电: 8 道均匀星形 + 白芯, 飞得又快又直 (像电"啪"地炸开)
			_spell_chips(world_pos, [Color(1, 1, 1, 1), base, base.lightened(0.4)], 8, 240.0, 380.0, true)
		"gas":
			# 毒: 12 颗慢速绿粒挤在一起慢慢散 (像一团毒气)
			_spell_chips(world_pos, [base, base.darkened(0.25), base.lightened(0.2)], 12, 12.0, 50.0, false)
		"sparkle":
			# 魔法: 10 颗小星慢慢飘散 (紫+粉+白闪)
			_spell_chips(world_pos, [base, base.lightened(0.45), Color(1, 1, 1, 1)], 10, 25.0, 75.0, false)
		"gust":
			# 风: 左右两侧横向喷条 (像一阵风刮过)
			var cols := [Color(1, 1, 1, 0.95), base, base.lightened(0.3)]
			for i in 8:
				var side: float = 1.0 if i % 2 == 0 else -1.0
				var ang: float = randf_range(-0.35, 0.35)
				var sp: float = randf_range(150.0, 260.0)
				_spell_one(world_pos, cols[i % cols.size()], Vector2(cos(ang) * side, sin(ang) * 0.5) * sp)
		_:
			spawn_explosion(world_pos, base)


# n 颗碎片爆发. even_star=true → 角度均匀成星形 (闪电); false → 全向随机.
func _spell_chips(pos: Vector2, cols: Array, n: int, smin: float, smax: float, even_star: bool) -> void:
	for i in n:
		var ang: float = (float(i) / float(n) * TAU + randf_range(-0.15, 0.15)) if even_star else randf_range(-PI, PI)
		var sp: float = randf_range(smin, smax)
		_spell_one(pos, cols[i % cols.size()], Vector2(cos(ang), sin(ang)) * sp)


func _spell_one(pos: Vector2, color: Color, vel: Vector2) -> void:
	var chip = BlockBreakParticleScene.instantiate()
	_root().add_child(chip)
	chip.setup(pos + Vector2(randf_range(-3, 3), randf_range(-3, 3)), color, vel)


func spawn_damage_number(world_pos: Vector2, amount: int, color: Color = Color(1, 0.9, 0.5)) -> void:
	# 砍怪 / 玩家受伤时, 头上飘一个 "-N" 数字, 0.7s 上升 + 渐隐.
	# color: 默认暖黄 (打怪); 玩家受伤可传 Color(1, 0.4, 0.4) 暗红.
	# 怪受击音效: 只在"砍怪"(默认黄字 g=0.9)时播, 玩家受伤(红字 g≈0.35)不播 — 玩家有自己的 hurt 音.
	# 按距离衰减: 离玩家远了变小, 超过 10 tile (120px) 直接静音 (用户要求)。
	if color.g > 0.6:
		SfxBank.play_at("hit", world_pos, 120.0, 0.08)
	var lbl := Label.new()
	lbl.text = "-%d" % amount
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_font_size_override("font_size", 14)
	# 随机水平偏移避免数字叠在一起 (连续多发命中)
	var jitter_x: float = randf_range(-6.0, 6.0)
	lbl.position = world_pos + Vector2(-8.0 + jitter_x, -16.0)
	lbl.z_index = 100
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root().add_child(lbl)
	# Tween: 向上飘 18 px, alpha 1 → 0, 0.7s
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 18.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(lbl.queue_free)


func spawn_walk_puff(world_pos: Vector2) -> void:
	var pos: Vector2 = world_pos + Vector2(randf_range(-2, 2), 0)
	var pool: Node = get_tree().get_first_node_in_group("dust_pool")
	if pool != null and pool.request_dust(pos, 0.6):
		return
	var d = DustParticleScene.instantiate()
	_root().add_child(d)
	d.setup(pos, 0.6)


# 爆炸 (死人箱触发): 红黄火光粒子 30 颗向四面散开 + 黑烟 + 飞溅木屑碎片.
# 用 BlockBreakParticle 当弹片 (颜色覆盖成爆炸色).
func spawn_explosion(world_pos: Vector2, tint: Color = Color(0, 0, 0, 0)) -> void:
	var parent: Node = _root()
	# 爆炸色板: 默认红 → 橙 → 黄 → 黑烟; 传了 tint (法杖元素色) 就围着 tint 配一套深浅.
	var explosion_palette: Array
	if tint.a <= 0.0:
		explosion_palette = [
			Color8(255, 230, 90),   # 黄亮
			Color8(255, 150, 40),   # 橙
			Color8(220, 60, 30),    # 红
			Color8(40, 30, 25),     # 黑烟
			Color8(255, 200, 80),   # 黄
			Color8(200, 50, 40),    # 暗红
		]
	else:
		explosion_palette = [
			tint.lightened(0.45),   # 亮芯
			tint,                   # 主色
			tint.darkened(0.3),     # 暗
			Color8(40, 30, 25),     # 黑烟
			tint.lightened(0.2),    # 次亮
			tint.darkened(0.5),     # 更暗
		]
	for i in 30:  # 比普通破方块 6 颗多很多 → "爆炸感"
		var chip = BlockBreakParticleScene.instantiate()
		parent.add_child(chip)
		var angle: float = randf_range(-PI, PI)   # 全方向 (不只是向上)
		var speed: float = randf_range(120.0, 280.0)
		var vel := Vector2(cos(angle), sin(angle)) * speed
		var color: Color = explosion_palette[i % explosion_palette.size()]
		chip.setup(world_pos + Vector2(randf_range(-6, 6), randf_range(-6, 6)), color, vel)


# 活水颗粒发射: 从流动的水冒小水珠 (纯视觉)。
# tid: 来源水 tile (决定群系颜色); n: 这次冒几颗。
# 返回 true = 已发射(或在 headless 下已计数); false = 到上限被拒。
# 护栏: 全局存活 >= MAX_WATER_GRAINS 直接拒 → 瀑布密集处也不会无限堆。
func spawn_water_grains(world_pos: Vector2, vel_hint: Vector2, tid: int, n: int = 1, splashes: bool = true) -> bool:
	if _grain_count >= MAX_WATER_GRAINS:
		return false
	# grains_emitted 数的是"发射器被成功调用的次数", 不是实际生成的颗粒数:
	# headless 测试里没池也没 effects_root, 不会真建节点, 但仍 +1 → 集成测试靠它确认钩子被调到。
	grains_emitted += 1
	# 颜色: 现成群系水色板的高光色 "c", alpha 调亮到 0.9 让水珠显眼
	var pal: Dictionary = BlocksArt.water_palette_for(tid)
	var base: Color = pal.get("c", Color(0.55, 0.8, 0.96, 1.0))
	var color := Color(base.r, base.g, base.b, 0.9)
	var pool: Node = get_tree().get_first_node_in_group("water_grain_pool")
	var has_root: bool = get_tree().get_first_node_in_group("effects_root") != null
	for i in n:
		if _grain_count >= MAX_WATER_GRAINS:
			break
		# 速度: 在 vel_hint 上加点随机扇形, 像溅开的水
		var vel := vel_hint + Vector2(randf_range(-22, 22), randf_range(-14, 4))
		var pos := world_pos + Vector2(randf_range(-2, 2), randf_range(-2, 2))
		if pool != null and pool.request_grain(pos, vel, color, splashes):
			_grain_count += 1
			continue
		# 没池但有 effects_root → 兜底 instantiate (跟其他 spawn_* 一致)
		if has_root:
			var g = WaterGrainScene.instantiate()
			_root().add_child(g)
			g._pool = self           # 让它死时调 Effects.recycle 减计数
			g.setup(pos, vel, color, splashes)
			_grain_count += 1
		# 既没池也没 root (headless 测试): 只计数, 不建节点
	return true


# 兜底 instantiate 出来的水珠 (无池) 走 Effects 当"池": 死时回收, 维持 _grain_count 正确。
func recycle(g: Node) -> void:
	if g != null and is_instance_valid(g):
		g.queue_free()
	_grain_count = maxi(0, _grain_count - 1)


# 联机聊天: 在 world_pos (玩家头顶) 冒一个文字气泡, 飘一下 → 停 3 秒 → 渐隐。
# 文字截短到 24 字保持气泡小巧 (完整内容在左下聊天栏看)。
func spawn_speech_bubble(world_pos: Vector2, text: String) -> void:
	if text == "":
		return
	var shown: String = text if text.length() <= 24 else text.substr(0, 24) + "…"
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.10, 0.82)   # 深色半透明气泡底
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", sb)
	panel.z_index = 120
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = shown
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lbl)
	_root().add_child(panel)
	# 头顶上方, 大致居中 (按字数估宽度往左挪半个; 不求精确, 够"在头顶上"即可)
	var est_w: float = float(shown.length()) * 6.0 + 8.0
	panel.position = world_pos + Vector2(-est_w * 0.5, -34.0)
	panel.modulate = Color(1, 1, 1, 1)
	var tw := panel.create_tween()
	tw.tween_property(panel, "position:y", panel.position.y - 6.0, 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.0)
	tw.tween_property(panel, "modulate:a", 0.0, 0.6)
	tw.tween_callback(panel.queue_free)
