# 形状对位 + 镜像配方匹配。静态调用。
# grid: Array[Array[String]]，每个 cell = "" 或 item_id。
# 返回 null 或 {"recipe_id": String, "output_id": String, "output_count": int,
#               "input_cells": Array[Vector2i]}  # 哪些 cell 是被消耗的输入 (col, row)
extends RefCounted


static func find_match(grid: Array) -> Variant:
	for r in RecipeDB.all_recipes():
		var hit = _match_recipe(grid, r, false)
		if hit != null:
			return hit
		if r.mirror_ok:
			hit = _match_recipe(grid, r, true)
			if hit != null:
				return hit
	return null


# 把 pattern (可能 mirrored) 平移到 grid 上对应位置，逐 cell 比对。
static func _match_recipe(grid: Array, recipe: Dictionary, mirror: bool) -> Variant:
	var pattern: Array = _maybe_mirror(recipe.pattern, mirror)
	var pat_rows: int = pattern.size()
	var pat_cols: int = (pattern[0] as Array).size()

	# pattern 非空 cell bbox
	var pat_bbox = _bbox_of_nonempty(pattern)
	if pat_bbox == null:
		return null
	var pat_min: Vector2i = pat_bbox[0]
	var pat_max: Vector2i = pat_bbox[1]

	var grid_rows: int = grid.size()
	var grid_cols: int = (grid[0] as Array).size()

	# grid 非空 bbox
	var grid_bbox = _bbox_of_nonempty(grid)
	if grid_bbox == null:
		return null
	var grid_min: Vector2i = grid_bbox[0]
	var grid_max: Vector2i = grid_bbox[1]

	# bbox 尺寸必须一致
	if (grid_max - grid_min) != (pat_max - pat_min):
		return null

	# pattern (pat_min) 对位 grid (grid_min)
	var dx: int = grid_min.x - pat_min.x
	var dy: int = grid_min.y - pat_min.y
	var input_cells: Array[Vector2i] = []

	for gr in grid_rows:
		for gc in grid_cols:
			var pr: int = gr - dy
			var pc: int = gc - dx
			var grid_cell: String = grid[gr][gc]
			var pat_cell: String = ""
			if pr >= 0 and pr < pat_rows and pc >= 0 and pc < pat_cols:
				pat_cell = pattern[pr][pc]
			if grid_cell != pat_cell:
				return null
			if pat_cell != "":
				input_cells.append(Vector2i(gc, gr))

	return {
		"recipe_id": recipe.id,
		"output_id": recipe.output_id,
		"output_count": recipe.output_count,
		"input_cells": input_cells,
	}


# [min_coord, max_coord] (Vector2i (col, row))，包围所有非空 cell。全空 → null。
static func _bbox_of_nonempty(grid: Array) -> Variant:
	var rows: int = grid.size()
	var cols: int = (grid[0] as Array).size()
	var found := false
	var min_r := rows
	var max_r := -1
	var min_c := cols
	var max_c := -1
	for r in rows:
		for c in cols:
			if grid[r][c] != "":
				found = true
				if r < min_r: min_r = r
				if r > max_r: max_r = r
				if c < min_c: min_c = c
				if c > max_c: max_c = c
	if not found:
		return null
	return [Vector2i(min_c, min_r), Vector2i(max_c, max_r)]


static func _maybe_mirror(pattern: Array, do_mirror: bool) -> Array:
	if not do_mirror:
		return pattern
	var result := []
	for row in pattern:
		var reversed_row: Array = (row as Array).duplicate()
		reversed_row.reverse()
		result.append(reversed_row)
	return result
