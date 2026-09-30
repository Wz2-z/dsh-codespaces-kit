<#
  dsh-codespaces doctor —— 一键体检（Windows 本机）

  用法：
    powershell -ExecutionPolicy Bypass -File doctor.ps1
    powershell -ExecutionPolicy Bypass -File doctor.ps1 -Key $env:USERPROFILE\.ssh\dsh_cs_key
    powershell -ExecutionPolicy Bypass -File doctor.ps1 -NoTunnel     # 跳过隧道检查（快）

  它检查本机的 GitHub CLI / 登录 / SSH 密钥 / Codespace / 隧道 / 桌面启动器，
  再把 install/cloud-doctor.sh 送进容器检查 DSH / workspace / deploy key / 自动同步，
  最后合成一张表并给出 N/M checks passed。
#>
[CmdletBinding()]
param(
    [string]$Repo,
    [string]$Codespace,
    [string]$Key,
    [string]$Base,
    [string]$Gh,
    [string]$GhConfig,
    [ValidateSet('zh', 'en')][string]$Lang = 'zh',
    [switch]$NoTunnel,
    [switch]$Json
)
$ErrorActionPreference = 'Continue'
$KitVersion = '1.7.0'
$CloudDoctorUrl = 'https://raw.githubusercontent.com/Wz2-z/dsh-codespaces-kit/main/install/cloud-doctor.sh'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
try { $OutputEncoding = [Text.Encoding]::UTF8 } catch {}

# 某些环境里 Test-Path 会因权限抛异常（比如读不到的 .ssh 目录），这里一律当成"不存在"
function Test-Exists([string]$path) {
    try { return [bool](Test-Path -LiteralPath $path -ErrorAction Stop) } catch { return $false }
}

$T = if ($Lang -eq 'en') {
    @{
        subtitle = 'host checks + cloud checks, merged into one table'
        ghMissing = 'gh not found (install/setup.ps1 installs a portable copy)'
        loggedIn = 'logged in: {0}'; notLoggedIn = 'not logged in (run gh auth login)'
        netDown = "can't reach api.github.com (network/proxy); token validity not verified"
        keyMissing = 'no {0} (install/setup.ps1 creates it)'
        keyOk = '{0} (readable, {1})'
        keyUnreadable = '{0} cannot be read by ssh-keygen (Windows ACL; keep only yourself with ICACLS)'
        keyError = '{0} unreadable: {1}'
        csNone = 'no Codespace available (gh codespace create -R owner/repo)'
        csUnknown = 'unknown (network down)'
        csWaking = '{0} ({1}; it will wake up when used)'
        csOk = '{0} ({1})'
        cloudNoScript = "can't fetch cloud-doctor.sh: {0}"
        cloudEmpty = 'the cloud returned nothing (key or network problem?)'
        cloudFailed = 'cloud checks failed: {0}'
        skipped = 'skipped ({0})'; missingGh = 'no gh (pass -Gh)'
        missingKey = 'no SSH key (pass -Key)'; missingCs = 'no Codespace'
        tunnel401 = '127.0.0.1:3080 → 401 (token required = good)'
        tunnel200 = '127.0.0.1:3080 → 200'
        tunnelDown = '127.0.0.1:3080 unreachable (returned {0})'
        tunnelSkipped = 'skipped (-NoTunnel)'; tunnelSkipMissing = 'skipped (no gh / key / Codespace)'
        launcherBroken = 'a shortcut points at a file that no longer exists: {0}'
        launcherOk = 'desktop has {0}'
        launcherWarn = 'has {0}, missing {1}'
        launcherMissing = 'no desktop launchers (run install/setup.ps1)'
        missing = 'missing'; maintEntry = 'maintenance entry (dsh control panel or Update dsh)'
        passed = '{0}/{1} checks passed'; warnings = ' · {0} warning(s)'; failed = ' · {0} failed'
    }
} else {
    @{
        subtitle = '本地检查 + 云端检查，两边合起来看'
        ghMissing = '没找到 gh（跑 install/setup.ps1 会装便携版）'
        loggedIn = '已登录：{0}'; notLoggedIn = '没登录（gh auth login）'
        netDown = '连不上 api.github.com（网络/代理问题；token 是否有效还没验证）'
        keyMissing = '没有 {0}（跑 install/setup.ps1 生成）'
        keyOk = '{0}（可读，{1}）'
        keyUnreadable = '{0} 用 ssh-keygen 读不了（Windows 权限；试试 ICACLS 只留自己可读）'
        keyError = '{0} 读不了：{1}'
        csNone = '没有可用的 Codespace（gh codespace create -R owner/repo）'
        csUnknown = '查不到（网络不通）'
        csWaking = '{0}（{1}，跑一下会自动唤醒）'
        csOk = '{0}（{1}）'
        cloudNoScript = '拿不到 cloud-doctor.sh：{0}'
        cloudEmpty = '云端没有返回结果（密钥或网络问题？）'
        cloudFailed = '云端检查失败：{0}'
        skipped = '跳过（{0}）'; missingGh = '没有 gh（用 -Gh 指定路径）'
        missingKey = '没有 SSH 密钥（用 -Key 指定）'; missingCs = '没有 Codespace'
        tunnel401 = '127.0.0.1:3080 → 401（需要 token，正常）'
        tunnel200 = '127.0.0.1:3080 → 200'
        tunnelDown = '127.0.0.1:3080 没通（返回 {0}）'
        tunnelSkipped = '按 -NoTunnel 跳过'; tunnelSkipMissing = '跳过（缺少 gh / 密钥 / Codespace）'
        launcherBroken = '快捷方式指向的文件不在了：{0}'
        launcherOk = '桌面有 {0}'
        launcherWarn = '有 {0}，缺 {1}'
        launcherMissing = '桌面没有启动器（跑 install/setup.ps1 生成）'
        missing = '缺'; maintEntry = '维护入口（dsh 管理台 或 更新 dsh）'
        passed = '{0}/{1} checks passed'; warnings = ' · {0} warning(s)'; failed = ' · {0} failed'
    }
}

