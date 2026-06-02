extends GutTest

const ItemsArt = preload("res://scripts/art/items_art.gd")

func test_cloud_boots_item_def():
	var def = ItemDB.get_def("cloud_boots")
	assert_not_null(def, "云靴物品存在")
	assert_eq(def["max_stack"], 1, "云靴不堆叠")

func test_cloud_boots_has_icon():
	assert_true(ItemsArt.has_icon("cloud_boots"), "云靴有图标")

func test_cloud_boots_recipe_exists():
	var r = RecipeDB.get_recipe("cloud_boots")
	assert_not_null(r, "云靴配方存在")
	assert_eq(r["output_id"], "cloud_boots", "产出云靴")
	assert_eq(r.get("requires", ""), "workbench", "要工作台")
	var ids := {}
	for row in r["pattern"]:
		for cell in row:
			if cell != "":
				ids[cell] = true
	assert_true(ids.has("feather"), "配方含羽毛")
	assert_true(ids.has("cloud"), "配方含云块")


const PlayerInventoryScript = preload("res://scripts/player/player_inventory.gd")

func test_has_item():
	var pinv = PlayerInventoryScript.new()
	add_child_autofree(pinv)   # 触发 _ready 建 inventory
	await wait_frames(1)
	assert_false(pinv.has_item("cloud_boots"), "一开始没有云靴")
	pinv.inventory.add("cloud_boots", 1)
	assert_true(pinv.has_item("cloud_boots"), "加了之后有云靴")
