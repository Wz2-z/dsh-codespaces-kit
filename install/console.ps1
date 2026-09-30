<#
  dsh-codespaces console — the (bilingual) control panel.

  Double-click the desktop shortcut, or:
    powershell -ExecutionPolicy Bypass -File console.ps1
    powershell -ExecutionPolicy Bypass -File console.ps1 -Action status       # non-interactive
    powershell -ExecutionPolicy Bypass -File console.ps1 -Action preview      # render the menu once
    powershell -ExecutionPolicy Bypass -File console.ps1 -Lang en             # English UI

  Actions: open / status / checkup / sync / update / audit / repair / uninstall / log / preview

  -Base points at the folder that holds gh\bin\gh.exe and ghconfig\ (auto-detected), -Key at the SSH key
  used to reach the Codespace. The chosen language is remembered in .console-lang next to this file.
#>
[CmdletBinding()]
param(
    [string]$Base,
    [string]$Key,
    [string]$Codespace,
    [string]$Action,
    [ValidateSet('zh', 'en', '')][string]$Lang = ''
)
$ErrorActionPreference = 'Continue'
$Version = '1.7.1'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
try { $OutputEncoding = [Text.Encoding]::UTF8 } catch {}

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path

function Test-Exists([string]$path) {
    try { return [bool](Test-Path -LiteralPath $path -ErrorAction Stop) } catch { return $false }
}

# ---------------------------------------------------------------- language
$LangFile = Join-Path $Here '.console-lang'
if (-not $Lang) {
    if (Test-Exists $LangFile) { $Lang = (Get-Content -LiteralPath $LangFile -Raw).Trim() }
}
if ($Lang -notin @('zh', 'en')) { $Lang = 'zh' }

