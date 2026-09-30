<#
  dsh-codespaces uninstall —— 卸载 / 撤销（Windows 本机）

  默认**只预览**，什么也不改。要真删必须加 -Yes，并且用开关指定范围：

    -Local          删桌面快捷方式（启动 / 管理台）
    -PurgeLocal     再删本机便携版 gh + SSH 私钥（-Local 的一部分）
    -Cloud          停云端：同步守护进程 + dsh web
    -PurgeCloud     再删 /workspaces/<repo>/.dsh-cloud（脚本与 sync.conf）
    -RevokeDeployKey  从仓库撤销 deploy key（需要个人令牌；平台令牌通常没权限）
    -DeleteCodespace  删除整个 Codespace（不可恢复！）

  它**不会**动：你的 GitHub 登录（要退自己 gh auth logout）、仓库里的内容、
  dsh 的对话历史（除非你删 Codespace）、DeepSeek 的 API Key（在容器里，随 Codespace 消失）。
#>
[CmdletBinding()]
param(
    [switch]$Yes,
    [switch]$Local,
    [switch]$PurgeLocal,
    [switch]$Cloud,
    [switch]$PurgeCloud,
    [switch]$RevokeDeployKey,
    [switch]$DeleteCodespace,
    [string]$Repo,
    [string]$Codespace,
    [string]$Key,
    [string]$Base,
    [string]$Gh,
    [string]$GhConfig
)
$ErrorActionPreference = 'Continue'
$KitVersion = '1.5.1'
$CloudUninstallUrl = 'https://raw.githubusercontent.com/Wz2-z/dsh-codespaces-kit/main/install/cloud-uninstall.sh'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
try { $OutputEncoding = [Text.Encoding]::UTF8 } catch {}

function Test-Exists([string]$path) {
    try { return [bool](Test-Path -LiteralPath $path -ErrorAction Stop) } catch { return $false }
}

if ($Base) {
    if (-not $Gh) { $Gh = Join-Path $Base 'gh\bin\gh.exe' }
    if (-not $GhConfig) {
        $candidate = Join-Path $Base 'ghconfig'
        if (Test-Exists $candidate) { $GhConfig = $candidate }
    }
}
if (-not $GhConfig) { $GhConfig = $env:GH_CONFIG_DIR }
if ($GhConfig) { $env:GH_CONFIG_DIR = $GhConfig }
if (-not $Key) { $Key = Join-Path $env:USERPROFILE '.ssh\dsh_cs_key' }
if (-not $Gh) {
    $candidate = Join-Path $env:LOCALAPPDATA 'dsh-cloud\gh\bin\gh.exe'
    if (Test-Exists $candidate) { $Gh = $candidate }
}
if (-not $Gh) {
    $onPath = Get-Command gh -ErrorAction SilentlyContinue
    if ($onPath) { $Gh = $onPath.Source }
}
if (-not $Codespace -and (Test-Exists $Gh)) {
    $list = @()
    try { $list = & $Gh codespace list --json name,state,repository 2>$null | ConvertFrom-Json } catch {}
    if ($Repo) {
        $Codespace = ($list | Where-Object {
            $r = $_.repository
            if ($r -is [string]) { $r -eq $Repo } else { $r.nameWithOwner -eq $Repo }
        } | Select-Object -First 1).name
    }
    if (-not $Codespace) { $Codespace = ($list | Select-Object -First 1).name }
}

$desktop = [Environment]::GetFolderPath('Desktop')
$shortcuts = @()
foreach ($name in @('DeepSeek Harness', 'dsh 管理台', '更新 dsh', 'dsh 同步', 'dsh 体检')) {
    $p = Join-Path $desktop "$name.lnk"
    if (Test-Exists $p) { $shortcuts += $p }
}

