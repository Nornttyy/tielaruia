#!/bin/bash
# Mac 上双击这个文件就能重新导出 web 版本 (build/web/ 会被刷新).
# 自动找 Godot.app, 没有就报错.
cd "$(dirname "$0")"

if [ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
	GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
elif [ -x "/Applications/Godot_v4.3.app/Contents/MacOS/Godot" ]; then
	GODOT="/Applications/Godot_v4.3.app/Contents/MacOS/Godot"
else
	echo "❌ 找不到 Godot. 请装到 /Applications/Godot.app"
	read -p "按回车关闭..."
	exit 1
fi

mkdir -p build/web
echo "🔨 导出 web 版本 (可能 10-30s)..."
"$GODOT" --headless --path . --export-release "Web" build/web/index.html
echo "✅ 导出完成: build/web/"
echo ""
echo "现在双击 play_web.command 就能在浏览器里玩"
read -p "按回车关闭..."
