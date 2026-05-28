# 中文 (基准语言). Locale.t(key) 找不到当前语言时 fallback 来这里.
# 加新文字: 先在这里定 key 中文, 然后 strings_en/ja/ko 加同名 key.
extends RefCounted

const S := {
	# 语言选择 (设置面板用)
	"lang_name": "中文",
	"lang_label": "语言",

	# 主菜单按钮
	"menu_new_game": "开始游戏",
	"menu_multiplayer": "多人游戏",
	"menu_settings": "设置",

	# 设置面板
	"settings_title": "设置",
	"settings_master_volume": "主音量",
	"settings_camera_zoom": "摄像机大小",
	"settings_back": "返回",

	# 世界选择 (WorldSelectPanel)
	"world_select_title": "选择世界",
	"world_select_empty": "还没有存档, 先创建一个新世界",
	"world_new": "创建新世界",
	"world_enter": "进入",
	"world_delete": "删除",
	"world_back": "返回",

	# 新建世界面板 (NewGamePanel)
	"newgame_title": "新建世界",
	"newgame_name_label": "世界名",
	"newgame_seed_label": "种子",
	"newgame_seed_random": "随机",
	"newgame_difficulty_label": "难度",
	"newgame_difficulty_easy": "简单",
	"newgame_difficulty_normal": "普通",
	"newgame_difficulty_hard": "困难",
	"newgame_cancel": "取消",
	"newgame_start": "开始",
	"newgame_default_world_name": "我的世界",

	# 多人游戏面板
	"mp_title": "联机",
	"mp_room_code_prompt": "输入朋友给的 6 位房间码",
	"mp_join_label": "加入",
	"mp_back": "返回",
	"mp_status_idle": "输入朋友给的 6 位房间码",
	"mp_status_joining": "连接中...",
	"mp_status_connected": "已连接, 加载世界...",
	"mp_status_disconnected": "对方断开了",
	"mp_status_error_prefix": "出错: ",
	"mp_room_code_invalid": "房间码必须是 6 位字母数字",
	"mp_module_missing": "联机模块未加载",
	"mp_default_world_name": "联机世界",

	# 删除存档对话框
	"delete_save_title": "删除存档",
	"delete_save_message": "真的要删除存档 \"%s\" 吗? \n这个操作不能撤销!",
	"delete_save_ok": "删除",
	"delete_save_cancel": "取消",
}
