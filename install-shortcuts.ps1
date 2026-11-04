﻿#requires -Version 5.1
<#
为已缓存的每个 WorkBuddy 账号在桌面创建一个快捷方式。
双击快捷方式即切换到对应账号；若 WorkBuddy 未运行则自动启动。
#>
param(
    [string]$Desktop = [Environment]::GetFolderPath('Desktop')
)

$authDir  = Join-Path $env:LOCALAPPDATA 'CodeBuddyExtension\Data\Public\auth'
$mainFile = Join-Path $authDir 'workbuddy-desktop.info'
$script   = Join-Path $PSScriptRoot 'switch-workbuddy.ps1'
$psExe    = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$icon     = 'C:\Program Files\WorkBuddy\WorkBuddy.exe'

function Get-Uid($path) {
    try {
        $obj = Get-Content $path -Raw -ErrorAction Stop | ConvertFrom-Json
        return $obj.account.uid
    } catch { return $null }
}

$known = @{}
$candidates = @()
if (Test-Path $mainFile) { $candidates += $mainFile }
$candidates += Get-ChildItem $authDir -Filter 'workbuddy-desktop.*.info' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notlike '*tmp*' } | ForEach-Object { $_.FullName }

foreach ($p in $candidates) {
    $uid = Get-Uid $p
    if (-not $uid) { continue }
    if (-not $known.ContainsKey($uid) -or
        (Get-Item $p).LastWriteTime -gt (Get-Item $known[$uid]).LastWriteTime) {
        $known[$uid] = $p
    }
}

if ($known.Count -eq 0) {
    Write-Error '未找到可用账号，请先在 WorkBuddy 中登录至少一个账号'
    exit 1
}

$shell = New-Object -ComObject WScript.Shell
$i = 0
foreach ($uid in ($known.Keys | Sort-Object)) {
    $i++
    $lnk = Join-Path $Desktop "WorkBuddy 账号$i.lnk"
    $shortcut = $shell.CreateShortcut($lnk)
    $shortcut.TargetPath = $psExe
    $shortcut.Arguments = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $script + '" -Account ' + $uid.Substring(0, 8)
    $shortcut.WorkingDirectory = $PSScriptRoot
    $shortcut.WindowStyle = 7
    if (Test-Path $icon) { $shortcut.IconLocation = "$icon,0" }
    $shortcut.Save()
    "已创建: $lnk  ->  $uid"
}

"共创建 $i 个快捷方式"
