extends GutTest
const Player = preload("res://scenes/player/player.tscn")
const Ambience = preload("res://scripts/audio/original_ambience.gd")
var player: CharacterBody2D
var entities: Node2D
var heard: Array = []
var saved_creative: bool

func before_each():
	saved_creative = GameSettings.creative_mode
	GameSettings.creative_mode = false
	heard.clear()
	SfxBank._cooldowns.clear()
	for voice in SfxBank._players: voice.stop()
	player = Player.instantiate()
	add_child_autofree(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	entities = Node2D.new()
	add_child_autofree(entities)
	entities.add_to_group("entities_root")
	entities.process_mode = Node.PROCESS_MODE_DISABLED
	SfxBank.sound_played.connect(_record)

func after_each():
	SfxBank.sound_played.disconnect(_record)
	SfxBank._cooldowns.clear()
	GameSettings.creative_mode = saved_creative
	for voice in SfxBank._players: voice.stop()

func _record(event: String, source: String):
	heard.append([event, source])

func test_actual_creatures_distinguish_hurt_and_death_without_duplicate_hits():
	for case in [["slime", "hit", "npc_die"], ["zombie", "hit", "undead_die"],
		["skeleton", "bone_hit", "undead_die"], ["mimic", "metal_hit", "magic_die"]]:
		var mob = load("res://scenes/entities/" + case[0] + ".tscn").instantiate()
		entities.add_child(mob)
		mob.global_position = player.global_position + Vector2(20, 0)
		heard.clear()
		assert_true(mob.take_damage(1))
		assert_eq(heard.size(), 1)
		assert_eq(heard[0][0], case[1])
		assert_false(mob.take_damage(1), "无敌帧中的接触不能再播放一次")
		assert_eq(heard.size(), 1)
		mob._iframe_t = 0.0
		assert_true(mob.take_damage(10000))
		assert_eq(heard.size(), 2, "致命一击只响死亡声")
		assert_eq(heard[1][0], case[2])
		mob._die()
		assert_eq(heard.size(), 2, "重复死亡通知不能重播")

func test_player_fatal_hit_uses_death_sample_once():
	var health = player.get_node("PlayerHealth")
	health.take_damage(10000, Vector2.ZERO)
	assert_eq(heard.size(), 1)
	assert_eq(heard[0][0], "player_die")
	assert_true(heard[0][1].ends_with("Player_Killed.wav"))
	health.take_damage(10000, Vector2.ZERO)
	assert_eq(heard.size(), 1)

func test_damage_numbers_and_healing_are_silent_visuals():
	Effects.spawn_damage_number(Vector2.ZERO, 3)
	Effects.spawn_damage_number(Vector2.ZERO, 20, Color.GREEN)
	player.get_node("PlayerHealth").heal(20)
	assert_eq(heard.size(), 0, "飘字不能再顺便触发统一的怪物受击声")

func test_distant_monsters_and_expired_voices_are_silent():
	SfxBank.play_creature("zombie", player.position + Vector2(500, 0), false)
	assert_eq(heard.size(), 0)
	var zombie = load("res://scenes/entities/zombie.tscn").instantiate()
	entities.add_child(zombie)
	var voice: Node = null
	for child in zombie.get_children():
		if child.get_script() == preload("res://scripts/audio/creature_voice.gd"): voice = child
	assert_not_null(voice)
	voice._remaining = 0.0
	voice._process(0.01)
	assert_eq(heard.size(), 1)
	assert_eq(heard[0][0], "zombie_idle")
	SfxBank._cooldowns.clear()
	zombie._is_dying = true
	voice._remaining = 0.0
	voice._process(0.01)
	assert_eq(heard.size(), 1)

func test_drips_are_throttled_and_original_variants_are_used():
	for i in 20: SfxBank.play_at("drip", player.global_position)
	assert_eq(heard.size(), 1, "一群落水颗粒不能叠出二十个同响水滴")
	assert_true(heard[0][1].get_file().begins_with("Drip_"))
	SfxBank._process(0.25)
	SfxBank.play_at("drip", player.global_position)
	assert_eq(heard.size(), 2)

func test_master_volume_is_not_applied_twice_to_sound_players():
	var old: float = GameSettings.master_volume
	GameSettings.master_volume = 0.1
	SfxBank.play("menu_open")
	assert_almost_eq(SfxBank._players[0].volume_db, SfxBank.GLOBAL_ATTEN_DB, 0.001)
	GameSettings.master_volume = old

func _ambience():
	var ambience = Ambience.new()
	add_child_autofree(ambience)
	ambience.set_process(false)
	return ambience

func test_water_and_lava_loop_only_while_real_flow_is_near():
	var ambience = _ambience()
	for kind in ["water", "lava"]:
		var voice: AudioStreamPlayer = ambience._players[kind]
		assert_false(voice.playing)
		ambience.note_flow(kind, entities, player.global_position)
		ambience._process(0.1)
		assert_true(voice.playing)
		assert_almost_eq(ambience._targets[kind], -30.0, 0.001)
		var sample := voice.stream as AudioStreamWAV
		assert_eq(sample.loop_mode, AudioStreamWAV.LOOP_FORWARD)
		assert_gt(sample.loop_end, 0)
		ambience._process(1.1)
		assert_false(voice.playing, "流水停止后淡出，不能无限循环")
		assert_true(ambience._sources.is_empty())

func test_waterfall_attenuates_and_stops_when_world_is_removed():
	var ambience = _ambience()
	ambience.note_flow("water", entities, player.global_position + Vector2(200, 0))
	ambience._process(0.1)
	assert_lt(ambience._targets.water, -30.0)
	assert_gt(ambience._targets.water, -80.0)
	entities.queue_free()
	ambience._process(0.3)
	assert_true(ambience._sources.is_empty())
	assert_false(ambience._players.water.playing)

func test_no_listener_and_distant_flow_cannot_start_ambience():
	var ambience = _ambience()
	ambience.note_flow("water", entities, player.global_position + Vector2(1000, 0))
	assert_true(ambience._sources.is_empty())
	player.remove_from_group("player")
	ambience.note_flow("water", entities, Vector2.ZERO)
	assert_true(ambience._sources.is_empty())

func test_throw_boomerang_explosion_and_fishing_have_separate_sounds():
	var inv = player.get_node("PlayerInventory")
	inv.inventory.slots[0] = {"item_id": "boomerang", "count": 1}
	inv.hotbar_selected = 0
	var action = player.get_node("PlayerAction")
	action.mouse_world_override = Vector2(100, 0)
	action._try_throw_weapon()
	assert_eq(heard.size(), 1)
	assert_eq(heard[0][0], "swing")
	var boomerang = entities.get_child(0)
	boomerang._physics_process(1.0 / 60.0)
	assert_eq(heard[1][0], "boomerang")
	var bomb = load("res://scenes/entities/bullet.tscn").instantiate()
	entities.add_child(bomb)
	bomb._visual = "bomb"
	bomb._explode(player.global_position)
	assert_eq(heard[2][0], "explosion")
	player.get_node("PlayerFishing")._on_bite()
	assert_eq(heard[3][0], "fish_bite")

class FlowWorld extends Node2D:
	var chunk_manager = self
	var tiles := {}
	func get_tile(x: int, y: int) -> int:
		return tiles.get(Vector2i(x, y), Tiles.AIR)
	func _set_water_tile_fast(x: int, y: int, tid: int):
		tiles[Vector2i(x, y)] = tid

func test_liquid_sim_reports_real_flow_but_world_loading_is_silent():
	var world := FlowWorld.new()
	add_child_autofree(world)
	var sim = preload("res://scripts/world/water_sim.gd").new()
	sim.world = world
	add_child_autofree(sim)
	sim.set_process(false)
	var ambience = MusicBank._original_ambience
	ambience._sources.clear()
	world.tiles[Vector2i(0, 0)] = Tiles.WATER
	sim._in_settle = true
	sim._step_tile(world, 0, 0)
	assert_true(ambience._sources.is_empty(), "加载地图找平时不响流水声")
	world.tiles.clear()
	world.tiles[Vector2i(0, 0)] = Tiles.WATER
	sim._in_settle = false
	sim._step_tile(world, 0, 0)
	assert_false(ambience._sources.is_empty(), "真正下落的水需要通知原版流水音")
	ambience._sources.clear()
