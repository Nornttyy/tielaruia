#!/bin/bash
# Mac 上双击这个文件就推 main 到 GitHub.
# 推完 GitHub Actions 自动 build + 部署到 https://nornttyy.github.io/tielaruia/
# (大概 3-5 分钟后网站更新).
cd "$(dirname "$0")"

echo "→ 当前本地领先 origin/main 的 commit:"
git log --oneline origin/main..HEAD | head -10
COUNT=$(git log --oneline origin/main..HEAD | wc -l | tr -d ' ')
echo ""
echo "→ 一共 $COUNT 个 commit 要推. 继续? (回车继续, Ctrl-C 取消)"
read

echo "→ git push origin main..."
git push origin main

echo ""
echo "✅ 推完了! 去 https://github.com/Nornttyy/tielaruia/actions 看部署进度"
echo "    大概 3-5 分钟后 https://nornttyy.github.io/tielaruia/ 会更新"
read -p "按回车关闭..."
