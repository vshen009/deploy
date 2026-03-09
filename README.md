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

## Versioned command

```bash
curl -fsSL https://dl.laobaiapi.cc/v1/opencode-setup.sh | bash
```

```powershell
irm https://dl.laobaiapi.cc/v1/opencode-setup.ps1 | iex
```

## Installer hub page

- https://dl.laobaiapi.cc/

## Config template

- https://dl.laobaiapi.cc/opencode.template.json
- https://dl.laobaiapi.cc/v1/opencode.template.json

## Extra scripts

- `scripts/fix-opencode-clipboard.sh` (Rocky Linux clipboard deps fix)
