#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="$HOME/.openclaw"
CONFIG_PATH="$CONFIG_DIR/openclaw.json"
MODE_ARG="${1:-}"
PRIMARY_MODEL=""
FALLBACK_MODEL=""

has_tty() {
  [[ -r /dev/tty ]]
}

sanitize_secret() {
  local __v="$1"
  __v="${__v//$'\r'/}"
  __v="${__v//$'\n'/}"
  printf "%s" "$__v"
}

prompt_read() {
  local __var_name="$1"
  local __prompt="$2"
  local __value=""
  if has_tty; then
    read -r -p "$__prompt" __value < /dev/tty
  else
    read -r -p "$__prompt" __value
  fi
  __value="$(sanitize_secret "$__value")"
  printf -v "$__var_name" "%s" "$__value"
}

prompt_read_secret() {
  local __var_name="$1"
  local __prompt="$2"
  local __value=""
  if has_tty; then
    read -r -s -p "$__prompt" __value < /dev/tty
    echo
  else
    read -r -s -p "$__prompt" __value
    echo
  fi
  __value="$(sanitize_secret "$__value")"
  printf -v "$__var_name" "%s" "$__value"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "缺少命令: $1"
    exit 1
  }
}

gen_token() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
  else
    python3 - <<'PY'
import secrets
print(secrets.token_hex(32))
PY
  fi
}

install_runtime() {
  echo "==> [1/4] 安装依赖 (curl, git, Node.js 22)"
  sudo dnf install -y curl git
  curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -
  sudo dnf install -y nodejs

  echo "==> [2/4] 安装 OpenClaw CLI"
  sudo npm install -g openclaw
}

prompt_key() {
  prompt_read LAOBAI_API_KEY "请输入 laobai API Key: "
  LAOBAI_API_KEY="$(sanitize_secret "${LAOBAI_API_KEY:-}")"
  if [[ -z "${LAOBAI_API_KEY:-}" ]]; then
    echo "API Key 不能为空，退出。"
    exit 1
  fi

  local key_len=${#LAOBAI_API_KEY}
  local head="${LAOBAI_API_KEY:0:4}"
  local tail="${LAOBAI_API_KEY:key_len-4:4}"
  local mask_len=$(( key_len - 8 ))
  local middle_mask=""

  if (( key_len <= 8 )); then
    # 太短时避免暴露过多信息
    if (( key_len <= 4 )); then
      head="${LAOBAI_API_KEY:0:1}"
      tail="${LAOBAI_API_KEY:key_len-1:1}"
    else
      head="${LAOBAI_API_KEY:0:2}"
      tail="${LAOBAI_API_KEY:key_len-2:2}"
    fi
    middle_mask="****"
  else
    middle_mask=$(printf '%*s' "$mask_len" '' | tr ' ' '*')
  fi

  echo "已接收 API Key（校验展示）：${head}${middle_mask}${tail}"
}

prompt_primary_model() {
  local choice=""
  echo "请选择默认模型："
  echo "  1) laobai/gpt-5.4-mini"
  echo "  2) laobai/gpt-5.3-codex"
  prompt_read choice "输入 1 或 2 [默认1]: "

  if [[ -z "$choice" ]]; then
    choice="1"
  fi

  case "$choice" in
    1)
      PRIMARY_MODEL="laobai/gpt-5.4-mini"
      FALLBACK_MODEL="laobai/gpt-5.3-codex"
      ;;
    2)
      PRIMARY_MODEL="laobai/gpt-5.3-codex"
      FALLBACK_MODEL="laobai/gpt-5.4-mini"
      ;;
    *)
      echo "无效模型选择，退出。"
      exit 1
      ;;
  esac

  echo "默认模型: ${PRIMARY_MODEL}"
  echo "首选回退: ${FALLBACK_MODEL}"
}

