#!/usr/bin/env bash
set -euo pipefail

echo "[1/4] 准备 Rocky 仓库 (EPEL + CRB)..."
if command -v dnf >/dev/null 2>&1; then
  sudo dnf install -y epel-release || true
  sudo dnf config-manager --set-enabled crb || true
  sudo dnf makecache
else
  echo "未检测到 dnf，请手动安装 xclip xsel wl-clipboard"
  exit 1
fi

echo "[2/4] 安装剪贴板依赖..."
sudo dnf install -y xclip xsel || true
sudo dnf install -y wl-clipboard || true

echo "[3/4] 检查安装结果..."
if ! command -v xclip >/dev/null 2>&1 && ! command -v xsel >/dev/null 2>&1 && ! command -v wl-copy >/dev/null 2>&1; then
  echo "[ERROR] 仍未找到可用剪贴板工具（xclip/xsel/wl-copy）"
  echo "请把下面命令输出发我：dnf repolist && dnf search xclip"
  exit 1
fi

echo "[4/4] 检查 osc52 脚本..."
if [[ ! -x "$HOME/.local/bin/osc52" ]]; then
  echo "未找到 $HOME/.local/bin/osc52，请联系我重新生成。"
  exit 1
fi

echo "[OK] 完成。请重开终端后测试。"
echo "测试命令：echo test | osc52"
