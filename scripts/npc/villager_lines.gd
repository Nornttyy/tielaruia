# 村民对话词条池。E 互动时随机选 1 句。
class_name VillagerLines extends RefCounted

const LINES := [
	"今天天气真好。",
	"听说山那边有怪物。",
	"你也是冒险者吗？",
	"记得多砍点树。",
	"晚上要小心史莱姆。",
	"工作台能合出更好的工具。",
	"我从来没出过这个村子。",
	"希望明年丰收。",
	"这个村庄已经有 30 年了。",
	"你看起来很厉害的样子。",
]


static func random_line() -> String:
	return LINES[randi() % LINES.size()]