write_fresh_config() {
  local gateway_token="$1"
  mkdir -p "$CONFIG_DIR"
  cat > "$CONFIG_PATH" <<JSON
{
  "gateway": {
    "mode": "local",
    "auth": {
      "mode": "token",
      "token": "${gateway_token}"
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "${PRIMARY_MODEL}",
        "fallbacks": [
          "${FALLBACK_MODEL}"
        ]
      },
      "models": {
        "laobai/gpt-5.4-mini": {
          "alias": "laobai-mini"
        },
        "laobai/gpt-5.3-codex": {
          "alias": "laobai-codex"
        }
      }
    }
  },
  "models": {
    "mode": "replace",
    "providers": {
      "laobai": {
        "baseUrl": "https://laobaiapi.cc/v1",
        "apiKey": "${LAOBAI_API_KEY}",
        "authHeader": true,
        "headers": {
          "User-Agent": "curl/8.5.0"
        },
        "models": [
          {
            "id": "gpt-5.4-mini",
            "name": "GPT-5.4 Mini (via laobai)",
            "api": "openai-responses",
            "reasoning": true,
            "input": ["text", "image"],
            "cost": {
              "input": 0,
              "output": 0,
              "cacheRead": 0,
              "cacheWrite": 0
            },
            "contextWindow": 204800,
            "maxTokens": 8192
          },
          {
            "id": "gpt-5.3-codex",
            "name": "GPT-5.3 Codex (via laobai)",
            "api": "openai-responses",
            "reasoning": true,
            "input": ["text", "image"],
            "cost": {
              "input": 0,
              "output": 0,
              "cacheRead": 0,
              "cacheWrite": 0
            },
            "contextWindow": 204800,
            "maxTokens": 8192
          }
        ]
      }
    }
  }
}
JSON
  chmod 600 "$CONFIG_PATH"
}

inject_laobai() {
  local gateway_token="$1"
  mkdir -p "$CONFIG_DIR"
  if [[ -f "$CONFIG_PATH" ]]; then
    cp "$CONFIG_PATH" "$CONFIG_PATH.bak.$(date +%Y%m%d-%H%M%S)"
  else
    echo '{}' > "$CONFIG_PATH"
  fi

  python3 - "$CONFIG_PATH" "$LAOBAI_API_KEY" "$gateway_token" "$PRIMARY_MODEL" "$FALLBACK_MODEL" <<'PY'
import json, sys
path, api_key, token, primary_model, fallback_model = sys.argv[1:6]
with open(path, 'r', encoding='utf-8') as f:
    text = f.read().strip() or '{}'
try:
    data = json.loads(text)
except Exception as e:
    raise SystemExit(f'现有 openclaw.json 不是合法 JSON，无法注入: {e}')

gateway = data.setdefault('gateway', {})
gateway['mode'] = 'local'
auth = gateway.setdefault('auth', {})
auth['mode'] = 'token'
if not auth.get('token'):
    auth['token'] = token

agents = data.setdefault('agents', {})
defaults = agents.setdefault('defaults', {})

old_model = defaults.get('model', {})

def as_list(value):
    if isinstance(value, str):
        return [value] if value else []
    if isinstance(value, list):
        return [item for item in value if isinstance(item, str) and item]
    return []

fallback_chain = [fallback_model]
fallback_chain.extend(as_list(old_model.get('primary')))
fallback_chain.extend(as_list(old_model.get('fallbacks')))
fallback_chain.extend(as_list(old_model.get('fallback')))

seen = set()
deduped_fallback = []
for item in fallback_chain:
    if item == primary_model or item in seen:
        continue
    seen.add(item)
    deduped_fallback.append(item)

defaults['model'] = {
    'primary': primary_model,
    'fallbacks': deduped_fallback,
}

allow = defaults.setdefault('models', {})
allow['laobai/gpt-5.4-mini'] = {'alias': 'laobai-mini'}
allow['laobai/gpt-5.3-codex'] = {'alias': 'laobai-codex'}

models = data.setdefault('models', {})
models['mode'] = 'merge'
providers = models.setdefault('providers', {})
laobai = providers.setdefault('laobai', {})
laobai['baseUrl'] = 'https://laobaiapi.cc/v1'
laobai['apiKey'] = api_key
laobai['api'] = 'openai-responses'
laobai['authHeader'] = True
headers = laobai.setdefault('headers', {})
headers['User-Agent'] = 'curl/8.5.0'

existing_models = laobai.get('models')
if not isinstance(existing_models, list):
    existing_models = []

def upsert_model(model_list, model_def):
    target_id = model_def.get('id')
    for item in model_list:
        if isinstance(item, dict) and item.get('id') == target_id:
            item.update(model_def)
            return
    model_list.append(model_def)

upsert_model(existing_models, {
    'id': 'gpt-5.4-mini',
    'name': 'GPT-5.4 Mini (via laobai)',
    'api': 'openai-responses',
    'reasoning': True,
    'input': ['text', 'image'],
    'cost': {'input': 0, 'output': 0, 'cacheRead': 0, 'cacheWrite': 0},
    'contextWindow': 204800,
    'maxTokens': 8192,
})
upsert_model(existing_models, {
    'id': 'gpt-5.3-codex',
    'name': 'GPT-5.3 Codex (via laobai)',
    'api': 'openai-responses',
    'reasoning': True,
    'input': ['text', 'image'],
    'cost': {'input': 0, 'output': 0, 'cacheRead': 0, 'cacheWrite': 0},
    'contextWindow': 204800,
    'maxTokens': 8192,
})

laobai['models'] = existing_models

with open(path, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write('\n')
PY
}

get_gateway_token() {
  python3 - "$CONFIG_PATH" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)
print(data.get('gateway', {}).get('auth', {}).get('token', ''))
PY
}

