@echo off
chcp 65001 >nul
echo Laobai API - Codex CLI One-Click Setup
echo.

if not exist "%userprofile%\.codex" mkdir "%userprofile%\.codex"

if exist "%userprofile%\.codex\config.toml" (
  copy "%userprofile%\.codex\config.toml" "%userprofile%\.codex\config.toml.bak" >nul
  echo Backed up config.toml to config.toml.bak
  echo NOTE: Your projects/mcp_servers/skills settings are in config.toml.bak
  echo       Please manually merge them back if needed.
)
if exist "%userprofile%\.codex\auth.json" (
  copy "%userprofile%\.codex\auth.json" "%userprofile%\.codex\auth.json.bak" >nul
  echo Backed up auth.json to auth.json.bak
)

(
echo model_provider = "laobai"
echo model = "gpt-5.4"
echo model_reasoning_effort = "high"
echo network_access = "enabled"
echo disable_response_storage = true
echo windows_wsl_setup_acknowledged = true
echo model_verbosity = "high"
echo.
echo [model_providers.laobai]
echo name = "laobai"
echo base_url = "https://laobaiapi.cc"
echo wire_api = "responses"
echo requires_openai_auth = true
) > "%userprofile%\.codex\config.toml"

set "API_KEY=%LAOBAI_API_KEY%"
if "%API_KEY%"=="" (
  set /p API_KEY=Please input laobai API Key: 
)

rem Sanitize pasted key (remove CR/LF and surrounding spaces)
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "$k=$env:API_KEY; if($null -eq $k){''} else {(($k -replace "`r|`n","").Trim())}"`) do set "API_KEY=%%A"

if "%API_KEY%"=="" (
  echo.
  echo ERROR: API Key cannot be empty.
  pause
  exit /b 1
)

(
echo {
echo   "OPENAI_API_KEY": "%API_KEY%"
echo }
) > "%userprofile%\.codex\auth.json"

echo.
echo Done! Codex CLI is ready.
pause
