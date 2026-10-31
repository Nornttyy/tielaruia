extends GutTest

const Player = preload("res://scenes/player/player.tscn")
const Timing = preload("res://scripts/items/original_use_timing.gd")
const Content = preload("res://scripts/items/original_content.gd")
var p: CharacterBody2D
var inv: Node
var held: Sprite2D
var action: Node
var old_creative: bool

class MiningWorld extends Node2D:
	var chunk_manager = null

func before_each():
	old_creative = GameSettings.creative_mode
	GameSettings.creative_mode = false
	p = Player.instantiate()
	add_child_autofree(p)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	inv = p.get_node("PlayerInventory")
	held = p.get_node("HeldItem")
	action = p.get_node("PlayerAction")
	action._connect_hotbar_signal()
	action.primary_override = true
	action.secondary_held_override = false
	action.mouse_world_override = Vector2(48, -12)
	inv.inventory.slots.fill(null)
	_equip("copper_pickaxe")

func after_each():
	GameSettings.creative_mode = old_creative

func _equip(id: String):
	inv.inventory.slots[0] = {"item_id": id, "count": 1}
	inv.inventory_changed.emit()
	action._on_hotbar_changed(0)

func _make_mining_target() -> TileMapLayer:
	# 小范围真实 TileMap，不启动主场景、世界生成或读写玩家存档。
	var world := MiningWorld.new()
	add_child_autofree(world)
	var terrain := TileMapLayer.new()
	terrain.tile_set = TileSet.new()
	terrain.tile_set.tile_size = Vector2i(12, 12)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(Image.create(12, 12, false, Image.FORMAT_RGBA8))
	source.texture_region_size = Vector2i(12, 12)
	terrain.tile_set.add_source(source, Tiles.STONE)
	source.create_tile(Vector2i.ZERO)
	world.add_child(terrain)
	terrain.add_to_group("terrain_layer")
	terrain.set_cell(Vector2i(2, 0), Tiles.STONE, Vector2i.ZERO)
	terrain.set_cell(Vector2i(3, 0), Tiles.STONE, Vector2i.ZERO)
	return terrain

func test_available_melee_tools_and_bow_have_item_specific_timings():
	for id in Content.ORIGINAL_ITEM_IDS:
		var def = ItemDB.get_def(id)
		if def != null and def.tool_kind in ["pickaxe", "axe", "hammer", "sword", "bow"]:
			assert_true(Timing.ANIMATION_TICKS.has(id), id + " 不能落回统一的旧慢速")
	assert_almost_eq(Timing.seconds("copper_pickaxe"), 23.0 / 60.0, 0.000001)
	assert_almost_eq(Timing.seconds("copper_axe"), 0.5, 0.000001)
	assert_almost_eq(Timing.seconds("copper_dagger"), 13.0 / 60.0, 0.000001)
	assert_almost_eq(Timing.seconds("wood_bow"), 0.5, 0.000001)

func test_weapon_body_and_hit_window_finish_on_the_same_tick():
	for id in ["copper_pickaxe", "copper_axe", "copper_dagger", "iron_sword", "gold_sword"]:
		_equip(id)
		action.primary_override = true
		action._physics_process(0.0)
		var duration := Timing.seconds(id)
		assert_almost_eq(p._action_duration, duration, 0.000001, id)
		assert_almost_eq(held._use_timer, duration, 0.000001, id)
		assert_almost_eq(action._attack_cooldown, duration, 0.000001, id)
		action.primary_override = false
		var ticks: int = Timing.ANIMATION_TICKS[id]
		for i in range(ticks - 1):
			action._physics_process(1.0 / 60.0)
		assert_true(held.visible, id + " 最后一刻前仍在动作中")
		assert_gt(p._action_timer, 0.0)
		assert_true(action._pickaxe_spin_active or action._sword_attack_active)
		action._physics_process(1.0 / 60.0)
		assert_false(held.visible, id)
		assert_eq(p._action_timer, 0.0, id)
		assert_false(action._pickaxe_spin_active or action._sword_attack_active, id)

