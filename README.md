# opencode-installer

Cloudflare Pages static files for one-command OpenCode setup.

## User command

```bash
curl -fsSL https://dl.laobaiapi.cc/opencode-setup.sh | bash
```

## Windows command

```powershell
irm https://dl.laobaiapi.cc/opencode-setup.ps1 | iex
```

## Non-interactive one-click

```bash
curl -fsSL https://dl.laobaiapi.cc/opencode-setup.sh | OPENCODE_API_KEY='sk-xxx' bash -s -- --one-click
```

## Installer hub page

- https://dl.laobaiapi.cc/

## Codex command (Linux/macOS)

```bash
curl -fsSL https://dl.laobaiapi.cc/codex-setup.sh | bash
```


## Codex command (Windows CMD/PowerShell)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr https://dl.laobaiapi.cc/codex-setup.bat -OutFile $env:TEMP\codex-setup.bat; cmd /c $env:TEMP\codex-setup.bat"
```


## Config template

- https://dl.laobaiapi.cc/opencode.template.json

## Extra scripts

- `scripts/fix-opencode-clipboard.sh` (Rocky Linux clipboard deps fix)
