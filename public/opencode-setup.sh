#!/usr/bin/env bash
set -euo pipefail

# ====== 可按需修改（只建议改这里）======
# 可选：手动指定安装命令（优先级最高）
# 例如:
#   export OPENCODE_INSTALL_CMD='npm install -g opencode'
#   export OPENCODE_INSTALL_CMD='pnpm add -g opencode'
#   export OPENCODE_INSTALL_CMD='brew install opencode'
# 未指定时会自动检测 npm / pnpm / brew
INSTALL_CMD="${OPENCODE_INSTALL_CMD:-}"

# opencode 配置文件路径
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
CONFIG_FILE="${CONFIG_DIR}/opencode.json"
# 配置模板 URL（文件不存在时会尝试下载）
TEMPLATE_URL="${OPENCODE_TEMPLATE_URL:-https://dl.laobaiapi.cc/opencode.template.json}"
# =======================================

green()  { printf "\033[32m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
red()    { printf "\033[31m%s\033[0m\n" "$*"; }

resolve_install_cmd() {
  if [[ -n "$INSTALL_CMD" ]]; then
    printf "%s" "$INSTALL_CMD"
    return 0
  fi

  if command -v npm >/dev/null 2>&1; then
    printf "%s" "npm install -g opencode"
    return 0
  fi

  if command -v pnpm >/dev/null 2>&1; then
    printf "%s" "pnpm add -g opencode"
    return 0
  fi

  if command -v brew >/dev/null 2>&1; then
    printf "%s" "brew install opencode"
    return 0
  fi

  return 1
}

preview_key() {
  local key="$1"
  local n=${#key}
  if (( n <= 8 )); then
    printf "%s" "$key"
  else
    printf "%s...%s" "${key:0:4}" "${key:n-4:4}"
  fi
}

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf "%s" "$s"
}

install_opencode() {
  local install_cmd

  if command -v opencode >/dev/null 2>&1; then
    green "检测到 opencode 已安装：$(command -v opencode)"
    opencode --version || true
    return 0
  fi

  if ! install_cmd="$(resolve_install_cmd)"; then
    red "未检测到可用包管理器（npm / pnpm / brew）。"
    yellow "请先安装其中一个，或设置 OPENCODE_INSTALL_CMD 指定安装命令。"
    return 1
  fi

  yellow "开始安装 opencode..."
  yellow "执行命令: $install_cmd"
  bash -c "$install_cmd"

  if command -v opencode >/dev/null 2>&1; then
    green "安装成功：$(command -v opencode)"
    opencode --version || true
  else
    red "安装命令已执行，但未检测到 opencode 命令。"
    yellow "请检查 INSTALL_CMD 是否正确。"
    return 1
  fi
}

download_template_if_needed() {
  if [[ -f "$CONFIG_FILE" ]]; then
    return 0
  fi

  if [[ -z "$TEMPLATE_URL" ]]; then
    return 1
  fi

  if command -v curl >/dev/null 2>&1; then
    if curl -fsSL "$TEMPLATE_URL" -o "$CONFIG_FILE"; then
      yellow "已下载配置模板：$TEMPLATE_URL"
      return 0
    fi
  elif command -v wget >/dev/null 2>&1; then
    if wget -qO "$CONFIG_FILE" "$TEMPLATE_URL"; then
      yellow "已下载配置模板：$TEMPLATE_URL"
      return 0
    fi
  fi

  return 1
}

save_api_key() {
  local key="$1"
  local existed_before=0

  mkdir -p "$CONFIG_DIR"
  chmod 700 "$CONFIG_DIR" || true

  if [[ -f "$CONFIG_FILE" ]]; then
    existed_before=1
  fi

  download_template_if_needed || true

  if [[ "$existed_before" -eq 1 && -f "$CONFIG_FILE" ]]; then
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak.$(date +%Y%m%d%H%M%S)"
    yellow "已备份旧配置文件。"
  fi

  umask 077

  if command -v jq >/dev/null 2>&1 && [[ -s "$CONFIG_FILE" ]]; then
    local tmp
    tmp="$(mktemp)"
    if jq --arg k "$key" '.provider.openai.options.apiKey = $k' "$CONFIG_FILE" > "$tmp" 2>/dev/null; then
      mv "$tmp" "$CONFIG_FILE"
    else
      rm -f "$tmp"
      cat > "$CONFIG_FILE" <<EOF
{
  "provider": {
    "openai": {
      "options": {
        "apiKey": "$key"
      }
    }
  }
}
EOF
    fi
  elif command -v python3 >/dev/null 2>&1 && [[ -s "$CONFIG_FILE" ]]; then
    local tmp
    tmp="$(mktemp)"
    if python3 - "$CONFIG_FILE" "$key" > "$tmp" <<'PY'
import json
import sys

path = sys.argv[1]
key = sys.argv[2]

with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

def update_api_key(value):
    if isinstance(value, dict):
        for k in list(value.keys()):
            if k == "apiKey":
                value[k] = key
            else:
                update_api_key(value[k])
    elif isinstance(value, list):
        for item in value:
            update_api_key(item)

update_api_key(data)

if isinstance(data, dict):
    provider = data.setdefault("provider", {})
    openai = provider.setdefault("openai", {})
    options = openai.setdefault("options", {})
    options["apiKey"] = key

print(json.dumps(data, ensure_ascii=False, indent=2))
PY
    then
      mv "$tmp" "$CONFIG_FILE"
    else
      rm -f "$tmp"
      cat > "$CONFIG_FILE" <<EOF
{
  "provider": {
    "openai": {
      "options": {
        "apiKey": "$key"
      }
    }
  }
}
EOF
    fi
  else
    cat > "$CONFIG_FILE" <<EOF
{
  "provider": {
    "openai": {
      "options": {
        "apiKey": "$key"
      }
    }
  }
}
EOF
  fi

  chmod 600 "$CONFIG_FILE" || true
  green "API Key 已写入：$CONFIG_FILE"
}

configure_apikey() {
  local mode key confirm p

  echo "请选择输入方式："
  echo "1) 明文输入（可见）"
  echo "2) 隐藏输入（推荐）"
  read -r -p "输入选项 [1/2]： " mode

  case "$mode" in
    1)
      read -r -p "请输入 API Key（明文）： " key
      ;;
    2|"")
      read -r -s -p "请输入 API Key（隐藏）： " key
      echo
      ;;
    *)
      red "无效选项。"
      return 1
      ;;
  esac

  if [[ -z "${key:-}" ]]; then
    red "API Key 不能为空。"
    return 1
  fi

  p="$(preview_key "$key")"
  yellow "Key 预览：$p"

  read -r -p "确认保存这个 Key？[y/N]: " confirm
  if [[ "${confirm,,}" == "y" ]]; then
    save_api_key "$key"
  else
    yellow "已取消保存。"
  fi
}

one_click() {
  install_opencode
  configure_apikey
}

main_menu() {
  while true; do
    echo
    echo "========== OpenCode 一键脚本 =========="
    echo "1) 安装 opencode"
    echo "2) 配置 API Key"
    echo "3) 一键执行（安装 + 配置）"
    echo "0) 退出"
    echo "======================================="
    read -r -p "请选择 [0-3]: " choice

    case "$choice" in
      1) install_opencode || true ;;
      2) configure_apikey || true ;;
      3) one_click || true ;;
      0) echo "已退出"; exit 0 ;;
      *) red "无效选项，请重新输入。" ;;
    esac
  done
}

main_menu
