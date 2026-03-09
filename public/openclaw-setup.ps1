param(
  [ValidateSet("fresh", "inject", "menu")]
  [string]$Mode = "menu",
  [string]$ApiKey,
  [switch]$Help
)

$ErrorActionPreference = "Stop"

$ConfigDir = Join-Path $HOME ".openclaw"
$ConfigPath = Join-Path $ConfigDir "openclaw.json"

function Write-Green([string]$Msg) { Write-Host $Msg -ForegroundColor Green }
function Write-Yellow([string]$Msg) { Write-Host $Msg -ForegroundColor Yellow }
function Write-Red([string]$Msg) { Write-Host $Msg -ForegroundColor Red }

function Refresh-Path {
  $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
  $user = [Environment]::GetEnvironmentVariable("Path", "User")
  $env:Path = "$machine;$user"
}

function Ensure-Node {
  if (Get-Command npm -ErrorAction SilentlyContinue) {
    return
  }

  if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Yellow "未检测到 npm，尝试通过 winget 安装 Node.js LTS..."
    winget install --id OpenJS.NodeJS.LTS -e --silent --accept-package-agreements --accept-source-agreements
    Refresh-Path
  }

  if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    throw "未检测到 npm。请先安装 Node.js（https://nodejs.org/）后重试。"
  }
}

function Ensure-OpenClaw {
  if (Get-Command openclaw -ErrorAction SilentlyContinue) {
    return
  }

  Ensure-Node
  Write-Yellow "开始安装 OpenClaw CLI..."
  npm install -g openclaw
  Refresh-Path

  if (-not (Get-Command openclaw -ErrorAction SilentlyContinue)) {
    throw "安装完成后仍未检测到 openclaw 命令。"
  }
}

