# 探索预览直接跳到生成器的真实选址，不保存世界或角色。
extends CanvasLayer
const Generator = preload("res://scripts/world/world_generator.gd")
const Features = preload("res://scripts/world/classic_world_features.gd")
var world: Node2D
var stops: Array = []
var current := 0
var title: Label
var detail: Label
var jump_button: Button
var _busy := false

func setup(target: Node2D) -> void:
	world = target
	layer = 20
	stops = Features.landmarks(Generator.classic_plan(world.world_seed))
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 605)
	panel.size = Vector2(650, 96)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.035, 0.055, 0.12, 0.94)
	bg.border_color = Color(0.37, 0.49, 0.72)
	bg.set_border_width_all(2)
	bg.content_margin_left = 14
	bg.content_margin_top = 8
	bg.content_margin_bottom = 8
	bg.content_margin_right = 14
	panel.add_theme_stylebox_override("panel", bg)
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var text_box := VBoxContainer.new()
	text_box.custom_minimum_size.x = 388
	row.add_child(text_box)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 22)
	text_box.add_child(title)
	detail = Label.new()
	detail.add_theme_font_size_override("font_size", 15)
	text_box.add_child(detail)
	var prev := Button.new()
	prev.text = "上一处"
	prev.custom_minimum_size = Vector2(84, 44)
	row.add_child(prev)
	prev.pressed.connect(func(): visit(posmod(current - 1, stops.size())))
	jump_button = Button.new()
	jump_button.text = "下一处"
	jump_button.custom_minimum_size = Vector2(84, 44)
	row.add_child(jump_button)
	jump_button.pressed.connect(func(): visit((current + 1) % stops.size()))
	var note := Label.new()
	note.text = "群系与建筑预览 · 不影响存档 · A/D 移动 · 空格飞行 · F10 返回"
	note.position = Vector2(24, 575)
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_constant_override("outline_size", 5)
	add_child(note)
	world._slime_spawn_timer = INF
	world._animal_spawn_timer = INF
	var inventory = world.get_player().get_node("PlayerInventory")
	inventory.inventory.slots.fill(null)
	var items := ["copper_pickaxe", "copper_axe", "wood_hammer", "torch", "rope", "living_wood", "sunplate", "dungeon_brick", "sandstone_brick", "wood_platform"]
	for i in items.size(): inventory.inventory.slots[i] = {"item_id": items[i], "count": 1 if i < 3 else 99}
	inventory.inventory_changed.emit()
	visit(0)

func visit(index: int) -> void:
	if _busy: return
	_busy = true
	current = index
	var stop: Dictionary = stops[index]
	var target: Vector2i = stop.pos
	var feet: Vector2i = stop.feet
	if target.y == -1:
		target.y = Generator._estimate_surf(target.x, world.world_seed, 256) - 5
		feet.y = Generator._estimate_surf(feet.x, world.world_seed, 256) - 2
	var center := Chunk.chunk_x_of(target.x)
	# 全景的镜头中心会偏离玩家，按真实视野预载，避免画面边缘突然黑掉。
	var radius := maxi(1, ceili(1280.0 / (float(stop.zoom) * 12.0 * 128.0)))
	for cx in range(center - radius, center + radius + 1): world.chunk_manager.load_one(cx)
	var player = world.get_player()
	player.position = Vector2(feet.x + 0.5, feet.y + 1) * 12
	player.velocity = Vector2.ZERO
	world.bed_spawn_point = feet
	world.camera.set_meta("art_preview_zoom", stop.zoom)
	world.camera.zoom = Vector2.ONE * float(stop.zoom)
	world.camera.position = Vector2(target - feet) * 12
	world.camera.reset_smoothing()
	world.camera.force_update_scroll()
	for mob in get_tree().get_nodes_in_group("slimes"): mob.queue_free()
	world.chunk_manager.unload_far_from(center, 4)
	title.text = "%02d / %02d   %s" % [index + 1, stops.size(), stop.name]
	detail.text = stop.hint
	_busy = false
