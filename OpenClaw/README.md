# OpenClaw 一键安装（Rocky Linux）

目标：
- 一键安装 OpenClaw
- 仅保留 1 个 provider（laobai）
- API Key 由你手动输入

## 使用步骤

```bash
cd OpenClaw
chmod +x install_openclaw_rocky.sh
./install_openclaw_rocky.sh
```

安装脚本会：
1. 安装 Node.js 22 + npm
2. 全局安装 OpenClaw CLI
3. 生成最简 `~/.openclaw/openclaw.json`（仅 laobai）
4. 你输入 API Key 后自动写入配置
5. 尝试启动 gateway 并输出状态

## 配置文件模板

模板在：`openclaw.single-provider.template.json`

> 说明：脚本会直接生成可用配置，你一般不用手动改模板。