$CloudDir = Join-Path $env:LOCALAPPDATA 'dsh-cloud'
# -Base 指向"整套东西放一起"的目录（里面应该有 gh\bin\gh.exe 和 ghconfig\）
if ($Base) {
    if (-not $Gh) { $Gh = Join-Path $Base 'gh\bin\gh.exe' }
    if (-not $GhConfig) {
        $candidate = Join-Path $Base 'ghconfig'
        if (Test-Exists $candidate) { $GhConfig = $candidate }
    }
}
if (-not $GhConfig) { $GhConfig = $env:GH_CONFIG_DIR }
if ($GhConfig) { $env:GH_CONFIG_DIR = $GhConfig }
if (-not $Key) {
    $Key = Join-Path $env:USERPROFILE '.ssh\dsh_cs_key'
}
if (-not $Repo -and $env:DSH_REPO) { $Repo = $env:DSH_REPO }

$results = New-Object System.Collections.ArrayList
function Add-Check([string]$name, [string]$status, [string]$detail) {
    [void]$results.Add([pscustomobject]@{ Name = $name; Status = $status; Detail = $detail })
}

if (-not $Json) {
    Write-Host ''
    Write-Host "dsh-codespaces doctor  v$KitVersion" -ForegroundColor White
    Write-Host $T.subtitle -ForegroundColor DarkGray
}

# ------------------------------------------------------------------ GitHub CLI
if (-not $Gh) { $Gh = $env:DSH_GH }
if (-not $Gh) {
    $candidates = @(
        (Join-Path $CloudDir 'gh\bin\gh.exe'),
        (Join-Path $env:USERPROFILE '.local\share\dsh-cloud\gh\bin\gh.exe')
    )
    foreach ($candidate in $candidates) {
        if (Test-Exists $candidate) { $Gh = $candidate; break }
    }
}
if (-not $Gh) {
    $onPath = Get-Command gh -ErrorAction SilentlyContinue
    if ($onPath) { $Gh = $onPath.Source }
}
if (Test-Exists $Gh) {
    $ghVersion = (& $Gh --version 2>$null | Select-Object -First 1)
    Add-Check 'GitHub CLI' 'ok' "$ghVersion"
} else {
    Add-Check 'GitHub CLI' 'fail' $T.ghMissing
}

# ------------------------------------------------------------ GitHub 认证
$authed = $false
$authDetail = $T.notLoggedIn
$networkDown = $false
function Test-NetworkError([string]$text) {
    return [bool]($text -match 'dial tcp|connectex|forbidden by its access permissions|no such host|i/o timeout|connection refused|Could not resolve host')
}
if (Test-Exists $Gh) {
    $status = & $Gh auth status 2>&1 | Out-String
    $authed = $LASTEXITCODE -eq 0
    if ($authed) {
        $account = ($status | Select-String -Pattern 'account ([^\s]+)' | Select-Object -First 1).Matches.Groups[1].Value
        $authDetail = if ($account) { $T.loggedIn -f $account } else { $T.loggedIn -f '?' }
    } elseif (Test-NetworkError $status) {
        # gh 在"连不上网"时也会说 token invalid —— 分开报，别误导
        $networkDown = $true
        $authDetail = $T.netDown
    }
}
Add-Check 'GitHub authentication' $(if ($authed) { 'ok' } elseif ($networkDown) { 'warn' } else { 'fail' }) $authDetail

