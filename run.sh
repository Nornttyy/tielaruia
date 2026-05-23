#!/bin/bash
# 硬刷新启动 godot: kill 旧进程 → 删 .godot 缓存 → 重建 class 索引 → 启动游戏.
# 自动找 Godot 二进制: 优先 PATH 里的 godot, 否则 Mac 上 /Applications/Godot.app.
set -e

# 找 godot 二进制
if command -v godot >/dev/null 2>&1; then
	GODOT=godot
elif [ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
	GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
elif [ -x "/Applications/Godot_v4.3.app/Contents/MacOS/Godot" ]; then
	GODOT="/Applications/Godot_v4.3.app/Contents/MacOS/Godot"
else
	echo "找不到 Godot. 请装到 /Applications/Godot.app 或加到 PATH" >&2
	exit 1
fi

killall Godot 2>/dev/null || true
killall godot 2>/dev/null || true
rm -rf .godot
"$GODOT" --headless --editor --quit 2>/dev/null
"$GODOT" --path . "$@"
