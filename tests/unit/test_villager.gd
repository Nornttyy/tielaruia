extends GutTest

const VillagerScene = preload("res://scenes/entities/villager.tscn")
const VillagerArt = preload("res://scripts/art/villager_art.gd")


func test_instantiate_villager():
	var v = VillagerScene.instantiate()
	add_child_autofree(v)
	await get_tree().process_frame
	assert_not_null(v)


func test_villager_in_villagers_group():
	var v = VillagerScene.instantiate()
	add_child_autofree(v)
	await get_tree().process_frame
	assert_true(v.is_in_group("villagers"), "应在 villagers group")


func test_villager_has_idle_animation():
	var v = VillagerScene.instantiate()
	add_child_autofree(v)
	await get_tree().process_frame
	var anim: AnimatedSprite2D = v.get_node("AnimatedSprite2D")
	assert_eq(anim.animation, "idle")
	assert_true(anim.is_playing())


func test_villager_art_returns_sprite_frames():
	var sf = VillagerArt.build_sprite_frames()
	assert_not_null(sf)
	assert_true(sf.has_animation("idle"))
	assert_eq(sf.get_frame_count("idle"), 2)