post_check() {
  echo "==> 校验配置"
  openclaw doctor || true

  echo "==> 启动与检查"
  openclaw gateway start || true
  openclaw gateway status || true
  openclaw status || true
}

main() {
  local mode="${MODE_ARG:-}"

  if [[ -z "$mode" ]]; then
    echo "请选择模式："
    echo "  1) 全新安装 OpenClaw（生成干净单 provider laobai 配置）"
    echo "  2) 已安装 OpenClaw，注入 laobai provider 并切默认模型"
    prompt_read mode "输入 1 或 2: "
  fi

  case "$mode" in
    --fresh)
      mode="1"
      ;;
    --inject)
      mode="2"
      ;;
    --help|-h)
      cat <<'EOF'
用法:
  bash openclaw-setup.sh
  bash openclaw-setup.sh --fresh
  bash openclaw-setup.sh --inject
EOF
      exit 0
      ;;
  esac

  case "$mode" in
    1)
      install_runtime
      prompt_key
      prompt_primary_model
      GATEWAY_TOKEN="$(gen_token)"
      echo "==> [3/4] 生成全新 openclaw.json"
      write_fresh_config "$GATEWAY_TOKEN"
      echo "==> [4/4] 已写入 gateway token"
      ;;
    2)
      require_cmd python3
      require_cmd openclaw
      prompt_key
      prompt_primary_model
      GATEWAY_TOKEN="$(gen_token)"
      echo "==> 注入 laobai provider 并切换默认模型"
      inject_laobai "$GATEWAY_TOKEN"
      ;;
    *)
      echo "无效选择，退出。"
      exit 1
      ;;
  esac

  post_check
  FINAL_GATEWAY_TOKEN="$(get_gateway_token)"
  echo
  echo "完成：配置文件路径 -> $CONFIG_PATH"
  echo "请保存好 Gateway token：${FINAL_GATEWAY_TOKEN}"
  echo "提醒：后续连接 Control UI、节点或远程客户端时，token 就是这个。"
}

main "$@"