# ------------------------------------------------------------------ SSH 密钥
$keyOk = $false
$keyDetail = $T.keyMissing -f $Key
$keyStatus = 'fail'
if (Test-Exists $Key) {
    try {
        $pub = (& ssh-keygen -y -f $Key 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -eq 0 -and $pub.StartsWith('ssh-')) {
            $keyOk = $true
            $keyStatus = 'ok'
            $keyDetail = $T.keyOk -f $Key, ($pub -split ' ')[0]
        } else {
            # 读不了就先记警告，但**不挡住**后面的云端检查（也许只是权限工具在捣乱）
            $keyStatus = 'warn'
            $keyDetail = $T.keyUnreadable -f $Key
        }
    } catch {
        $keyStatus = 'warn'
        $keyDetail = $T.keyError -f $Key, $_.Exception.Message
    }
}
Add-Check 'SSH key' $keyStatus $keyDetail

# ------------------------------------------------------------------ Codespace
$Cs = $Codespace
if (Test-Exists $Gh) {
    $list = @()
    $listError = ''
    try { $list = & $Gh codespace list --json name,state,repository 2>&1 | ConvertFrom-Json } catch { $listError = $_.Exception.Message }
    if (-not $list -and (Test-NetworkError "$listError")) { $networkDown = $true }
    if (-not $Cs -and $Repo) {
        $Cs = ($list | Where-Object {
            $r = $_.repository
            if ($r -is [string]) { $r -eq $Repo } else { $r.nameWithOwner -eq $Repo }
        } | Select-Object -First 1).name
    }
    if (-not $Cs) { $Cs = ($list | Select-Object -First 1).name }
}
if (-not $Cs) {
    if ($networkDown) {
        Add-Check 'Codespace' 'warn' $T.csUnknown
    } else {
        Add-Check 'Codespace' 'fail' $T.csNone
    }
} else {
    $state = ($list | Where-Object { $_.name -eq $Cs } | Select-Object -First 1).state
    if ($state -and $state -ne 'Available') {
        Add-Check 'Codespace' 'warn' ($T.csWaking -f $Cs, $state)
    } else {
        Add-Check 'Codespace' 'ok' (if ($state) { $T.csOk -f $Cs, $state } else { $Cs })
    }
}

