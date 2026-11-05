# 學園好食 motion 工具：一鍵檢查＆安裝（Windows）
# 請雙擊「一鍵安裝_Windows.bat」，它會呼叫這個檔案。
# 會先檢查全部，列出缺什麼，問過你之後才安裝。
# 只檢查不安裝：一鍵安裝_Windows.bat --check
param([string]$Mode = 'install')

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Set-Location -LiteralPath $PSScriptRoot
$CheckOnly = $Mode -eq 'check'

# 開放授權字型：思源黑體（全部頁面）、思源宋體（剪貼字卡）、jf open 粉圓（撕紙條、剪貼字卡）
$Fonts = @(
  @{ Name = 'Noto Sans TC 字型'; File = 'NotoSansTC-VariableFont_wght.ttf'; Match = 'NotoSansTC*';
     Url = 'https://github.com/google/fonts/raw/main/ofl/notosanstc/NotoSansTC%5Bwght%5D.ttf' },
  @{ Name = 'Noto Serif TC 字型'; File = 'NotoSerifTC-VariableFont_wght.ttf'; Match = 'NotoSerifTC*';
     Url = 'https://github.com/google/fonts/raw/main/ofl/notoseriftc/NotoSerifTC%5Bwght%5D.ttf' },
  @{ Name = 'jf open 粉圓 字型'; File = 'jf-openhuninn-2.1.ttf'; Match = 'jf-openhuninn*';
     Url = 'https://github.com/justfont/open-huninn-font/releases/download/v2.1/jf-openhuninn-2.1.ttf' }
)
$UserFontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'

function Ok($t)  { Write-Host "  ✔ $t" -ForegroundColor Green }
function Bad($t) { Write-Host "  ✘ $t" -ForegroundColor Red }

