<#
  DeepSeek Harness (dsh) on GitHub Codespaces —— 本机一键安装（Windows）

  用法：
    powershell -ExecutionPolicy Bypass -File setup.ps1 -Repo 你的用户名/仓库名
    powershell -ExecutionPolicy Bypass -File setup.ps1            # 已经建好 Codespace 时可以不带参数

  它做这几件事（和云端脚本凑成完整流水线）：
    [1/8] 检查 GitHub CLI（没有就下便携版）
    [2/8] 检查 Codespace（没有就按 -Repo 建一个）
    [3-7/8] 把 install/cloud-setup.sh 送进容器执行（Node / dsh / workspace / deploy key / sync）
    [8/8] 本机验证：建隧道 → 访问 3080 → 放桌面快捷方式 → 报 Installation complete

  参数：
    -Repo owner/name   用哪个仓库当"云端主机"（新电脑上首次需要）
    -Codespace 名字    指定 Codespace（默认自动挑）
    -DryRun            只检查、只打印，不改本机（云端也会用 --dry-run 跑）
    -SkipShortcuts     不创建桌面快捷方式
#>
[CmdletBinding()]
param(
    [string]$Repo,
    [string]$Codespace,
    [switch]$DryRun,
    [switch]$SkipShortcuts
)

$ErrorActionPreference = 'Stop'
$KitVersion = '1.0.0'
$CloudSetupUrl = 'https://raw.githubusercontent.com/Wz2-z/dsh-codespaces-kit/main/install/cloud-setup.sh'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

function Step($n, $text) { Write-Host ''; Write-Host "[$n/8] $text" -ForegroundColor White }
function Ok($t)   { Write-Host "     ✓ $t" -ForegroundColor Green }
function Info($t)  { Write-Host "       $t" -ForegroundColor DarkGray }
function Warn($t)  { Write-Host "     ! $t" -ForegroundColor Yellow }
function Die($t)   { Write-Host "`n✗ $t" -ForegroundColor Red; exit 1 }
function Have($cmd) { return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

Write-Host "DeepSeek Harness · Codespaces 一键安装（本机 Windows）  v$KitVersion" -ForegroundColor White
if ($DryRun) { Write-Host '模式：dry-run（只检查，不改任何东西）' -ForegroundColor Yellow }

$CloudDir = Join-Path $env:LOCALAPPDATA 'dsh-cloud'

# ---------------------------------------------------------------------------
Step 1 '检查 GitHub CLI'
$Gh = Join-Path $CloudDir 'gh\bin\gh.exe'
if (-not (Test-Path $Gh)) {
    $onPath = Get-Command gh -ErrorAction SilentlyContinue
    if ($onPath) { $Gh = $onPath.Source; Ok "用系统里的 gh：$Gh" }
    elseif ($DryRun) { Warn "没装 gh，也没下过便携版（dry-run 不下载）" }
    else {
        Info '下载便携版 GitHub CLI 到 %LOCALAPPDATA%\dsh-cloud（不需要管理员权限）'
        New-Item -ItemType Directory -Force -Path $CloudDir | Out-Null
        $zip = Join-Path $CloudDir 'gh.zip'
        $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/cli/cli/releases/latest' -Headers @{ 'User-Agent' = 'dsh-kit' }
        $asset = $rel.assets | Where-Object { $_.name -like 'gh_*_windows_amd64.zip' } | Select-Object -First 1
        if (-not $asset) { Die '找不到 gh 的 windows_amd64 安装包' }
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -UseBasicParsing
        Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $CloudDir 'gh') -Force
        $Gh = (Get-ChildItem (Join-Path $CloudDir 'gh') -Recurse -Filter gh.exe | Select-Object -First 1).FullName
        if (-not $Gh) { Die '解压后没找到 gh.exe' }
        Ok "装好了：$(& $Gh --version | Select-Object -First 1)"
    }
}
else { Ok "已经装好：$(& $Gh --version | Select-Object -First 1)" }