Write-Host ''
Write-Host "dsh-codespaces uninstall  v$KitVersion" -ForegroundColor White
Write-Host ''
Write-Host '会处理的：' -ForegroundColor Cyan
if ($Local) {
    Write-Host "  · 删桌面快捷方式：$($shortcuts.Count) 个"
    foreach ($s in $shortcuts) { Write-Host "      $s" -ForegroundColor DarkGray }
    if ($PurgeLocal) {
        Write-Host "  · 删本机便携版 gh 与 SSH 密钥："
        Write-Host "      $(Join-Path $env:LOCALAPPDATA 'dsh-cloud')" -ForegroundColor DarkGray
        Write-Host "      $Key / $Key.pub" -ForegroundColor DarkGray
    }
} else {
    Write-Host '  · 本机：跳过（没有 -Local）' -ForegroundColor DarkGray
}

if ($Cloud) {
    Write-Host "  · 云端：停同步守护进程、停 dsh web $(if ($PurgeCloud) { '、删 .dsh-cloud 目录' })"
    if ($RevokeDeployKey) { Write-Host '  · 撤销仓库里的 deploy key（dsh-cloud-autosync）' }
    if ($DeleteCodespace) { Write-Host "  · 删除 Codespace $Codespace（不可恢复）" -ForegroundColor Red }
} else {
    Write-Host '  · 云端：跳过（没有 -Cloud）' -ForegroundColor DarkGray
}

Write-Host ''
Write-Host '不会动的（要自己决定）：' -ForegroundColor Cyan
Write-Host '  · GitHub 登录（gh auth logout -h github.com）'
Write-Host '  · 仓库里的内容（那是你的成果）'
Write-Host '  · DeepSeek API Key（在容器 ~/.dsh 里，删 Codespace 就没了）'
Write-Host '  · GitHub 上的 Codespaces 记录（除非 -DeleteCodespace）'

if (-not $Yes) {
    Write-Host ''
    Write-Host '（这是预览。要真的执行：加 -Yes，并用 -Local / -Cloud 等指定范围）' -ForegroundColor Yellow
    Write-Host ''
    exit 0
}

Write-Host ''
if ($Local) {
    foreach ($s in $shortcuts) {
        try { Remove-Item -LiteralPath $s -Force -ErrorAction Stop; Write-Host "  ✓ 已删 $s" }
        catch { Write-Host "  ✗ 删不掉 $s：$($_.Exception.Message)" -ForegroundColor Red }
    }
    if ($PurgeLocal) {
        foreach ($t in @((Join-Path $env:LOCALAPPDATA 'dsh-cloud'), "$Key", "$Key.pub")) {
            if (Test-Exists $t) {
                try { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction Stop; Write-Host "  ✓ 已删 $t" }
                catch { Write-Host "  ✗ 删不掉 $t：$($_.Exception.Message)" -ForegroundColor Red }
            }
        }
    }
}

if ($Cloud -and $Codespace -and (Test-Exists $Gh) -and (Test-Exists $Key)) {
    $script = Join-Path $PSScriptRoot 'cloud-uninstall.sh'
    $tmp = Join-Path $env:TEMP 'cloud-uninstall.sh'
    $have = $false
    if (Test-Exists $script) { Copy-Item $script $tmp -Force; $have = $true }
    else {
        try { Invoke-WebRequest -Uri $CloudUninstallUrl -OutFile $tmp -UseBasicParsing; $have = $true } catch {}
    }
    if ($have) {
        $flags = @('--yes')
        if ($PurgeCloud) { $flags += '--remove-files' }
        if ($RevokeDeployKey) { $flags += '--revoke-deploy-key' }
        if ($DeleteCodespace) { $flags += '--delete-codespace' }
        $remote = "bash -s - $($flags -join ' ')"
        $cmdLine = "`"$Gh`" codespace ssh -c $Codespace -- -i `"$Key`" `"$remote`" < `"$tmp`""
        $out = cmd /c $cmdLine 2>&1
        foreach ($line in $out) { Write-Host "  $line" }
    } else {
        Write-Host '  ✗ 拿不到 cloud-uninstall.sh' -ForegroundColor Red
    }
}

Write-Host ''
Write-Host '完成。剩下的手动步骤（如果有）：' -ForegroundColor Cyan
Write-Host '  · 想退出 GitHub 登录：gh auth logout -h github.com'
Write-Host '  · 想删 Codespace：https://github.com/codespaces'
Write-Host '  · 想删 Deploy key：仓库 Settings → Deploy keys'
Write-Host ''
