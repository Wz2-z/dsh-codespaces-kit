<#
  dsh-codespaces audit —— 凭据 / 权限清单（Windows 本机）

  “这套工具到底创建了哪些 key/token/config，它们分别能干什么” —— 一条命令列清楚。
  只报告"有什么、在哪、能干什么"，**不打印任何密钥或令牌的内容**。

  用法：powershell -ExecutionPolicy Bypass -File audit.ps1 [-Base <目录>] [-Key <私钥>] [-Json]
#>
[CmdletBinding()]
param(
    [string]$Repo,
    [string]$Codespace,
    [string]$Key,
    [string]$Base,
    [string]$Gh,
    [string]$GhConfig,
    [switch]$Json
)
$ErrorActionPreference = 'Continue'
$KitVersion = '1.5.1'
$CloudAuditUrl = 'https://raw.githubusercontent.com/Wz2-z/dsh-codespaces-kit/main/install/cloud-audit.sh'
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

$rows = New-Object System.Collections.ArrayList
function Add-Row([string]$item, [string]$where, [string]$power) {
    [void]$rows.Add([pscustomobject]@{ Item = $item; Where = $where; Power = $power })
}

# --------------------------------------------------------------- 本机
if (Test-Exists $Gh) {
    $ver = (& $Gh --version 2>$null | Select-Object -First 1)
    Add-Row '便携版 GitHub CLI' $Gh "$ver · 不是系统安装、不改 PATH、不需要管理员"
} else {
    Add-Row '便携版 GitHub CLI' '（没有）' '缺它就什么也做不了：跑 install/setup.ps1'
}

if (Test-Exists $Gh -and (Test-Exists $GhConfig)) {
    $hosts = Join-Path $GhConfig 'hosts.yml'
    $scopes = ''
    if (Test-Exists $hosts) {
        $raw = Get-Content -LiteralPath $hosts -Raw
        if ($raw -match 'oauth_token:\s*(\S+)') { $scopes = '已存登录令牌（明文放在 hosts.yml）' }
    }
    $status = (& $Gh auth status 2>&1 | Out-String)
    $scopeLine = ($status -split "`n" | Select-String -Pattern 'Token scopes' | Select-Object -First 1)
    Add-Row 'GitHub 登录令牌' $hosts "$scopes$(if ($scopeLine) { " · $($scopeLine.ToString().Trim())" })`n            能做什么：读写你能访问的仓库、管理你的 Codespaces"
    Add-Row '撤销方式' '' "gh auth logout -h github.com（或在 GitHub → Settings → Applications 里撤销那把 token）"
} else {
    Add-Row 'GitHub 登录令牌' '（没有）' '没登录；gh auth login 之后才会有'
}

if (Test-Exists $Key) {
    $pub = ''
    try { $pub = (& ssh-keygen -y -f $Key 2>&1 | Out-String).Trim() } catch {}
    $type = if ($pub -match '^(ssh-\S+)') { $matches[1] } else { '未知类型' }
    Add-Row 'SSH 私钥' $Key "$type · 只用来 SSH 进你自己的 Codespace`n            能做什么：登录容器（不能读写仓库、不能动 GitHub 设置）"
    Add-Row '撤销方式' '' "在 GitHub → Settings → SSH and GPG keys 里删掉对应的公钥；本机删掉 $Key 和 $Key.pub"
} else {
    Add-Row 'SSH 私钥' $Key '（没有）· 跑 install/setup.ps1 生成'
}

$desktop = [Environment]::GetFolderPath('Desktop')
$links = @()
foreach ($name in @('DeepSeek Harness', 'dsh 管理台', '更新 dsh', 'dsh 同步', 'dsh 体检')) {
    if (Test-Exists (Join-Path $desktop "$name.lnk")) { $links += $name }
}
if ($links.Count -gt 0) {
    Add-Row '桌面快捷方式' "$desktop" "$($links -join ' / ')`n            只是 .lnk，里面没有密钥，指向工作区里的 .bat"
} else {
    Add-Row '桌面快捷方式' $desktop '（没有）'
}

# --------------------------------------------------------------- 云端
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
if ($Codespace -and (Test-Exists $Gh) -and (Test-Exists $Key)) {
    $script = Join-Path $PSScriptRoot 'cloud-audit.sh'
    $tmp = Join-Path $env:TEMP 'cloud-audit.sh'
    $have = $false
    if (Test-Exists $script) { Copy-Item $script $tmp -Force; $have = $true }
    else {
        try { Invoke-WebRequest -Uri $CloudAuditUrl -OutFile $tmp -UseBasicParsing; $have = $true } catch {}
    }
    if ($have) {
        $cmdLine = "`"$Gh`" codespace ssh -c $Codespace -- -i `"$Key`" `"bash -s`" < `"$tmp`""
        foreach ($line in (cmd /c $cmdLine 2>&1)) {
            if ($line -match '^AUDIT\|([^|]+)\|([^|]*)\|(.*)$') {
                Add-Row $matches[1] $matches[2] $matches[3]
            }
        }
    }
} else {
    Add-Row '云端凭据' '' '跳过（缺 gh / 私钥 / Codespace）'
}

Add-Row '没被创建的东西' '' @'
没有账号级 PAT、没有 GitHub App、没有云厂商账号、没有 sudo 改动；
DeepSeek 的 API Key 只存在容器里的 ~/.dsh/.credentials.yaml（0600），不进仓库、不上传到别处。
'@

if ($Json) {
    [pscustomobject]@{ version = $KitVersion; items = $rows } | ConvertTo-Json -Depth 5
    exit 0
}

Write-Host ''
Write-Host "dsh-codespaces audit  v$KitVersion" -ForegroundColor White
Write-Host "这套工具创建的凭据 / 配置，以及各自能干什么（不显示任何密钥内容）" -ForegroundColor DarkGray
Write-Host ''
foreach ($row in $rows) {
    Write-Host ("  ● {0}" -f $row.Item) -ForegroundColor Cyan
    if ($row.Where) { Write-Host ("     位置：{0}" -f $row.Where) }
    if ($row.Power) { Write-Host ("     $($row.Power)") -ForegroundColor DarkGray }
}
Write-Host ''
Write-Host '  想彻底清掉：dsh-codespaces uninstall --yes' -ForegroundColor Yellow
Write-Host '  详细说明：docs/security-model.md'
Write-Host ''
