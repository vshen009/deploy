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

has_tty() {
  [[ -r /dev/tty ]]
}

prompt_read() {
  local __var_name="$1"
  local __prompt="$2"
  local __value=""
  if ! has_tty; then
    return 1
  fi
  read -r -p "$__prompt" __value < /dev/tty
  printf -v "$__var_name" "%s" "$__value"
}

prompt_read_secret() {
  local __var_name="$1"
  local __prompt="$2"
  local __value=""
  if ! has_tty; then
    return 1
  fi
  read -r -s -p "$__prompt" __value < /dev/tty
  echo
  printf -v "$__var_name" "%s" "$__value"
}

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
  if ! prompt_read mode "输入选项 [1/2]： "; then
    red "当前会话不可交互，请设置 OPENCODE_API_KEY 后重试。"
    return 1
  fi

  case "$mode" in
    1)
      if ! prompt_read key "请输入 API Key（明文）： "; then
        red "当前会话不可交互，请设置 OPENCODE_API_KEY 后重试。"
        return 1
      fi
      ;;
    2|"")
      if ! prompt_read_secret key "请输入 API Key（隐藏）： "; then
        red "当前会话不可交互，请设置 OPENCODE_API_KEY 后重试。"
        return 1
      fi
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

  if ! prompt_read confirm "确认保存这个 Key？[y/N]: "; then
    red "当前会话不可交互，请设置 OPENCODE_API_KEY 后重试。"
    return 1
  fi
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

install_clipboard_deps() {
  if command -v xclip >/dev/null 2>&1 || command -v xsel >/dev/null 2>&1 || command -v wl-copy >/dev/null 2>&1 || command -v pbcopy >/dev/null 2>&1; then
    green "已检测到可用剪贴板工具。"
    return 0
  fi

  if command -v dnf >/dev/null 2>&1; then
    yellow "检测到 dnf，准备安装剪贴板依赖..."
    sudo dnf install -y epel-release || true
    sudo dnf config-manager --set-enabled crb || true
    sudo dnf makecache || true
    sudo dnf install -y xclip xsel wl-clipboard
    return 0
  fi

  if command -v apt-get >/dev/null 2>&1; then
    yellow "检测到 apt，准备安装剪贴板依赖..."
    sudo apt-get update
    sudo apt-get install -y xclip xsel wl-clipboard
    return 0
  fi

  if command -v brew >/dev/null 2>&1; then
    yellow "检测到 macOS 环境，系统通常自带 pbcopy。"
    return 0
  fi

  red "未识别包管理器，无法自动安装剪贴板依赖。"
  return 1
}

write_osc52_bridge() {
  mkdir -p "$HOME/.local/bin"

  cat > "$HOME/.local/bin/osc52" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ ! -t 0 ]; then
  data="$(cat)"
else
  data="${*:-}"
fi

if [[ -z "$data" ]]; then
  echo "用法: echo 'text' | osc52 或 osc52 'text'" >&2
  exit 1
fi

if command -v pbcopy >/dev/null 2>&1; then
  printf "%s" "$data" | pbcopy
  echo "已复制到剪贴板 (pbcopy)"
  exit 0
fi

if command -v wl-copy >/dev/null 2>&1 && [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
  printf "%s" "$data" | wl-copy
  echo "已复制到剪贴板 (wl-copy)"
  exit 0
fi

if command -v xclip >/dev/null 2>&1; then
  printf "%s" "$data" | xclip -selection clipboard -quiet
  echo "已复制到剪贴板 (xclip)"
  exit 0
fi

if command -v xsel >/dev/null 2>&1; then
  printf "%s" "$data" | xsel --clipboard --input
  echo "已复制到剪贴板 (xsel)"
  exit 0
fi

echo "错误: 未找到可用剪贴板工具，请先安装 xclip/xsel/wl-clipboard" >&2
exit 1
EOF

  chmod +x "$HOME/.local/bin/osc52"
  green "已写入剪贴板桥接脚本：$HOME/.local/bin/osc52"
}

fix_clipboard() {
  install_clipboard_deps
  write_osc52_bridge

  if printf "opencode-clipboard-test" | "$HOME/.local/bin/osc52" >/dev/null 2>&1; then
    green "剪贴板修复完成，测试通过。"
  else
    yellow "脚本已安装，但测试未通过（常见于远程/无图形会话）。"
    yellow "请在本地图形终端执行：echo test | osc52"
  fi
}

main_menu() {
  while true; do
    echo
    echo "========== OpenCode 一键脚本 =========="
    echo "1) 安装 opencode"
    echo "2) 配置 API Key"
    echo "3) 一键执行（安装 + 配置）"
    echo "4) 修复剪贴板问题"
    echo "0) 退出"
    echo "======================================="
    if ! prompt_read choice "请选择 [0-4]: "; then
      red "未检测到可交互终端，无法显示菜单。"
      yellow "可使用：OPENCODE_API_KEY='sk-...' bash opencode-setup.sh --one-click"
      return 1
    fi

    case "$choice" in
      1) install_opencode || true ;;
      2) configure_apikey || true ;;
      3) one_click || true ;;
      4) fix_clipboard || true ;;
      0) echo "已退出"; exit 0 ;;
      *) red "无效选项，请重新输入。" ;;
    esac
  done
}

run_cli() {
  local cmd="${1:-menu}"
  local env_key="${OPENCODE_API_KEY:-}"
  local key="$env_key"

  case "$cmd" in
    --install)
      install_opencode
      ;;
    --configure)
      if [[ -n "$key" ]]; then
        save_api_key "$key"
      else
        configure_apikey
      fi
      ;;
    --one-click)
      install_opencode
      if [[ -n "$key" ]]; then
        save_api_key "$key"
      else
        configure_apikey
      fi
      ;;
    --fix-clipboard)
      fix_clipboard
      ;;
    --help|-h)
      cat <<'EOF'
用法:
  bash opencode-setup.sh
  bash opencode-setup.sh --install
  OPENCODE_API_KEY='sk-xxx' bash opencode-setup.sh --configure
  OPENCODE_API_KEY='sk-xxx' bash opencode-setup.sh --one-click
  bash opencode-setup.sh --fix-clipboard
EOF
      ;;
    menu|"")
      main_menu
      ;;
    *)
      red "未知参数: $cmd"
      yellow "使用 --help 查看可用命令。"
      return 1
      ;;
  esac
}

run_cli "${1:-menu}"
