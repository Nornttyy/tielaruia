#!/usr/bin/env python3
"""
本地 HTTP 服务器, 给浏览器版游戏用.

为什么需要这个: Godot 4 WebAssembly 要求 HTTP 响应带:
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Embedder-Policy: require-corp
Python 自带 http.server 不带这俩头, 用 file:// 直接打开 index.html
也跑不起来. 这脚本就是为了塞这俩头.

用法:
  python3 serve_web.py
然后浏览器打开 http://localhost:8060

依赖: 只用标准库, 任何 Python 3 都行 (Mac 自带).
"""

import http.server
import os
import socketserver
import sys
import webbrowser
from pathlib import Path

PORT = 8060
WEB_DIR = Path(__file__).resolve().parent / "build" / "web"


class GodotWebHandler(http.server.SimpleHTTPRequestHandler):
	def __init__(self, *args, **kwargs):
		super().__init__(*args, directory=str(WEB_DIR), **kwargs)

	def end_headers(self):
		# Godot 4 WASM 需要这俩头才能跑
		self.send_header("Cross-Origin-Opener-Policy", "same-origin")
		self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
		# 防止浏览器缓存旧文件 (开发阶段每次 export 都要看到新版本)
		self.send_header("Cache-Control", "no-store")
		super().end_headers()

	def log_message(self, fmt, *args):
		# 静默 404 之类的噪声, 只 log 实际请求
		if args and "404" in str(args):
			return
		super().log_message(fmt, *args)


def main():
	if not WEB_DIR.exists():
		print(f"❌ {WEB_DIR} 不存在")
		print("先在 Godot 编辑器导出 Web 版本 (项目 → 导出 → Web → 导出项目)")
		print("或者在终端运行: godot --headless --path . --export-release \"Web\" build/web/index.html")
		sys.exit(1)
	if not (WEB_DIR / "index.html").exists():
		print(f"❌ {WEB_DIR}/index.html 不存在, 没找到导出的游戏")
		sys.exit(1)

	url = f"http://localhost:{PORT}"
	print(f"🎮 启动服务器: {url}")
	print(f"📂 服务文件夹: {WEB_DIR}")
	print(f"按 Ctrl+C 停止")
	print()

	# 自动开浏览器
	webbrowser.open(url)

	# 启动服务器
	socketserver.TCPServer.allow_reuse_address = True
	with socketserver.TCPServer(("", PORT), GodotWebHandler) as httpd:
		try:
			httpd.serve_forever()
		except KeyboardInterrupt:
			print("\n👋 服务器已停止")


if __name__ == "__main__":
	main()