# --------------------------------------------------------------- 云端检查
$cloudRan = $false
if ($Cs -and (Test-Exists $Gh) -and (Test-Exists $Key)) {
    $script = Join-Path $PSScriptRoot 'cloud-doctor.sh'
    $tmp = Join-Path $env:TEMP 'cloud-doctor.sh'
    $haveScript = $false
    if (Test-Exists $script) {
        Copy-Item $script $tmp -Force
        $haveScript = $true
    } else {
        try {
            Invoke-WebRequest -Uri $CloudDoctorUrl -OutFile $tmp -UseBasicParsing
            $haveScript = $true
        } catch {
            Add-Check 'Cloud checks' 'warn' ($T.cloudNoScript -f $_.Exception.Message)
        }
    }
    if ($haveScript) {
        try {
            # 用 cmd 的 < 直接把文件喂给 gh stdin：PowerShell 5.1 的管道会按 ASCII 重编码，中文会变 ?
            $cmdLine = "`"$Gh`" codespace ssh -c $Cs -- -i `"$Key`" `"bash -s`" < `"$tmp`""
            $lines = cmd /c $cmdLine 2>&1
            foreach ($line in $lines) {
                if ($line -match '^CHECK\|([^|]+)\|([^|]+)\|(.*)$') {
                    Add-Check $matches[1] $matches[2] $matches[3]
                    $cloudRan = $true
                }
            }
            if (-not $cloudRan) {
                Add-Check 'Cloud checks' 'warn' $T.cloudEmpty
            }
        } catch {
            Add-Check 'Cloud checks' 'warn' ($T.cloudFailed -f $_.Exception.Message)
        }
    }
} else {
    $why = if (-not (Test-Exists $Gh)) { $T.missingGh } elseif (-not (Test-Exists $Key)) { $T.missingKey } else { $T.missingCs }
    Add-Check 'Cloud checks' 'warn' ($T.skipped -f $why)
}

# -------------------------------------------------------------------- 隧道
if ($NoTunnel) {
    Add-Check 'Tunnel' 'warn' $T.tunnelSkipped
} elseif ($Cs -and (Test-Exists $Gh) -and (Test-Exists $Key)) {
    $proc = Start-Process -FilePath $Gh -ArgumentList @('codespace', 'ports', 'forward', '3080:3080', '-c', $Cs) -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds 7
    $code = 0
    try { $code = [int](Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:3080/' -TimeoutSec 8).StatusCode }
    catch { try { $code = [int]$_.Exception.Response.StatusCode } catch { $code = 0 } }
    if ($proc -and -not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    if ($code -eq 401) { Add-Check 'Tunnel' 'ok' $T.tunnel401 }
    elseif ($code -eq 200) { Add-Check 'Tunnel' 'ok' $T.tunnel200 }
    else { Add-Check 'Tunnel' 'fail' ($T.tunnelDown -f $code) }
} else {
    Add-Check 'Tunnel' 'warn' $T.tunnelSkipMissing
}

# ---------------------------------------------------------------- 桌面启动器
$desktop = [Environment]::GetFolderPath('Desktop')
# 启动入口必须有；维护入口可以是"更新 dsh"，也可以是合并后的"dsh 管理台"
$startNames = @('DeepSeek Harness')
$maintNames = @('dsh 管理台', '更新 dsh')
$optNames = @('dsh 同步', 'dsh 体检')
$foundStart = @($startNames | Where-Object { Test-Exists (Join-Path $desktop "$_.lnk") })
$foundMaint = @($maintNames | Where-Object { Test-Exists (Join-Path $desktop "$_.lnk") })
$foundOpt = @($optNames | Where-Object { Test-Exists (Join-Path $desktop "$_.lnk") })
$present = @($foundStart + $foundMaint + $foundOpt)

# 快捷方式指向的 .bat 还在不在（挪过目录就会断）
$broken = @()
if ($present.Count -gt 0) {
    try {
        $shell = New-Object -ComObject WScript.Shell
        foreach ($name in $present) {
            try {
                $target = $shell.CreateShortcut((Join-Path $desktop "$name.lnk")).TargetPath
                if ($target -and -not (Test-Exists $target)) { $broken += "$name → $target" }
            } catch {
                # 读不出来就当没坏
            }
        }
    } catch {
        # 没有 COM 也不影响其它检查
    }
}

if ($broken.Count -gt 0) {
    Add-Check 'Launcher' 'warn' ($T.launcherBroken -f ($broken -join '; '))
} elseif ($foundStart.Count -gt 0 -and $foundMaint.Count -gt 0) {
    Add-Check 'Launcher' 'ok' ($T.launcherOk -f ($present -join ' / '))
} elseif ($present.Count -gt 0) {
    $missing = @()
    if ($foundStart.Count -eq 0) { $missing += 'DeepSeek Harness' }
    if ($foundMaint.Count -eq 0) { $missing += $T.maintEntry }
    Add-Check 'Launcher' 'warn' ($T.launcherWarn -f ($present -join ' / '), ($missing -join ', '))
} else {
    Add-Check 'Launcher' 'fail' $T.launcherMissing
}

# -------------------------------------------------------------------- 输出
$ok = @($results | Where-Object { $_.Status -eq 'ok' }).Count
$warn = @($results | Where-Object { $_.Status -eq 'warn' }).Count
$fail = @($results | Where-Object { $_.Status -eq 'fail' }).Count
$total = $results.Count

if ($Json) {
    [pscustomobject]@{
        version = $KitVersion
        passed = $ok; warnings = $warn; failed = $fail; total = $total
        checks = $results
    } | ConvertTo-Json -Depth 5
} else {
    $order = @('GitHub CLI', 'GitHub authentication', 'Codespace', 'DSH', 'SSH key',
               'Workspace', 'Deploy key', 'Auto sync', 'Sync config', 'dsh web', 'Tunnel', 'Launcher')
    $ordered = @()
    foreach ($name in $order) { $ordered += @($results | Where-Object { $_.Name -eq $name }) }
    $ordered += @($results | Where-Object { $_.Name -notin $order })

    foreach ($r in $ordered) {
        $mark = switch ($r.Status) { 'ok' { '✓' } 'warn' { '!' } default { '✗' } }
        $color = switch ($r.Status) { 'ok' { 'Green' } 'warn' { 'Yellow' } default { 'Red' } }
        Write-Host ("  {0,-24} " -f $r.Name) -NoNewline
        Write-Host $mark -ForegroundColor $color -NoNewline
        Write-Host "  $($r.Detail)" -ForegroundColor DarkGray
    }
    Write-Host ''
    $summary = $T.passed -f $ok, $total
    if ($warn) { $summary += ($T.warnings -f $warn) }
    if ($fail) { $summary += ($T.failed -f $fail) }
    Write-Host "  $summary" -ForegroundColor $(if ($fail) { 'Red' } elseif ($warn) { 'Yellow' } else { 'Green' })
    Write-Host ''
}

exit $(if ($fail) { 1 } else { 0 })
