#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PUBLIC_SCRIPT="$ROOT_DIR/public/openclaw-setup.sh"
REMOTE_SCRIPT_URL="https://dl.laobaiapi.cc/openclaw-setup.sh"

if [[ -x "$PUBLIC_SCRIPT" || -f "$PUBLIC_SCRIPT" ]]; then
  exec bash "$PUBLIC_SCRIPT" "$@"
fi

echo "未找到本地 public/openclaw-setup.sh，尝试从线上下载执行: $REMOTE_SCRIPT_URL"
exec bash <(curl -fsSL "$REMOTE_SCRIPT_URL") "$@"
