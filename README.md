# deploy

这个仓库现在按“**Cloudflare Pages 静态分发**”来收口，当前线上有效内容以 `public/` 为准。

## 当前保留内容

- `public/`：站点实际对外发布文件
- `archive/non-public-20260319/`：从仓库根目录迁移出去的历史辅助文件
- `archive/non-public-20260319.tar.gz`：对应压缩包备份

## 这次整理做了什么

2026-03-19 这次整理中，已将 `public/` 之外原先散落在根目录的辅助内容统一归档，包括：

- `OpenClaw/`
- `docs/`
- `scripts/`
- `push_deploy.sh`
- 旧版根目录 `README.md`（已保存为 `archive/non-public-20260319/README.pre-archive.md`）

这些文件**暂时不删除**，先保留在 `archive/` 里观察一段时间；确认完全不再需要后，再做下一轮清理。

## 部署说明

Cloudflare Pages 继续使用：

- Build output directory: `public`
- 其余非 `public/` 内容不参与当前静态站点输出

## 常用访问链接

- 站点首页：`https://dl.laobaiapi.cc/`
- OpenClaw 安装脚本：`https://dl.laobaiapi.cc/openclaw-setup.sh`
- OpenCode 安装脚本：`https://dl.laobaiapi.cc/opencode-setup.sh`
- Codex 安装脚本：`https://dl.laobaiapi.cc/codex-setup.sh`
- OpenCode 模板：`https://dl.laobaiapi.cc/opencode.template.json`

## 说明

如果后续发现 `archive/` 中仍有文件需要回流到主目录，再按实际使用情况恢复，不做教条化硬删。