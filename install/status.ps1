<#
  dsh-codespaces status —— 一眼看清现在的状态（Windows 本机）

  用法：
    powershell -ExecutionPolicy Bypass -File status.ps1
    powershell -ExecutionPolicy Bypass -File status.ps1 -Base <目录> -Key <私钥> -Quick   # 不查隧道，最快

  输出形如：
    Codespace       Running (fluffy-…)
    Tunnel          Healthy (127.0.0.1:3080 → 401)
    DSH             0.1.7-rc.2 · pid 62857
    Auto sync       idle · on · daemon pid 54889
    Last check      32 seconds ago
    Last push       1 minute ago · dsh: add projects/plugincreate (6 files)
    Pending files   0
#>
[CmdletBinding()]
param(
    [string]$Repo,
    [string]$Codespace,
    [string]$Key,
    [string]$Base,
    [string]$Gh,
    [string]$GhConfig,
    [switch]$NoTunnel,
    [switch]$Quick,
    [switch]$Json
)
$ErrorActionPreference = 'Continue'
$KitVersion = '1.6.0'
$CloudStatusUrl = 'https://raw.githubusercontent.com/Wz2-z/dsh-codespaces-kit/main/install/cloud-status.sh'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
try { $OutputEncoding = [Text.Encoding]::UTF8 } catch {}

function Test-Exists([string]$path) {
    try { return [bool](Test-Path -LiteralPath $path -ErrorAction Stop) } catch { return $false }
}

# ---------------------------------------------------------------- 上下文
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
    $candidates = @((Join-Path $env:LOCALAPPDATA 'dsh-cloud\gh\bin\gh.exe'))
    foreach ($c in $candidates) { if (Test-Exists $c) { $Gh = $c; break } }
}
if (-not $Gh) {
    $onPath = Get-Command gh -ErrorAction SilentlyContinue
    if ($onPath) { $Gh = $onPath.Source }
}

function Format-Age($epoch) {
    $value = 0
    if (-not [double]::TryParse("$epoch", [ref]$value) -or $value -le 0) { return '—' }
    $seconds = [int]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $value)
    if ($seconds -lt 0) { return '刚刚' }
    if ($seconds -lt 60) { return "$seconds 秒前" }
    if ($seconds -lt 3600) { return "$([int]($seconds / 60)) 分钟前" }
    if ($seconds -lt 86400) { return "$([int]($seconds / 3600)) 小时前" }
    return "$([int]($seconds / 86400)) 天前"
}

# ---------------------------------------------------------------- 找 Codespace
$state = ''
if (Test-Exists $Gh) {
    $list = @()
    try { $list = & $Gh codespace list --json name,state,repository 2>$null | ConvertFrom-Json } catch {}
    if (-not $Codespace -and $Repo) {
        $Codespace = ($list | Where-Object {
            $r = $_.repository
            if ($r -is [string]) { $r -eq $Repo } else { $r.nameWithOwner -eq $Repo }
        } | Select-Object -First 1).name
    }
    if (-not $Codespace) { $Codespace = ($list | Select-Object -First 1).name }
    $state = ($list | Where-Object { $_.name -eq $Codespace } | Select-Object -First 1).state
}

