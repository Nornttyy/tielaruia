#!/bin/bash
# 启动 godot 游戏. 自动找 Godot 二进制 (PATH 或 /Applications).
#
# 用法:
#   ./run.sh             # 仅启动游戏 (快, 不重建缓存)
#   ./run.sh --rebuild   # 完整重建 .godot 缓存后启动 (慢, 改了 class_name/资源后用)
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

# 解析 --rebuild
REBUILD=false
ARGS=()
for arg in "$@"; do
	if [ "$arg" = "--rebuild" ]; then
		REBUILD=true
	else
		ARGS+=("$arg")
	fi
done

killall Godot 2>/dev/null || true
killall godot 2>/dev/null || true

if [ "$REBUILD" = true ]; then
	echo "[run.sh] 重建 .godot 缓存 (可能 10-30s)..."
	rm -rf .godot
	# --import 比 --editor --quit 更直接, 而且不静默 stderr 方便看错误
	"$GODOT" --headless --path . --import
	echo "[run.sh] 缓存重建完, 启动游戏"
fi

"$GODOT" --path . "${ARGS[@]}"
