<#
  dsh-codespaces update —— 升级云端 dsh 并重新开好隧道
  用法：powershell -ExecutionPolicy Bypass -File update.ps1 [-Base <目录>] [-Key <私钥>] [-NoOpen]
#>
[CmdletBinding()]
param(
    [string]$Repo, [string]$Codespace, [string]$Key, [string]$Base, [string]$Gh, [string]$GhConfig,
    [switch]$NoOpen
)
$ErrorActionPreference = 'Continue'
$KitVersion = '1.5.1'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
try { $OutputEncoding = [Text.Encoding]::UTF8 } catch {}
function Test-Exists([string]$path) { try { return [bool](Test-Path -LiteralPath $path -ErrorAction Stop) } catch { return $false } }
if ($Base) {
    if (-not $Gh) { $Gh = Join-Path $Base 'gh\bin\gh.exe' }
    if (-not $GhConfig) { $c = Join-Path $Base 'ghconfig'; if (Test-Exists $c) { $GhConfig = $c } }
}
if (-not $GhConfig) { $GhConfig = $env:GH_CONFIG_DIR }
if ($GhConfig) { $env:GH_CONFIG_DIR = $GhConfig }
if (-not $Key) { $Key = Join-Path $env:USERPROFILE '.ssh\dsh_cs_key' }
if (-not $Gh) {
    $c = Join-Path $env:LOCALAPPDATA 'dsh-cloud\gh\bin\gh.exe'
    if (Test-Exists $c) { $Gh = $c }
}
if (-not $Codespace -and (Test-Exists $Gh)) {
    $list = @(); try { $list = & $Gh codespace list --json name,repository 2>$null | ConvertFrom-Json } catch {}
    if ($Repo) {
        $Codespace = ($list | Where-Object { $r = $_.repository; if ($r -is [string]) { $r -eq $Repo } else { $r.nameWithOwner -eq $Repo } } | Select-Object -First 1).name
    }
    if (-not $Codespace) { $Codespace = ($list | Select-Object -First 1).name }
}
if (-not $Codespace) { Write-Host '✗ 找不到 Codespace（用 -Codespace 指定）' -ForegroundColor Red; exit 1 }

Write-Host ''
Write-Host "dsh-codespaces update  v$KitVersion" -ForegroundColor White
Write-Host "升级云端 dsh（$Codespace），大约 1 分钟…" -ForegroundColor DarkGray
$out = Join-Path $env:TEMP 'dsh_update_out.txt'
$repoName = ($(& $Gh codespace list --json name,repository 2>$null | ConvertFrom-Json | Where-Object { $_.name -eq $Codespace } | Select-Object -First 1).repository)
$slug = if ($repoName -is [string]) { $repoName } else { $repoName.nameWithOwner }
$cloudDir = "/workspaces/$($slug.Split('/')[-1])/.dsh-cloud"
& $Gh codespace ssh -c $Codespace -- -i $Key "bash $cloudDir/update.sh" > $out 2>&1
Get-Content -LiteralPath $out | ForEach-Object { Write-Host "  $_" }

Write-Host ''
Write-Host '重建隧道并打开浏览器…' -ForegroundColor DarkGray
Start-Process -FilePath $Gh -ArgumentList @('codespace','ports','forward','3080:3080','-c',$Codespace) -WindowStyle Hidden
Start-Sleep -Seconds 8
if (-not $NoOpen) {
    $url = (Get-Content -LiteralPath $out | Select-String -Pattern '^http' | Select-Object -Last 1)
    if ($url) { Start-Process $url.ToString().Trim() } else { Start-Process 'http://127.0.0.1:3080' }
}
Write-Host '完成。' -ForegroundColor Green
Write-Host ''
