extends GutTest

const BuffHudClass = preload("res://scripts/ui/buff_hud.gd")
const BuffsClass = preload("res://scripts/player/player_buffs.gd")

func test_hud_reads_active_kinds():
	var buffs = BuffsClass.new()
	add_child_autofree(buffs)
	var hud = BuffHudClass.new()
	add_child_autofree(hud)
	hud.bind(buffs)
	buffs.apply("speed", 10.0)
	buffs.apply("mining", 10.0)
	# HUD 应能从 buffs 读到 2 个活跃 kind
	assert_eq(hud._active_kinds().size(), 2)
	buffs.apply("speed", 0.0)   # secs<=0 不生效, 仍是 2
	assert_eq(hud._active_kinds().size(), 2)

func test_hud_empty_when_no_buffs():
	var hud = BuffHudClass.new()
	add_child_autofree(hud)
	# 没 bind 也不该崩
	assert_eq(hud._active_kinds().size(), 0)
