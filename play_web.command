#!/bin/bash
# Mac 上双击这个文件就能在浏览器里玩 (前提: build/web/ 已导出).
# 自动 cd 到脚本所在目录, 然后跑 serve_web.py.
cd "$(dirname "$0")"
python3 serve_web.py