$S = if ($Lang -eq 'en') {
    @{
        title = 'dsh control panel'; codespace = 'codespace'; sync = 'auto sync'; notFound = '(no Codespace found)'
        modePaused = 'paused'; modeOn = 'on'; pending = 'pending'
        open = 'open dsh'; openDesc = 'wake Codespace → start dsh → tunnel → browser'
        status = 'status'; statusDesc = 'one screen: sync / tunnel / pending / last push'
        checkup = 'checkup'; checkupDesc = '12 checks (host + cloud)'
        syncMenu = 'auto sync'; syncMenuDesc = 'state / commit now / pause / mode / fold window'
        update = 'update dsh'; updateDesc = 'upgrade dsh in the cloud and reopen the tunnel'
        audit = 'credentials'; auditDesc = 'which keys/tokens/configs exist and what they can do'
        repair = 'repair'; repairDesc = 're-run the installer (idempotent), then doctor'
        uninstall = 'uninstall'; uninstallDesc = 'preview first, then choose how much to remove'
        log = 'sync log'; logDesc = 'last 25 lines'
        refresh = 'refresh'; refreshDesc = 'fetch the header state again'
        language = 'language'; languageDesc = 'switch between 中文 / English'
        exit = 'exit'; exitDesc = ''
        choose = '  choose'; pressEnter = '  press Enter to go back'; cancelled = '  cancelled.'
        s1 = 'status'; s2 = 'commit now'; s3 = 'pause'; s4 = 'resume'
        s5 = 'mode: idle'; s6 = 'mode: interval'; s7 = 'mode: manual'
        s8 = 'fold window: on'; s9 = 'fold window: off'; s0 = 'back'
        s1d = 'mode / pending / last commit'; s2d = 'sync.sh --now'
        s3d = '--disable'; s4d = '--enable'
        s5d = 'commit after the edits go quiet (default)'; s6d = 'commit every 5 minutes'
        s7d = 'only when you press 2'; s8d = 'fold into the previous commit (30 min)'
        s9d = 'always start a new commit'
        u1 = 'cancel'; u2 = 'stop only'; u3 = 'uninstall'; u4 = 'full clean'
        u1d = 'do nothing'; u2d = 'stop cloud sync + dsh (keep files, shortcuts, keys)'
        u3d = 'delete shortcuts + stop cloud + delete .dsh-cloud'
        u4d = 'also delete portable gh + ssh key on this PC'
        uAskKey = '  also revoke the GitHub deploy key? (y/N)'
        okOpened = '  opened. keep the minimized "dsh tunnel" window open while using dsh.'
        step1 = '  [1/3] checking Codespace state …'; step2 = '  [2/3] starting dsh in the container …'
        step3 = '  [3/3] starting the tunnel and opening the browser …'
        waking = '      waking it up, about one minute …'
        missing = 'missing'; repairRun = '  re-running the cloud installer (idempotent) …'
    }
} else {
    @{
        title = 'dsh 管理台'; codespace = 'codespace'; sync = '自动同步'; notFound = '（没找到 Codespace）'
        modePaused = '已暂停'; modeOn = '同步中'; pending = '待提交'
        open = '打开 dsh'; openDesc = '唤醒 Codespace → 启动 dsh → 隧道 → 浏览器'
        status = '状态'; statusDesc = '一眼看清现在（同步 / 隧道 / 待提交 / 上次推送）'
        checkup = '体检'; checkupDesc = '12 项检查（本机 + 云端）'
        syncMenu = '自动同步'; syncMenuDesc = '状态 / 立即提交 / 暂停 / 模式 / 折叠窗口'
        update = '更新 dsh'; updateDesc = '升级云端 dsh 并重建隧道'
        audit = '权限清单'; auditDesc = '创建了哪些 key/token/config，各自能干什么'
        repair = '修复'; repairDesc = '重跑一遍安装（幂等）再体检'
        uninstall = '卸载'; uninstallDesc = '先预览，再选清到什么程度'
        log = '同步日志'; logDesc = '最近 25 行'
        refresh = '刷新'; refreshDesc = '重新取一次顶部状态'
        language = '语言'; languageDesc = '在 中文 / English 之间切换'
        exit = '退出'; exitDesc = ''
        choose = '  选择'; pressEnter = '  回车返回菜单'; cancelled = '  已取消。'
        s1 = '状态'; s2 = '立即提交'; s3 = '暂停'; s4 = '恢复'
        s5 = '模式 idle'; s6 = '模式 interval'; s7 = '模式 manual'
        s8 = '折叠窗口开'; s9 = '折叠窗口关'; s0 = '返回'
        s1d = '模式 / 待提交 / 最近提交'; s2d = 'sync.sh --now'
        s3d = '--disable'; s4d = '--enable'
        s5d = '静默一会儿再提交（默认）'; s6d = '每 5 分钟提交一次'
        s7d = '只在你按 2 时提交'; s8d = '折进上一条提交（30 分钟）'
        s9d = '每次都新开一条提交'
        u1 = '取消'; u2 = '只停'; u3 = '卸载'; u4 = '彻底清'
        u1d = '什么都不做'; u2d = '停云端同步 + 停 dsh（保留文件、快捷方式、密钥）'
        u3d = '删快捷方式 + 停云端 + 删 .dsh-cloud'
        u4d = '在 3 基础上再删本机便携 gh + SSH 私钥'
        uAskKey = '  顺便撤销 GitHub 上的 deploy key？(y/N)'
        okOpened = '  已打开。使用期间别关那个最小化的 dsh tunnel 窗口。'
        step1 = '  [1/3] 检查 Codespace 状态 …'; step2 = '  [2/3] 在容器里启动 dsh …'
        step3 = '  [3/3] 建隧道并打开浏览器 …'
        waking = '      正在唤醒，约 1 分钟 …'
        missing = '缺少'; repairRun = '  重跑一遍云端安装（幂等：只补缺的）…'
    }
}

# ---------------------------------------------------------------- context
if (-not $Base) {
    foreach ($candidate in @((Join-Path $env:LOCALAPPDATA 'dsh-cloud'), (Join-Path (Split-Path -Parent $Here) 'work\cloud'))) {
        if (Test-Exists (Join-Path $candidate 'gh\bin\gh.exe')) { $Base = $candidate; break }
    }
}
if (-not $Base) { $Base = Join-Path $env:LOCALAPPDATA 'dsh-cloud' }
if (-not $Key) { $Key = Join-Path $env:USERPROFILE '.ssh\dsh_cs_key' }
$Gh = Join-Path $Base 'gh\bin\gh.exe'
$GhConfig = Join-Path $Base 'ghconfig'
$CloudDir = '/workspaces/dsh-box/.dsh-cloud'
if (Test-Exists $GhConfig) { $env:GH_CONFIG_DIR = $GhConfig }

$script:Ctx = @{ Codespace = $Codespace; State = ''; Mode = ''; Enabled = ''; Daemon = ''; Pending = ''; LastPush = '' }

