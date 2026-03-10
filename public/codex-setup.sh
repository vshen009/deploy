#!/usr/bin/env bash
set -euo pipefail

sanitize_api_key() {
  local __v="$1"
  __v="${__v//$'\r'/}"
  __v="${__v//$'\n'/}"
  printf "%s" "$__v"
}

mkdir -p ~/.codex
[ -f ~/.codex/config.toml ] && cp ~/.codex/config.toml ~/.codex/config.toml.bak

cat > ~/.codex/config.toml << 'CODEX_CONFIG'
model_provider = "laobai"
model = "gpt-5.4"
model_reasoning_effort = "high"
network_access = "enabled"
disable_response_storage = true
windows_wsl_setup_acknowledged = true
model_verbosity = "high"

[model_providers.laobai]
name = "laobai"
base_url = "https://laobaiapi.cc"
wire_api = "responses"
requires_openai_auth = true
CODEX_CONFIG

[ -f ~/.codex/config.toml.bak ] && awk '/^\[model_providers\.laobai\]/{skip=1;next} /^\[/{skip=0} skip{next} /^\[/{found=1} found{print}' ~/.codex/config.toml.bak >> ~/.codex/config.toml

API_KEY="$(sanitize_api_key "${LAOBAI_API_KEY:-}")"
if [[ -z "$API_KEY" ]]; then
  read -r -s -p "请输入 laobai API Key: " API_KEY < /dev/tty
  echo
fi

API_KEY="$(sanitize_api_key "$API_KEY")"

if [[ -z "$API_KEY" ]]; then
  echo "❌ API Key 不能为空"
  exit 1
fi

cat > ~/.codex/auth.json << CODEX_AUTH
{
  "OPENAI_API_KEY": "${API_KEY}"
}
CODEX_AUTH

echo "✅ Done!"
