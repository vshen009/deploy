# OpenClaw 一键安装 / 注入配置（Rocky Linux）

目标：
- 方式一：**全新安装** OpenClaw，并生成一个干净可启动的单 provider（laobai）配置
- 方式二：对**已经安装好的本地 OpenClaw**，向现有 `~/.openclaw/openclaw.json` **注入 laobai provider**，并把默认模型切到 `laobai/gpt-5.3-codex`
- 两种方式都补齐最低启动要件：`gateway.mode=local`、`gateway.auth.token`、默认模型

## 一行下载运行（推荐）

```bash
curl -fsSL https://dl.laobaiapi.cc/openclaw-setup.sh | bash
```

> 适合 Rocky / RHEL 系。脚本会自动弹出菜单，让你选择“全新安装”或“注入 laobai provider”。

版本固定（v1）：

```bash
curl -fsSL https://dl.laobaiapi.cc/v1/openclaw-setup.sh | bash
```

## 仓库内手动运行（调试用）

```bash
curl -fsSL https://dl.laobaiapi.cc/openclaw-setup.sh -o openclaw-setup.sh
chmod +x openclaw-setup.sh
./openclaw-setup.sh
```

脚本会弹出 2 个菜单：

### 1) 全新安装
适合：机器上还没装 OpenClaw，或者你想直接生成一份干净配置。

脚本会：
1. 安装 Node.js 22 + npm
2. 全局安装 OpenClaw CLI
3. 询问 laobai API Key（静默输入，回车后会显示“前4位 + 掩码 + 后4位”用于校验）
4. 自动生成 gateway token
5. 写入一份可启动的 `~/.openclaw/openclaw.json`
6. 尝试启动 gateway 并输出状态

### 2) 注入 laobai provider
适合：本机已经装好了 OpenClaw，你只想把老白 provider 打进去，并把默认模型改成老白。

脚本会：
1. 读取现有 `~/.openclaw/openclaw.json`
2. 先做一个时间戳备份 `openclaw.json.bak.YYYYmmdd-HHMMSS`
3. 询问 laobai API Key（静默输入，回车后会显示“前4位 + 掩码 + 后4位”用于校验）
4. 注入 `models.providers.laobai`
5. 将 `agents.defaults.model.primary` 改成 `laobai/gpt-5.3-codex`
6. 在 `agents.defaults.models` 中加入 `laobai/gpt-5.3-codex`
7. 若缺少 `gateway.mode` / `gateway.auth.token`，自动补齐，保证能启动
8. 尝试启动 gateway 并输出状态

## 模板文件

### `openclaw.single-provider.template.json`
用于**全新安装**的干净模板：
- `models.mode = "replace"`
- 只保留 `laobai`
- 包含默认模型、gateway local 模式、gateway token 占位

### `openclaw.inject-laobai.template.json`
用于**往现有配置注入**的思路模板：
- `models.mode = "merge"`
- 保留已有 provider，同时增加 `laobai`
- 把默认模型切到 `laobai/gpt-5.3-codex`
- 包含 gateway local / token 的最低启动要求

## 说明

- 这里的模板和脚本都按“**最小可启动**”思路整理，不含任何聊天渠道配置。
- `gateway.auth.token` 由脚本自动生成并写入配置；如果现有配置里已经有 token，注入模式会保留原 token 不覆盖。
- 脚本执行结束后，会把当前生效的 Gateway token 明确打印出来，方便你保存。
- 如果现有 `openclaw.json` 不是合法 JSON，注入模式会停止，避免写坏配置。
- 当前脚本面向 Rocky Linux（`dnf` + NodeSource）。
