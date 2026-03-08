# Cloudflare Pages 剩余步骤（换电脑继续）

这份文档用于在新电脑上继续完成 `deploy` 仓库上线，不依赖当前机器环境。

## 1) 在新电脑拉取仓库

```bash
git clone https://github.com/vshen009/deploy.git
cd deploy
```

## 2) 登录 Cloudflare 控制台

- 打开：`https://dash.cloudflare.com/`
- 说明：`https://dash.cloudflare.com/login` 页面不一定提供 GitHub 登录按钮，这是正常现象。
- 重点：Cloudflare 账号登录方式，和 Pages 连接 GitHub 仓库是两件事。

## 3) 创建 Pages 项目并连接仓库

1. 左侧进入 `Workers & Pages`
2. 点击 `Create`
3. 选择 `Pages`
4. 选择 `Connect to Git`
5. 授权并选择仓库：`vshen009/deploy`

## 4) 构建配置

- Framework preset: `None`
- Build command: 留空
- Build output directory: `public`
- 点击 `Save and Deploy`

## 5) 绑定自定义域名

1. 进入 Pages 项目
2. 打开 `Custom domains`
3. 添加：`dl.laobaiapi.cc`
4. 按提示完成 DNS（通常自动创建 CNAME）
5. 等状态变为 Active

## 6) 验证访问

以下链接能打开即表示部署成功：

- `https://dl.laobaiapi.cc/opencode-setup.sh`
- `https://dl.laobaiapi.cc/v1/opencode-setup.sh`
- `https://dl.laobaiapi.cc/opencode.template.json`
- `https://dl.laobaiapi.cc/latest.txt`

## 7) 对外安装命令

推荐（先下载再执行）：

```bash
curl -fsSL https://dl.laobaiapi.cc/opencode-setup.sh -o opencode-setup.sh && bash opencode-setup.sh
```

简版：

```bash
curl -fsSL https://dl.laobaiapi.cc/opencode-setup.sh | bash
```

## 8) 常见问题

- 看不到 GitHub 登录按钮：正常，去 Pages 的 `Connect to Git` 做仓库授权。
- 看不到仓库 `deploy`：去 GitHub -> Settings -> Applications -> Installed GitHub Apps 检查 Cloudflare 权限。
- 域名未生效：检查 `dl.laobaiapi.cc` 的 DNS 记录是否已创建并已代理。
