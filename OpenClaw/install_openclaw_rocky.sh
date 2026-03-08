#!/usr/bin/env bash
set -euo pipefail

echo "==> [1/5] 安装依赖 (curl, git, NodeSource repo)"
sudo dnf install -y curl git
curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -
sudo dnf install -y nodejs

echo "==> [2/5] 安装 OpenClaw CLI"
sudo npm install -g openclaw

echo "==> [3/5] 准备配置目录"
mkdir -p "$HOME/.openclaw"

read -r -s -p "请输入 laobai API Key: " LAOBAI_API_KEY
echo
if [[ -z "${LAOBAI_API_KEY}" ]]; then
  echo "API Key 不能为空，退出。"
  exit 1
fi

echo "==> [4/5] 生成最简 openclaw.json (单 provider: laobai)"
cat > "$HOME/.openclaw/openclaw.json" <<JSON
{
  "models": {
    "mode": "replace",
    "providers": {
      "laobai": {
        "baseUrl": "https://laobaiapi.cc/v1",
        "apiKey": "${LAOBAI_API_KEY}",
        "api": "openai-responses",
        "authHeader": true,
        "headers": {
          "User-Agent": "curl/8.5.0"
        },
        "models": [
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

chmod 600 "$HOME/.openclaw/openclaw.json"

echo "==> [5/5] 启动与检查"
openclaw gateway start || true
openclaw gateway status || true
openclaw status || true

echo "完成：OpenClaw 已安装，且已写入单 provider(laobai) 配置。"