func test_holding_tool_restarts_only_after_its_whole_swing():
	for rate in [60, 120]:
		_equip("copper_pickaxe")
		action._physics_process(0.0)
		var duration := 23.0 / 60.0
		var steps: int = 23 * rate / 60
		for cycle in range(4):
			for i in range(1, steps):
				action._physics_process(1.0 / rate)
				assert_almost_eq(action._pickaxe_spin_t, float(i) / rate, 0.000001, "整次挥动期间不重置")
			assert_gt(held.rotation, 1.0, "确实挥到下落末段，没有被下一挥打断")
			action._physics_process(1.0 / rate)
			assert_eq(action._pickaxe_spin_t, 0.0)
			assert_almost_eq(p._action_timer, duration, 0.000001)

func test_switching_mining_targets_and_air_does_not_restart_swing():
	_make_mining_target()
	action.aim_override = Vector2i(2, 0)
	action._physics_process(0.0)
	for i in range(1, 19):
		# 在两块石头及空气间切换，旧代码在换目标时会反复重播起手。
		action.aim_override = Vector2i(2 + i % 3, 0)
		action._physics_process(1.0 / 60.0)
		assert_almost_eq(action._pickaxe_spin_t, float(i) / 60.0, 0.000001)
		assert_almost_eq(p._action_timer, (23.0 - i) / 60.0, 0.000001)
	assert_gt(held.rotation, 0.5, "切方块仍完成下挥")
	assert_gt(action._mine_saved.size(), 1, "实际进入过多个方块的挖掘分支")

func test_render_frames_do_not_speed_up_the_physics_action_clock():
	action._physics_process(0.0)
	action._physics_process(0.1)
	var remaining: float = p._action_timer
	var rotation: float = held.rotation
	for i in range(24):
		p._process(1.0 / 240.0)
		held._process(1.0 / 240.0)
	assert_almost_eq(p._action_timer, remaining, 0.000001)
	assert_almost_eq(held._use_timer, remaining, 0.000001)
	assert_almost_eq(held.rotation, rotation, 0.000001)
	assert_almost_eq(action._pickaxe_spin_t, 0.1, 0.000001)

func test_bow_release_cadence_matches_body_and_weapon():
	_equip("wood_bow")
	inv.pickup("wood_arrow", 10)
	var entities := Node2D.new()
	add_child_autofree(entities)
	entities.add_to_group("entities_root")
	action._physics_process(0.0)
	assert_eq(entities.get_child_count(), 1)
	assert_almost_eq(p._action_duration, 0.5, 0.000001)
	for i in range(29):
		action._physics_process(1.0 / 60.0)
	assert_eq(entities.get_child_count(), 1, "30 刻前不连发")
	assert_true(held.visible)
	action._physics_process(1.0 / 60.0)
	assert_eq(entities.get_child_count(), 2)
	assert_almost_eq(p._action_timer, 0.5, 0.000001)
	assert_almost_eq(held._use_timer, 0.5, 0.000001)

func test_changing_tool_cancels_old_damage_window_and_uses_new_timing():
	action._physics_process(0.0)
	inv.pickup("copper_dagger", 1)
	inv.set_hotbar_selection(1)
	assert_false(action._pickaxe_spin_active)
	assert_false(held.visible)
	action._physics_process(0.0)
	assert_true(action._sword_attack_active)
	assert_almost_eq(action._sword_attack_duration, 13.0 / 60.0, 0.000001)

func test_mining_contact_sound_does_not_spam_when_target_changes():
	watch_signals(SfxBank)
	for sound_player in SfxBank._players: sound_player.stop()
	action._mining_sound_cooldown = 0.0
	action._play_mining_contact(Tiles.STONE)
	action._play_mining_contact(Tiles.DIRT)
	assert_signal_emit_count(SfxBank, "sound_played", 1)
	for _tick in 14: action._advance_attack_clock(1.0 / 60.0)
	action._play_mining_contact(Tiles.DIRT)
	assert_signal_emit_count(SfxBank, "sound_played", 1)
	action._advance_attack_clock(1.0 / 60.0)
	action._play_mining_contact(Tiles.STONE)
	assert_signal_emit_count(SfxBank, "sound_played", 2)
	action._play_break_contact(Tiles.STONE)
	assert_signal_emit_count(SfxBank, "sound_played", 2, "最后一击不能与破坏声重叠")
	for sound_player in SfxBank._players: sound_player.stop()