# ---------------------------------------------------------------- 云端数据
$cloud = @{}
if ($Codespace -and (Test-Exists $Gh) -and (Test-Exists $Key)) {
    $script = Join-Path $PSScriptRoot 'cloud-status.sh'
    $tmp = Join-Path $env:TEMP 'cloud-status.sh'
    $have = $false
    if (Test-Exists $script) { Copy-Item $script $tmp -Force; $have = $true }
    else {
        try { Invoke-WebRequest -Uri $CloudStatusUrl -OutFile $tmp -UseBasicParsing; $have = $true } catch {}
    }
    if ($have) {
        $cmdLine = "`"$Gh`" codespace ssh -c $Codespace -- -i `"$Key`" `"bash -s`" < `"$tmp`""
        foreach ($line in (cmd /c $cmdLine 2>&1)) {
            if ($line -match '^STATUS\|([^|]+)\|(.*)$') { $cloud[$matches[1]] = $matches[2] }
        }
    }
}

# ---------------------------------------------------------------- 隧道
$tunnel = 'skipped'
$tunnelDetail = ''
if ($NoTunnel -or $Quick) {
    $tunnelDetail = '按 -Quick/-NoTunnel 跳过'
} elseif ($Codespace -and (Test-Exists $Gh) -and (Test-Exists $Key)) {
    $proc = $null
    function Probe-Tunnel {
        try { return [int](Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:3080/' -TimeoutSec 4).StatusCode }
        catch { try { return [int]$_.Exception.Response.StatusCode } catch { return 0 } }
    }
    $code = 0
    # 已经有隧道（比如桌面启动器开着）就直接用，不再开一条
    $code = Probe-Tunnel
    if ($code -eq 0) {
        $proc = Start-Process -FilePath $Gh -ArgumentList @('codespace', 'ports', 'forward', '3080:3080', '-c', $Codespace) -PassThru -WindowStyle Hidden
        for ($i = 1; $i -le 6; $i++) {
            Start-Sleep -Seconds 2
            $code = Probe-Tunnel
            if ($code -ne 0) { break }
        }
    }
    if ($proc -and -not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    if ($code -eq 401) { $tunnel = 'Healthy'; $tunnelDetail = '127.0.0.1:3080 → 401（需要 token，正常）' }
    elseif ($code -eq 200) { $tunnel = 'Healthy'; $tunnelDetail = '127.0.0.1:3080 → 200' }
    elseif ($code -eq 0) { $tunnel = 'Down'; $tunnelDetail = '127.0.0.1:3080 没通' }
    else { $tunnel = 'Degraded'; $tunnelDetail = "返回 $code" }
} else {
    $tunnelDetail = '跳过（缺 gh / 密钥 / Codespace）'
}

$dshHttp = $cloud['dsh_http']
$dshState = if ($dshHttp -eq '401') { 'Healthy' } elseif ($dshHttp -eq '200') { 'Healthy' } elseif ($cloud['dsh_pid']) { "Degraded (HTTP $dshHttp)" } else { 'Down' }
$syncState = if ($cloud['daemon_pids'] -and $cloud['enabled'] -ne 'off') { 'Running' } elseif ($cloud['daemon_pids']) { 'Paused' } else { 'Stopped' }

if ($Json) {
    [pscustomobject]@{
        version = $KitVersion
        codespace = @{ name = $Codespace; state = $state }
        tunnel = @{ state = $tunnel; detail = $tunnelDetail }
        dsh = @{ state = $dshState; version = $cloud['dsh_version']; pid = $cloud['dsh_pid']; http = $dshHttp }
        sync = @{
            state = $syncState; mode = $cloud['mode']; enabled = $cloud['enabled']
            idle = $cloud['idle']; squash = $cloud['squash']; daemonPids = $cloud['daemon_pids']
            lastCheck = $cloud['last_check_epoch']; lastPush = $cloud['last_push_epoch']
            lastPushSubject = $cloud['last_push_subject']; pushFailures = $cloud['push_failures']
        }
        workspace = @{
            pending = $cloud['pending']; pendingFiles = $cloud['pending_files']
            head = $cloud['head_sha']; headEpoch = $cloud['head_epoch']; headSubject = $cloud['head_subject']
            remote = $cloud['remote_sha']; inSync = $cloud['in_sync']
        }
    } | ConvertTo-Json -Depth 6
    exit 0
}

Write-Host ''
$W = 68
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
function Rule([string]$left = '', [string]$right = '') {
    $pad = $W - 4 - (Get-VisualLength $left) - (Get-VisualLength $right)
    if ($pad -lt 1) { $pad = 1 }
    Write-Host '│ ' -NoNewline -ForegroundColor DarkCyan
    Write-Host $left -NoNewline -ForegroundColor DarkGray
    Write-Host (' ' * $pad) -NoNewline
    Write-Host $right -NoNewline -ForegroundColor DarkGray
    Write-Host ' │' -ForegroundColor DarkCyan
}
function Row([string]$name, [string]$state, [string]$detail) {
    $color = switch ($state) { 'Healthy' { 'Green' } 'Running' { 'Green' } 'Down' { 'Red' } 'Stopped' { 'Red' } default { 'Yellow' } }
    $pad = 12 - (Get-VisualLength $name)
    if ($pad -lt 1) { $pad = 1 }
    Write-Host '│ ' -NoNewline -ForegroundColor DarkCyan
    Write-Host $name -NoNewline -ForegroundColor White
    Write-Host (' ' * $pad) -NoNewline
    if ($state) {
        $spad = 10 - (Get-VisualLength $state)
        if ($spad -lt 1) { $spad = 1 }
        Write-Host $state -ForegroundColor $color -NoNewline
        Write-Host (' ' * $spad) -NoNewline
    } else {
        Write-Host (' ' * 10) -NoNewline
    }
    # 详情长度不定，右边框会飘；只留左边一条竖线，反而更整齐
    Write-Host $detail -ForegroundColor DarkGray
}

Write-Host ''
Write-Host ('╭' + ('─' * ($W - 2)) + '╮') -ForegroundColor DarkCyan
Rule "dsh-codespaces status" "v$KitVersion"
Rule 'codespace' $(if ($Codespace) { $Codespace } else { '（没有）' })
Write-Host ('╰' + ('─' * ($W - 2)) + '╯') -ForegroundColor DarkCyan
Write-Host ''

if ($Codespace) { Row 'Codespace' $(if ($state -and $state -ne 'Available') { 'Starting' } else { 'Running' }) "$Codespace$(if ($state) { "（$state）" })" }
else { Row 'Codespace' 'Down' '没有可用的 Codespace' }
Row 'Tunnel' $(if ($tunnel -eq 'skipped') { 'Skipped' } else { $tunnel }) $tunnelDetail
Row 'DSH' $dshState "$($cloud['dsh_version'])$(if ($cloud['dsh_pid']) { " · pid $($cloud['dsh_pid'])" }) · HTTP $dshHttp"
Row 'Auto sync' $syncState "$($cloud['mode']) · $(if ($cloud['enabled'] -eq 'off') { 'paused' } else { 'on' })$(if ($cloud['daemon_pids']) { " · daemon pid $($cloud['daemon_pids'])" }) · 静默 $($cloud['idle'])s · 折叠 $($cloud['squash'])s"
Row 'Last check' '' (Format-Age $cloud['last_check_epoch'])
Row 'Last push' '' "$(Format-Age $cloud['last_push_epoch'])$(if ($cloud['last_push_subject']) { " · $($cloud['last_push_subject'])" })"
Row 'Last commit' '' "$($cloud['head_sha']) · $(Format-Age $cloud['head_epoch']) · $($cloud['head_subject'])"
Row 'Pending files' '' "$($cloud['pending'])$(if ($cloud['pending_files']) { " ($($cloud['pending_files']))" })"
Row 'In sync' '' "$($cloud['in_sync'])（本地 $($cloud['head_sha']) / 远端 $($cloud['remote_sha'])）"
if ($cloud['push_failures'] -and $cloud['push_failures'] -ne '0') {
    Write-Host "  ! 日志里有 $($cloud['push_failures']) 次 push FAILED（tail -n 40 ~/dsh-sync.log 看看）" -ForegroundColor Yellow
}
Write-Host ''