function Get-Remote([string]$command) {
    if (-not (Test-Exists $Gh) -or -not (Test-Exists $Key) -or -not $script:Ctx.Codespace) { return @() }
    $cmdLine = "`"$Gh`" codespace ssh -c $($script:Ctx.Codespace) -- -i `"$Key`" `"$command`""
    return @(cmd /c $cmdLine 2>&1)
}
function Resolve-Codespace {
    if ($script:Ctx.Codespace) { return }
    if (-not (Test-Exists $Gh)) { return }
    $list = @()
    try { $list = & $Gh codespace list --json name,state 2>$null | ConvertFrom-Json } catch {}
    $first = $list | Select-Object -First 1
    if ($first) { $script:Ctx.Codespace = $first.name; $script:Ctx.State = $first.state }
}
function Update-HeaderData {
    Resolve-Codespace
    if (-not $script:Ctx.Codespace) { return }
    foreach ($line in (Get-Remote "bash $CloudDir/sync.sh --status 2>/dev/null | head -2")) {
        if ($line -match '模式：(\S+?)（enabled=(\w+)）') { $script:Ctx.Mode = $matches[1]; $script:Ctx.Enabled = $matches[2] }
    }
    $i = 0
    foreach ($line in (Get-Remote "tail -n 1 ~/dsh-sync.log; echo ---; pgrep -f 'sync[.]sh --daemon' | head -1")) {
        $i++
        if ($i -eq 1 -and $line -match '(\d{4}-\d\d-\d\dT[\d:]+)') { $script:Ctx.LastPush = $matches[1] }
        if ($i -eq 3 -and $line -match '^\d+$') { $script:Ctx.Daemon = $line }
    }
    foreach ($line in (Get-Remote 'cd ~/dsh-workspace 2>/dev/null && git status --porcelain | wc -l')) {
        if ($line -match '^\d+$') { $script:Ctx.Pending = $line }
    }
}
function Age([string]$iso) {
    if (-not $iso) { return '' }
    try {
        $t = [datetime]::Parse($iso, $null, [System.Globalization.DateTimeStyles]::AdjustToUniversal)
        $d = [DateTimeOffset]::UtcNow.UtcDateTime - $t
        if ($Lang -eq 'en') {
            if ($d.TotalMinutes -lt 1) { return 'just now' }
            if ($d.TotalMinutes -lt 60) { return "$([int]$d.TotalMinutes) min ago" }
            if ($d.TotalHours -lt 24) { return "$([int]$d.TotalHours) h ago" }
            return "$([int]$d.TotalDays) d ago"
        }
        if ($d.TotalMinutes -lt 1) { return '刚刚' }
        if ($d.TotalMinutes -lt 60) { return "$([int]$d.TotalMinutes) 分钟前" }
        if ($d.TotalHours -lt 24) { return "$([int]$d.TotalHours) 小时前" }
        return "$([int]$d.TotalDays) 天前"
    } catch { return '' }
}

# ---------------------------------------------------------------- rendering
$W = 62
function Line([string]$text = '', [string]$color = 'Gray') { Write-Host $text -ForegroundColor $color }
function Get-VisualLength([string]$s) {
    $n = 0
    foreach ($ch in $s.ToCharArray()) {
        $code = [int][char]$ch
        if ($code -ge 0x1100 -and ($code -le 0x115F -or ($code -ge 0x2E80 -and $code -le 0xA4CF) -or
            ($code -ge 0xAC00 -and $code -le 0xD7A3) -or ($code -ge 0xF900 -and $code -le 0xFAFF) -or
            ($code -ge 0xFE30 -and $code -le 0xFE6F) -or ($code -ge 0xFF00 -and $code -le 0xFF60) -or
            ($code -ge 0xFFE0 -and $code -le 0xFFE6))) { $n += 2 } else { $n += 1 }
    }
    return $n
}
function Bar([string]$left, [string]$right = '', [string]$color = 'DarkCyan') {
    $pad = ($W - 2) - (Get-VisualLength $left) - (Get-VisualLength $right)
    if ($pad -lt 1) { $pad = 1 }
    Write-Host '│ ' -NoNewline -ForegroundColor $color
    Write-Host $left -NoNewline -ForegroundColor White
    Write-Host (' ' * $pad) -NoNewline
    Write-Host $right -NoNewline -ForegroundColor DarkGray
    Write-Host ' │' -ForegroundColor $color
}
function Show-Header {
    $cs = if ($script:Ctx.Codespace) { $script:Ctx.Codespace } else { $S.notFound }
    $sync = if ($script:Ctx.Mode) {
        $state = if ($script:Ctx.Enabled -eq 'off') { $S.modePaused } else { $S.modeOn }
        "$($S.sync) $($script:Ctx.Mode) · $state · $($S.pending) $($script:Ctx.Pending)"
    } else { "$($S.sync) …" }
    Line ''
    Line ('╭' + ('─' * ($W - 2)) + '╮') 'DarkCyan'
    Bar $S.title "v$Version" 'DarkCyan'
    Bar "$($S.codespace)  $cs" $script:Ctx.State 'DarkCyan'
    Bar $sync (Age $script:Ctx.LastPush) 'DarkCyan'
    Line ('╰' + ('─' * ($W - 2)) + '╯') 'DarkCyan'
    Line ''
}
function Show-Item([string]$key, [string]$label, [string]$desc) {
    $pad = 14 - (Get-VisualLength $label)
    if ($pad -lt 1) { $pad = 1 }
    Write-Host '   ' -NoNewline
    Write-Host "[$key] " -ForegroundColor Yellow -NoNewline
    Write-Host $label -ForegroundColor White -NoNewline
    Write-Host (' ' * $pad) -NoNewline
    Write-Host $desc -ForegroundColor DarkGray
}