if (Test-Path $Gh) {
    & $Gh auth status *> $null
    if ($LASTEXITCODE -ne 0) {
        if ($DryRun) { Warn '还没登录 gh（dry-run 不发起登录）' }
        else {
            Info '需要一次浏览器授权：屏幕上的验证码 → https://github.com/login/device'
            & $Gh auth login --hostname github.com --git-protocol https --web --scopes codespace,repo,read:org,workflow
            if ($LASTEXITCODE -ne 0) { Die 'gh auth login 没成功，再跑一次本脚本即可' }
        }
    }
    else { Ok '已经登录过 gh' }
}

# ---------------------------------------------------------------------------
Step 2 '检查 Codespace'
$Cs = $Codespace
if (Test-Path $Gh -and -not $Cs) {
    $list = @()
    try { $list = & $Gh codespace list --json name,state,displayName,repository 2>$null | ConvertFrom-Json } catch {}
    $pick = $null
    if ($Repo) {
        $pick = $list | Where-Object {
            $r = $_.repository
            if ($r -is [string]) { $r -eq $Repo } else { $r.nameWithOwner -eq $Repo }
        } | Select-Object -First 1
    }
    if (-not $pick) { $pick = $list | Select-Object -First 1 }
    if ($pick) { $Cs = $pick.name; Ok "用这个 Codespace：$Cs（$($pick.state)）" }
}
if (-not $Cs -and $Repo -and (Test-Path $Gh)) {
    if ($DryRun) { Warn "没有 Codespace，dry-run 不创建（会执行 gh codespace create -R $Repo）" }
    else {
        Info "没有可用的 Codespace，按 $Repo 新建一个（2 核 / East US / 闲置 240 分钟）"
        $Cs = (& $Gh codespace create -R $Repo -m basicLinux32gb -l EastUs --idle-timeout 240m 2>&1 | Select-Object -Last 1)
        if (-not $Cs) { Die '创建 Codespace 失败（仓库名对不对？免费额度还在吗？）' }
        Ok "建好了：$Cs"
    }
}
if (-not $Cs) { Warn '没有可用的 Codespace：加 -Repo 你的用户名/仓库名 再跑一次' }

# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '[3-7/8] 交给云端：Node → dsh → workspace → deploy key → 自动同步' -ForegroundColor White
if ($Cs -and (Test-Path $Gh)) {
    $tmp = Join-Path $env:TEMP 'dsh-cloud-setup.sh'
    if (Test-Path (Join-Path $PSScriptRoot 'cloud-setup.sh')) {
        Copy-Item (Join-Path $PSScriptRoot 'cloud-setup.sh') $tmp -Force
        Info "用本地这份 cloud-setup.sh"
    }
    elseif ($DryRun) { Warn 'dry-run 且本地没有 cloud-setup.sh，跳过云端步骤' }
    else { Invoke-WebRequest -Uri $CloudSetupUrl -OutFile $tmp -UseBasicParsing }

    if (Test-Path $tmp) {
        $remote = '/tmp/dsh-cloud-setup.sh'
        $dryFlag = if ($DryRun) { ' --dry-run' } else { '' }
        try {
            & $Gh codespace cp -e -c $Cs $tmp "remote:$remote"
            if ($LASTEXITCODE -ne 0) {
                Warn '上传脚本失败，改成让容器自己下载'
                $remoteCmd = "curl -fsSL $CloudSetupUrl -o $remote && bash $remote$dryFlag"
            }
            else { $remoteCmd = "bash $remote$dryFlag" }
            & $Gh codespace ssh -c $Cs -- $remoteCmd
            if ($LASTEXITCODE -ne 0) { Warn '云端脚本返回非 0：把上面的输出贴给 AI 继续修' }
        }
        catch { Warn "云端步骤出错：$($_.Exception.Message)" }
    }
}
else { Warn '没有 Codespace，跳过云端步骤' }