# 剛用 winget 裝好的工具，要重新讀一次 PATH 才找得到
function Refresh-Path {
  $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
  $u = [Environment]::GetEnvironmentVariable('PYTHON', 'User')
  if ($u) { $env:PYTHON = $u }
}
function Has($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

# 找真的 Python（Windows 內建的 python 指令可能只是「到 Microsoft Store 下載」的捷徑）
function Find-Python {
  if ($env:PYTHON -and (Test-Path -LiteralPath $env:PYTHON)) { return $env:PYTHON }
  foreach ($c in 'py', 'python', 'python3') {
    if (-not (Has $c)) { continue }
    $rest = if ($c -eq 'py') { @('-3') } else { @() }
    try {
      $p = & $c @rest -c "import sys; print(sys.executable)" 2>$null
      if ($LASTEXITCODE -eq 0 -and $p -and (Test-Path -LiteralPath "$p".Trim())) { return "$p".Trim() }
    } catch {}
  }
  # winget 裝的 Python 預設在使用者資料夾，PATH 還沒更新時也找得到
  $local = Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python3*\python.exe') -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
  if ($local) { return $local.FullName }
  return $null
}

function Has-Font($f) {
  foreach ($d in @($UserFontDir, (Join-Path $env:WINDIR 'Fonts'))) {
    if (Test-Path -LiteralPath $d) {
      if (Get-ChildItem -LiteralPath $d -Filter $f.Match -ErrorAction SilentlyContinue) { return $true }
    }
  }
  return $false
}

# 只裝給目前這個使用者，不需要系統管理員權限
function Install-Font($f) {
  New-Item -ItemType Directory -Force -Path $UserFontDir | Out-Null
  $dest = Join-Path $UserFontDir $f.File
  Invoke-WebRequest -Uri $f.Url -OutFile $dest -UseBasicParsing
  $reg = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
  if (-not (Test-Path $reg)) { New-Item -Path $reg -Force | Out-Null }
  New-ItemProperty -Path $reg -Name ([IO.Path]::GetFileNameWithoutExtension($f.File) + ' (TrueType)') -Value $dest -PropertyType String -Force | Out-Null
}

function Winget-Install($id, $label) {
  Write-Host ""; Write-Host "▶ 安裝 $label"
  winget install --id $id -e --silent --accept-source-agreements --accept-package-agreements
  Refresh-Path
}

function Check-All {
  $script:Missing = @()
  Write-Host ""; Write-Host "檢查中…"
  Refresh-Path
  if (Has 'winget') { Ok 'winget（用來安裝其他工具）' } else { Bad 'winget（用來安裝其他工具）'; $script:Missing += 'winget' }
  if (Has 'node') { Ok "Node.js $(node -v)" } else { Bad 'Node.js'; $script:Missing += 'node' }
  if ((Has 'ffmpeg') -and ((ffmpeg -hide_banner -encoders 2>$null) -match 'prores_ks')) { Ok 'ffmpeg' } else { Bad 'ffmpeg'; $script:Missing += 'ffmpeg' }
  $py = Find-Python
  if ($py) {
    Ok "Python（$py）"
    & $py -c "import numpy" 2>$null
    if ($LASTEXITCODE -eq 0) { Ok 'numpy' } else { Bad 'numpy（音效用）'; $script:Missing += 'numpy' }
  } else {
    Bad 'Python 3'; $script:Missing += 'python', 'numpy'
  }
  foreach ($f in $Fonts) { if (Has-Font $f) { Ok $f.Name } else { Bad $f.Name; $script:Missing += 'font' } }
  if (Test-Path -LiteralPath 'node_modules\playwright-core') { Ok '輸出工具（playwright-core）' } else { Bad '輸出工具（playwright-core）'; $script:Missing += 'npm' }
  # render.mjs --check：0 = 都正常，2 = 瀏覽器可以但字型找不到，其他 = 瀏覽器開不起來
  $code = 1
  if ((Has 'node') -and (Test-Path -LiteralPath 'node_modules\playwright-core')) { node render.mjs --check *> $null; $code = $LASTEXITCODE }
  if ($code -eq 0 -or $code -eq 2) { Ok '瀏覽器' } else { Bad '瀏覽器（或還不能測試）'; $script:Missing += 'browser' }
  $script:Missing = @($script:Missing | Select-Object -Unique)
}
function Need($k) { $script:Missing -contains $k }

function Install-Missing {
  if (Need 'winget') {
    Write-Host ""
    Write-Host "這台電腦沒有 winget。請打開 Microsoft Store，搜尋「應用程式安裝程式」（App Installer）並更新或安裝，裝好後再執行一次。"
    return
  }
  if (Need 'node')   { Winget-Install 'OpenJS.NodeJS.LTS' 'Node.js' }
  if (Need 'ffmpeg') { Winget-Install 'Gyan.FFmpeg' 'ffmpeg' }
  if (Need 'python') { Winget-Install 'Python.Python.3.13' 'Python' }
  $py = Find-Python
  if ($py) {
    # render.mjs 會先看 PYTHON 這個環境變數，記下真的 Python 位置，避免叫到 Store 的捷徑
    [Environment]::SetEnvironmentVariable('PYTHON', $py, 'User'); $env:PYTHON = $py
    if (Need 'numpy') { Write-Host ""; Write-Host "▶ 安裝 numpy"; & $py -m pip install --user numpy }
  } elseif (Need 'numpy') {
    Write-Host "找不到 Python，numpy 先跳過。"
  }
  foreach ($f in $Fonts) {
    if (-not (Has-Font $f)) {
      Write-Host ""; Write-Host "▶ 下載 $($f.Name)（開放授權）"
      try { Install-Font $f } catch { Write-Host "下載失敗：$($_.Exception.Message)" }
    }
  }
  if ((Need 'npm') -or (Need 'node')) {
    Write-Host ""; Write-Host "▶ 安裝輸出工具（npm install）"
    npm.cmd install
  }
  if (Has 'node') {
    node render.mjs --check *> $null
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 2) {
      Write-Host ""; Write-Host "▶ 下載輸出用的瀏覽器"
      npx.cmd playwright-core install chromium
    }
  }
}

Write-Host "=== 學園好食 motion 工具：環境檢查（Windows）==="
Check-All

if ($script:Missing.Count -eq 0) {
  Write-Host ""; Write-Host "全部都準備好了，可以直接用 node render.mjs 輸出。"
  exit 0
}
if ($CheckOnly) {
  Write-Host ""; Write-Host "有 $($script:Missing.Count) 類還沒準備好。"
  exit 1
}

Write-Host ""
$ans = Read-Host "要現在安裝缺少的項目嗎？會用 winget 安裝並同意各軟體的授權條款 (y/n)"
if ($ans -ne 'y' -and $ans -ne 'Y') { Write-Host "沒有安裝任何東西。"; exit 1 }

Install-Missing
Write-Host ""; Write-Host "=== 安裝完成，再檢查一次 ==="
Check-All
Write-Host ""
if ($script:Missing.Count -eq 0) {
  Write-Host "全部都準備好了！"
  Write-Host "（剛裝好的字型和工具，如果已經開著的終端機或剪輯軟體找不到，關掉重開就好）"
} else {
  Write-Host "還有 $($script:Missing.Count) 類沒成功，請把上面的畫面截圖給協助你的人看。"
  Write-Host "有時候只是要重新開機，或關掉這個視窗再雙擊一次。"
}
