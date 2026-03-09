param(
  [switch]$Install,
  [switch]$Configure,
  [switch]$OneClick,
  [string]$ApiKey,
  [switch]$Help
)

$ErrorActionPreference = "Stop"

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
    Write-Yellow "npm not found. Trying to install Node.js LTS via winget..."
    winget install --id OpenJS.NodeJS.LTS -e --silent --accept-package-agreements --accept-source-agreements
    Refresh-Path
  }

  if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    throw "npm not found. Please install Node.js first: https://nodejs.org/"
  }
}

function Resolve-InstallCommand {
  if (Get-Command npm -ErrorAction SilentlyContinue) {
    return "npm install -g opencode"
  }
  if (Get-Command pnpm -ErrorAction SilentlyContinue) {
    return "pnpm add -g opencode"
  }
  return $null
}

function Install-OpenCode {
  if (Get-Command opencode -ErrorAction SilentlyContinue) {
    Write-Green "opencode is already installed: $((Get-Command opencode).Source)"
    try { opencode --version | Out-Host } catch {}
    return
  }

  Ensure-Node
  $cmd = Resolve-InstallCommand
  if (-not $cmd) {
    throw "No supported install command found (npm / pnpm)."
  }

  Write-Yellow "Installing opencode..."
  Write-Yellow "Running command: $cmd"
  Invoke-Expression $cmd

  Refresh-Path
  if (Get-Command opencode -ErrorAction SilentlyContinue) {
    Write-Green "Install succeeded: $((Get-Command opencode).Source)"
    try { opencode --version | Out-Host } catch {}
  } else {
    throw "Install command completed, but opencode command is still unavailable."
  }
}

function Save-ApiKey([string]$Key) {
  if ([string]::IsNullOrWhiteSpace($Key)) {
    throw "API Key cannot be empty."
  }

  $configDir = Join-Path $env:APPDATA "opencode"
  $configFile = Join-Path $configDir "opencode.json"

  New-Item -ItemType Directory -Path $configDir -Force | Out-Null

  if (Test-Path $configFile) {
    $bak = "$configFile.bak.$(Get-Date -Format yyyyMMddHHmmss)"
    Copy-Item $configFile $bak -Force
    Write-Yellow "Backed up previous config: $bak"
  }

  $json = $null
  if (Test-Path $configFile) {
    try {
      $json = Get-Content $configFile -Raw | ConvertFrom-Json
    } catch {
      $json = $null
    }
  }

  if (-not $json) {
    $json = [pscustomobject]@{}
  }
  if (-not $json.provider) {
    $json | Add-Member -NotePropertyName provider -NotePropertyValue ([pscustomobject]@{}) -Force
  }
  if (-not $json.provider.openai) {
    $json.provider | Add-Member -NotePropertyName openai -NotePropertyValue ([pscustomobject]@{}) -Force
  }
  if (-not $json.provider.openai.options) {
    $json.provider.openai | Add-Member -NotePropertyName options -NotePropertyValue ([pscustomobject]@{}) -Force
  }

  $json.provider.openai.options.apiKey = $Key
  $json | ConvertTo-Json -Depth 100 | Set-Content -Path $configFile -Encoding UTF8

  Write-Green "API Key saved to: $configFile"
}

function Configure-ApiKey {
  $key = $ApiKey
  if ([string]::IsNullOrWhiteSpace($key)) {
    $secure = Read-Host "Enter API Key (hidden)" -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
      $key = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
      [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
  }

  Save-ApiKey -Key $key
}

function Show-Help {
@"
Usage:
  powershell -ExecutionPolicy Bypass -File .\opencode-setup.ps1
  powershell -ExecutionPolicy Bypass -File .\opencode-setup.ps1 -Install
  powershell -ExecutionPolicy Bypass -File .\opencode-setup.ps1 -Configure -ApiKey 'sk-xxx'
  powershell -ExecutionPolicy Bypass -File .\opencode-setup.ps1 -OneClick -ApiKey 'sk-xxx'
"@ | Write-Host
}

function Show-Menu {
  while ($true) {
    Write-Host ""
    Write-Host "========== OpenCode One-Click Script (Windows) =========="
    Write-Host "1) Install opencode"
    Write-Host "2) Configure API Key"
    Write-Host "3) One-click (Install + Configure)"
    Write-Host "0) Exit"
    $choice = Read-Host "Choose [0-3]"

    switch ($choice) {
      "1" { Install-OpenCode }
      "2" { Configure-ApiKey }
      "3" { Install-OpenCode; Configure-ApiKey }
      "0" { return }
      default { Write-Red "Invalid option. Please try again." }
    }
  }
}

if ($Help) {
  Show-Help
  exit 0
}

if ($OneClick) {
  Install-OpenCode
  Configure-ApiKey
  exit 0
}

if ($Install) {
  Install-OpenCode
  exit 0
}

if ($Configure) {
  Configure-ApiKey
  exit 0
}

Show-Menu