# ---------------------------------------------------------------------------
Step 8 '本机验证 + 桌面快捷方式'
function New-Launcher([string]$name, [string]$cloudScript, [string]$title) {
    # .bat 内容保持纯 ASCII，避免中文被写成 ????
    $body = @"
@echo off
setlocal
set "GH=%LOCALAPPDATA%\dsh-cloud\gh\bin\gh.exe"
set "CS=$Cs"
set "CLOUD=/workspaces/$Repo/.dsh-cloud"
set "LOG=%LOCALAPPDATA%\dsh-cloud\$($name -replace '[^A-Za-z0-9]', '-')-log.txt"
echo $title
"%GH%" codespace ssh -c "%CS%" -- "bash %CLOUD%/$cloudScript" >"%LOG%" 2>&1
for /f "delims=" %%u in ('findstr /r "^http" "%LOG%"') do set "URL=%%u"
start "dsh tunnel" /min cmd /c ""%GH%" codespace ports forward 3080:3080 -c "%CS%""
timeout /t 3 /nobreak >nul
if defined URL (start "" "%URL%") else (echo Could not read URL - see "%LOG%")
endlocal
"@
    $path = Join-Path $CloudDir "$name.bat"
    if ($DryRun) { Info "(dry-run) 会写 $path" }
    else { Set-Content -LiteralPath $path -Value $body -Encoding ASCII }
    return $path
}

if (-not $DryRun) {
    New-Item -ItemType Directory -Force -Path $CloudDir | Out-Null
    $startBat = New-Launcher 'start-dsh'  'start.sh'  'Starting cloud dsh...'
    $updBat   = New-Launcher 'update-dsh' 'update.sh' 'Updating cloud dsh...'
    Ok "启动脚本：$startBat"
    Ok "更新脚本：$updBat"

    if (-not $SkipShortcuts) {
        $desktop = [Environment]::GetFolderPath('Desktop')
        $ws = New-Object -ComObject WScript.Shell
        foreach ($pair in @(@('DeepSeek Harness', $startBat), @('更新 dsh', $updBat))) {
            $lnk = $ws.CreateShortcut((Join-Path $desktop "$($pair[0]).lnk"))
            $lnk.TargetPath = $pair[1]
            $lnk.WorkingDirectory = $CloudDir
            $lnk.Description = 'DeepSeek Harness on GitHub Codespaces'
            $lnk.Save()
        }
        Ok "桌面快捷方式：DeepSeek Harness / 更新 dsh"
    }
}
else { Info '(dry-run) 跳过：写启动脚本、建桌面快捷方式' }

if ($Cs -and (Test-Path $Gh) -and -not $DryRun) {
    Info '建隧道并试着访问 127.0.0.1:3080'
    $tunnel = Start-Process -FilePath $Gh -ArgumentList @('codespace', 'ports', 'forward', '3080:3080', '-c', $Cs) -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds 6
    $code = 0
    try { $code = [int](Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:3080/' -TimeoutSec 8).StatusCode }
    catch { try { $code = [int]$_.Exception.Response.StatusCode } catch { $code = 0 } }
    if ($code -eq 401) { Ok '隧道通了：3080 返回 401（说明需要 token，正常）' }
    elseif ($code -eq 200) { Ok '隧道通了：3080 返回 200' }
    else { Warn "隧道暂时没通（返回 $code）：稍后双击桌面「DeepSeek Harness」再看，或让 AI 排查" }
    if ($tunnel -and -not $tunnel.HasExited) { Stop-Process -Id $tunnel.Id -Force -ErrorAction SilentlyContinue }
}

Write-Host ''
Write-Host ' ✅ Installation complete ' -BackgroundColor Green -ForegroundColor Black
Write-Host ''
Write-Host "dsh-codespaces-kit v$KitVersion"
Write-Host "以后启动：双击桌面「DeepSeek Harness」（使用期间别关那个最小化的 dsh tunnel 窗口）"
Write-Host "升级 dsh：双击桌面「更新 dsh」"
Write-Host "看额度：https://github.com/settings/billing  ·  省额度：https://github.com/codespaces 点 Stop"
Write-Host ''