# ---------------------------------------------------------------- actions
function Invoke-Child([string]$script, [string[]]$extra = @()) {
    $path = Join-Path $Here $script
    if (-not (Test-Exists $path)) { Line "  $($S.missing) $path" Red; return }
    $argv = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $path, '-Base', $Base, '-Key', $Key, '-Lang', $Lang) + $extra
    & powershell @argv
}
function Action-Open {
    Line ''
    Line $S.step1 'DarkGray'
    $list = @(); try { $list = & $Gh codespace list --json name,state 2>$null | ConvertFrom-Json } catch {}
    $cs = $list | Where-Object { $_.name -eq $script:Ctx.Codespace } | Select-Object -First 1
    if (-not $cs) { $cs = $list | Select-Object -First 1 }
    if (-not $cs) { Line "  $($S.notFound)" Red; return }
    $script:Ctx.Codespace = $cs.name
    if ($cs.state -and $cs.state -ne 'Available') {
        Line $S.waking Yellow
        & $Gh codespace start -c $cs.name 2>&1 | Out-Null
    } else { Line '      Available' Green }
    Line $S.step2 'DarkGray'
    $out = Get-Remote "bash $CloudDir/start.sh"
    foreach ($line in $out) { Line "      $line" Gray }
    Line $S.step3 'DarkGray'
    Start-Process -FilePath $Gh -ArgumentList @('codespace', 'ports', 'forward', '3080:3080', '-c', $cs.name) -WindowStyle Hidden
    Start-Sleep -Seconds 8
    $url = ($out | Where-Object { $_ -match '^http' } | Select-Object -Last 1)
    if (-not $url) { $url = 'http://127.0.0.1:3080' }
    Start-Process $url.ToString().Trim()
    Line ''
    Line $S.okOpened Green
}
function Action-Sync {
    while ($true) {
        Line ''
        Line "  $($S.syncMenu)" White
        Show-Item '1' $S.s1 $S.s1d
        Show-Item '2' $S.s2 $S.s2d
        Show-Item '3' $S.s3 $S.s3d
        Show-Item '4' $S.s4 $S.s4d
        Show-Item '5' $S.s5 $S.s5d
        Show-Item '6' $S.s6 $S.s6d
        Show-Item '7' $S.s7 $S.s7d
        Show-Item '8' $S.s8 $S.s8d
        Show-Item '9' $S.s9 $S.s9d
        Show-Item '0' $S.s0 ''
        Line ''
        $c = [string](Read-Host $S.choose)
        $map = @{ '1' = '--status'; '2' = '--now'; '3' = '--disable'; '4' = '--enable';
                  '5' = '--mode=idle'; '6' = '--mode=interval --interval=300'; '7' = '--mode=manual';
                  '8' = '--squash-window=1800'; '9' = '--squash-window=0' }
        if ($c -eq '0' -or -not $c) { return }
        if (-not $map[$c]) { continue }
        Line ''
        foreach ($line in (Get-Remote "bash $CloudDir/sync.sh $($map[$c])")) { Line "  $line" Gray }
        $script:Ctx.Mode = ''
        Update-HeaderData
        Read-Host $S.pressEnter | Out-Null
    }
}
function Action-Log {
    Line ''
    foreach ($line in (Get-Remote 'tail -n 25 ~/dsh-sync.log')) { Line "  $line" Gray }
}
function Action-Repair {
    $scriptPath = Join-Path $Here 'cloud-setup.sh'
    if (-not (Test-Exists $scriptPath)) { Line "  $($S.missing) $scriptPath" Red; return }
    Line ''
    Line $S.repairRun 'DarkGray'
    $cmdLine = "`"$Gh`" codespace ssh -c $($script:Ctx.Codespace) -- -i `"$Key`" `"bash -s`" < `"$scriptPath`""
    foreach ($line in (cmd /c $cmdLine 2>&1)) { Line "  $line" Gray }
    Line ''
    Invoke-Child 'doctor.ps1'
}
function Action-Uninstall {
    Invoke-Child 'uninstall.ps1' @('-Local', '-Cloud', '-PurgeCloud')
    Line ''
    Show-Item '1' $S.u1 $S.u1d
    Show-Item '2' $S.u2 $S.u2d
    Show-Item '3' $S.u3 $S.u3d
    Show-Item '4' $S.u4 $S.u4d
    Line ''
    $c = [string](Read-Host $S.choose)
    switch ($c) {
        '2' { Invoke-Child 'uninstall.ps1' @('-Yes', '-Cloud') }
        '3' { Invoke-Child 'uninstall.ps1' @('-Yes', '-Local', '-Cloud', '-PurgeCloud') }
        '4' {
            $v = [string](Read-Host $S.uAskKey)
            if ($v -match '^(y|Y)') {
                Invoke-Child 'uninstall.ps1' @('-Yes', '-Local', '-PurgeLocal', '-Cloud', '-PurgeCloud', '-RevokeDeployKey')
            } else {
                Invoke-Child 'uninstall.ps1' @('-Yes', '-Local', '-PurgeLocal', '-Cloud', '-PurgeCloud')
            }
        }
        default { Line $S.cancelled 'DarkGray' }
    }
}
function Action-Language {
    $Lang = if ($Lang -eq 'en') { 'zh' } else { 'en' }
    try { Set-Content -LiteralPath $LangFile -Value $Lang -Encoding ASCII } catch {}
    Write-Host ''
    Write-Host '  language switched — restarting the panel …' -ForegroundColor Green
    Start-Sleep -Milliseconds 600
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Here 'console.ps1') -Base $Base -Key $Key -Codespace $script:Ctx.Codespace -Lang $Lang
    exit 0
}
function Invoke-Action([string]$name) {
    switch ($name) {
        'open' { Action-Open }
        'status' { Invoke-Child 'status.ps1' }
        'checkup' { Invoke-Child 'doctor.ps1' }
        'sync' { Action-Sync }
        'update' { Invoke-Child 'update.ps1' }
        'audit' { Invoke-Child 'audit.ps1' }
        'repair' { Action-Repair }
        'uninstall' { Action-Uninstall }
        'log' { Action-Log }
        'preview' { Show-Header; Show-MenuItems }
        default { Line "  ? $name" Red }
    }
}
function Show-MenuItems {
    Show-Item '1' $S.open $S.openDesc
    Show-Item '2' $S.status $S.statusDesc
    Show-Item '3' $S.checkup $S.checkupDesc
    Show-Item '4' $S.syncMenu $S.syncMenuDesc
    Show-Item '5' $S.update $S.updateDesc
    Line ''
    Show-Item 'A' $S.audit $S.auditDesc
    Show-Item 'R' $S.repair $S.repairDesc
    Show-Item 'U' $S.uninstall $S.uninstallDesc
    Show-Item 'L' $S.log $S.logDesc
    Line ''
    Show-Item 'F' $S.refresh $S.refreshDesc
    Show-Item 'E' $S.language $S.languageDesc
    Show-Item '0' $S.exit $S.exitDesc
}

if ($Action) { Update-HeaderData; Invoke-Action $Action; exit 0 }

Update-HeaderData
while ($true) {
    Clear-Host
    Show-Header
    Show-MenuItems
    Line ''
    $c = [string](Read-Host $S.choose)
    switch ($c.ToUpper()) {
        '1' { Clear-Host; Action-Open }
        '2' { Clear-Host; Update-HeaderData; Invoke-Child 'status.ps1' }
        '3' { Clear-Host; Invoke-Child 'doctor.ps1' }
        '4' { Clear-Host; Action-Sync; continue }
        '5' { Clear-Host; Invoke-Child 'update.ps1' }
        'A' { Clear-Host; Invoke-Child 'audit.ps1' }
        'R' { Clear-Host; Action-Repair }
        'U' { Clear-Host; Action-Uninstall }
        'L' { Clear-Host; Action-Log }
        'F' { Update-HeaderData; continue }
        'E' { Action-Language }
        '0' { break }
        default { continue }
    }
    Write-Host ''
    Read-Host $S.pressEnter | Out-Null
}
