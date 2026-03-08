#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_DIR"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[ERROR] 当前目录不是 git 仓库: $REPO_DIR"
  exit 1
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  echo "[ERROR] 未配置 origin，请先执行："
  echo "git remote add origin https://github.com/vshen009/deploy.git"
  exit 1
fi

if [[ -z "$(git status --porcelain)" ]]; then
  echo "[INFO] 没有需要提交的变更。"
  git status -sb
  exit 0
fi

git add .
git commit -m "fix template and installer apiKey handling"

if git push -u origin main; then
  echo "[OK] 已推送到 origin/main"
else
  echo "[ERROR] 推送失败（通常是未登录 GitHub）"
  echo "请先执行："
  echo "  export PATH=\"$HOME/.local/bin:$PATH\""
  echo "  gh auth login -h github.com -p https -w"
  echo "  gh auth setup-git"
  echo "然后再重跑：bash push_deploy.sh"
  exit 1
fi