function New-Token {
  $bytes = New-Object byte[] 32
  [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
  -join ($bytes | ForEach-Object { $_.ToString("x2") })
}

function Get-KeyMasked([string]$Key) {
  $len = $Key.Length
  if ($len -le 8) {
    if ($len -le 4) {
      return "$($Key.Substring(0,1))****$($Key.Substring($len-1,1))"
    }
    return "$($Key.Substring(0,2))****$($Key.Substring($len-2,2))"
  }
  $head = $Key.Substring(0,4)
  $tail = $Key.Substring($len-4,4)
  $mask = "*" * ($len - 8)
  return "$head$mask$tail"
}

function Prompt-ApiKey {
  if (-not [string]::IsNullOrWhiteSpace($ApiKey)) {
    return $ApiKey
  }

  $secure = Read-Host "请输入 laobai API Key（隐藏）" -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try {
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }

  if ([string]::IsNullOrWhiteSpace($plain)) {
    throw "API Key 不能为空。"
  }

  Write-Host "已接收 API Key（校验展示）：$(Get-KeyMasked $plain)"
  return $plain
}

function Ensure-JsonObject($obj, [string]$name) {
  if (-not $obj.$name) {
    $obj | Add-Member -NotePropertyName $name -NotePropertyValue ([pscustomobject]@{}) -Force
  }
}

function Save-Config($jsonObj) {
  New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
  $jsonObj | ConvertTo-Json -Depth 100 | Set-Content -Path $ConfigPath -Encoding UTF8
}

function Write-FreshConfig([string]$key, [string]$token) {
  $obj = [pscustomobject]@{
    gateway = [pscustomobject]@{
      mode = "local"
      auth = [pscustomobject]@{
        mode = "token"
        token = $token
      }
    }
    agents = [pscustomobject]@{
      defaults = [pscustomobject]@{
        model = [pscustomobject]@{ primary = "laobai/gpt-5.3-codex" }
        models = [pscustomobject]@{
          "laobai/gpt-5.3-codex" = [pscustomobject]@{ alias = "laobai-codex" }
        }
      }
    }
    models = [pscustomobject]@{
      mode = "replace"
      providers = [pscustomobject]@{
        laobai = [pscustomobject]@{
          baseUrl = "https://laobaiapi.cc/v1"
          apiKey = $key
          api = "openai-responses"
          authHeader = $true
          headers = [pscustomobject]@{ "User-Agent" = "PowerShell" }
          models = @(
            [pscustomobject]@{
              id = "gpt-5.3-codex"
              name = "GPT-5.3 Codex (via laobai)"
              api = "openai-responses"
              reasoning = $true
              input = @("text", "image")
              cost = [pscustomobject]@{ input = 0; output = 0; cacheRead = 0; cacheWrite = 0 }
              contextWindow = 204800
              maxTokens = 8192
            }
          )
        }
      }
    }
  }

  Save-Config $obj
}

function Inject-Laobai([string]$key, [string]$token) {
  New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null

  if (Test-Path $ConfigPath) {
    $bak = "$ConfigPath.bak.$(Get-Date -Format yyyyMMdd-HHmmss)"
    Copy-Item $ConfigPath $bak -Force
    Write-Yellow "已备份旧配置：$bak"
    try {
      $obj = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    } catch {
      throw "现有 openclaw.json 不是合法 JSON，无法注入。"
    }
  } else {
    $obj = [pscustomobject]@{}
  }

  Ensure-JsonObject $obj "gateway"
  Ensure-JsonObject $obj.gateway "auth"
  $obj.gateway.mode = "local"
  $obj.gateway.auth.mode = "token"
  if ([string]::IsNullOrWhiteSpace($obj.gateway.auth.token)) {
    $obj.gateway.auth.token = $token
  }

  Ensure-JsonObject $obj "agents"
  Ensure-JsonObject $obj.agents "defaults"
  $obj.agents.defaults.model = [pscustomobject]@{ primary = "laobai/gpt-5.3-codex" }
  if (-not $obj.agents.defaults.models) {
    $obj.agents.defaults | Add-Member -NotePropertyName models -NotePropertyValue ([pscustomobject]@{}) -Force
  }
  $obj.agents.defaults.models."laobai/gpt-5.3-codex" = [pscustomobject]@{ alias = "laobai-codex" }

  Ensure-JsonObject $obj "models"
  $obj.models.mode = "merge"
  if (-not $obj.models.providers) {
    $obj.models | Add-Member -NotePropertyName providers -NotePropertyValue ([pscustomobject]@{}) -Force
  }
  $obj.models.providers.laobai = [pscustomobject]@{
    baseUrl = "https://laobaiapi.cc/v1"
    apiKey = $key
    api = "openai-responses"
    authHeader = $true
    headers = [pscustomobject]@{ "User-Agent" = "PowerShell" }
    models = @(
      [pscustomobject]@{
        id = "gpt-5.3-codex"
        name = "GPT-5.3 Codex (via laobai)"
        api = "openai-responses"
        reasoning = $true
        input = @("text", "image")
        cost = [pscustomobject]@{ input = 0; output = 0; cacheRead = 0; cacheWrite = 0 }
        contextWindow = 204800
        maxTokens = 8192
      }
    )
  }

  Save-Config $obj
}

function Post-Check {
  try { openclaw doctor | Out-Host } catch {}
  try { openclaw gateway start | Out-Host } catch {}
  try { openclaw gateway status | Out-Host } catch {}
  try { openclaw status | Out-Host } catch {}
}

function Show-Help {
@"
用法:
  powershell -ExecutionPolicy Bypass -File .\openclaw-setup.ps1
  powershell -ExecutionPolicy Bypass -File .\openclaw-setup.ps1 -Mode fresh
  powershell -ExecutionPolicy Bypass -File .\openclaw-setup.ps1 -Mode inject
  powershell -ExecutionPolicy Bypass -File .\openclaw-setup.ps1 -Mode fresh -ApiKey 'sk-xxx'
"@ | Write-Host
}

function Run-Fresh {
  Ensure-OpenClaw
  $key = Prompt-ApiKey
  $token = New-Token
  Write-Yellow "==> 生成全新 openclaw.json"
  Write-FreshConfig -key $key -token $token
  Post-Check
  Write-Green "完成：配置文件路径 -> $ConfigPath"
  Write-Green "请保存好 Gateway token：$token"
}

function Run-Inject {
  Ensure-OpenClaw
  $key = Prompt-ApiKey
  $token = New-Token
  Write-Yellow "==> 注入 laobai provider 并切换默认模型"
  Inject-Laobai -key $key -token $token
  Post-Check

  $finalToken = $token
  try {
    $check = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    if ($check.gateway.auth.token) {
      $finalToken = $check.gateway.auth.token
    }
  } catch {}

  Write-Green "完成：配置文件路径 -> $ConfigPath"
  Write-Green "请保存好 Gateway token：$finalToken"
}

if ($Help) {
  Show-Help
  exit 0
}

switch ($Mode) {
  "fresh" { Run-Fresh; exit 0 }
  "inject" { Run-Inject; exit 0 }
  "menu" {
    Write-Host "请选择模式："
    Write-Host "  1) 全新安装 OpenClaw（生成干净单 provider laobai 配置）"
    Write-Host "  2) 已安装 OpenClaw，注入 laobai provider 并切默认模型"
    $choice = Read-Host "输入 1 或 2"
    if ($choice -eq "1") {
      Run-Fresh
      exit 0
    }
    if ($choice -eq "2") {
      Run-Inject
      exit 0
    }
    throw "无效选择，退出。"
  }
}
