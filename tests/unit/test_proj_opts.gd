# T5 验收: _proj_opts_from_def 字段映射正确; gun_impact 枪带命中特效 opts.
extends GutTest

const PlayerAction = preload("res://scripts/player/player_action.gd")


func _pa() -> Node:
	var pa = PlayerAction.new()
	autofree(pa)
	return pa


func test_opts_basic_mapping() -> void:
	var def := {"gun_pierce": true, "gun_slow_factor": 0.4, "gun_slow_dur": 2.5, "gun_visual": "ice", "bullet_lifetime": 0.9}
	var opts: Dictionary = _pa()._proj_opts_from_def(def)
	assert_true(bool(opts.get("pierce", false)))
	assert_eq(float(opts.get("slow_factor", 0.0)), 0.4)
	assert_eq(String(opts.get("visual", "")), "ice")
	assert_eq(float(opts.get("lifetime", 0.0)), 0.9)


func test_gun_impact_defs_marked() -> void:
	for id in ["sniper", "railgun"]:
		assert_true(bool(ItemDB.get_def(id).get("gun_impact", false)), id + " 该配 gun_impact")
	assert_false(bool(ItemDB.get_def("minigun").get("gun_impact", false)), "快枪不配 (防刷屏)")


func test_gun_fire_opts_include_impact_for_marked_gun() -> void:
	var pa = _pa()
	# 模拟 _try_fire_gun 的 opts 组装路径: gun_impact → impact_fx/impact_color 进 opts
	var def: Dictionary = ItemDB.get_def("railgun")
	var opts: Dictionary = pa._proj_opts_from_def(def)
	if bool(def.get("gun_impact", false)):
		var vis: String = String(def.get("gun_visual", ""))
		opts["impact_fx"] = pa._spell_impact_fx(vis) if vis != "" else "spark"
		opts["impact_color"] = pa._spell_fx_color(vis) if vis != "" else Color8(255, 230, 150)
	assert_eq(String(opts.get("impact_fx", "")), "spark", "railgun (laser visual) 命中该放 spark")
