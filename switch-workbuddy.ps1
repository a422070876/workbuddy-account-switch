﻿#requires -Version 5.1
<#
WorkBuddy 本地账号一键切换

用法：
  .\switch-workbuddy.ps1 -List                 列出已缓存的账号
  .\switch-workbuddy.ps1 -Account 4ce247bd     切换到指定 uid 前缀的账号
#>
param(
    [string]$Account,
    [switch]$List
)

$authDir  = Join-Path $env:LOCALAPPDATA 'CodeBuddyExtension\Data\Public\auth'
$mainFile = Join-Path $authDir 'workbuddy-desktop.info'
$storeDir = Join-Path $env:LOCALAPPDATA 'WorkBuddySwitch'
$exe      = 'C:\Program Files\WorkBuddy\WorkBuddy.exe'

New-Item -ItemType Directory -Path $storeDir -Force | Out-Null

function Get-AccountInfo($path) {
    try {
        $obj = Get-Content $path -Raw -ErrorAction Stop | ConvertFrom-Json
        if ($obj.account -and $obj.account.uid) {
            return [pscustomobject]@{ Uid = $obj.account.uid; Path = $path }
        }
    } catch { }
    return $null
}

$known = @{}
$candidates = @()
if (Test-Path $mainFile) { $candidates += $mainFile }
$candidates += Get-ChildItem $authDir -Filter 'workbuddy-desktop.*.info' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notlike '*tmp*' } | ForEach-Object { $_.FullName }
$candidates += Get-ChildItem $storeDir -Filter 'account-*.info' -ErrorAction SilentlyContinue |
    ForEach-Object { $_.FullName }

foreach ($p in $candidates) {
    $info = Get-AccountInfo $p
    if (-not $info) { continue }
    if (-not $known.ContainsKey($info.Uid) -or
        (Get-Item $p).LastWriteTime -gt (Get-Item $known[$info.Uid]).LastWriteTime) {
        $known[$info.Uid] = $p
    }
}

$current = if (Test-Path $mainFile) { (Get-AccountInfo $mainFile).Uid } else { $null }

if ($List -or -not $Account) {
    "当前账号: $current"
    $i = 0
    foreach ($uid in ($known.Keys | Sort-Object)) {
        $i++
        $stamp = (Get-Item $known[$uid]).LastWriteTime.ToString('yyyy-MM-dd HH:mm')
        "[$i] $uid  (缓存更新: $stamp)"
    }
    if (-not $List) { '用法: switch-workbuddy.ps1 -Account <uid前缀>' }
    return
}

$target = $known.Keys | Where-Object { $_ -like "$Account*" } | Select-Object -First 1
if (-not $target) {
    Write-Error "未找到账号: $Account（可先运行 -List 查看）"
    exit 1
}

# 切换前先保存当前账号的最新登录态，避免 token 刷新丢失
if ($current -and $current -ne $target) {
    $currentSnapshot = Join-Path $storeDir ('account-' + $current.Substring(0, 8) + '.info')
    Copy-Item $mainFile $currentSnapshot -Force -ErrorAction SilentlyContinue
}

if ($current -ne $target) {
    $tmp = Join-Path $authDir ('workbuddy-desktop.info.tmp-' + [guid]::NewGuid().ToString('N'))
    Copy-Item $known[$target] $tmp -Force
    Move-Item $tmp $mainFile -Force
    Remove-Item ($mainFile + '.logged-out') -Force -ErrorAction SilentlyContinue
}

if (-not (Get-Process 'WorkBuddy' -ErrorAction SilentlyContinue)) {
    if (Test-Path $exe) { Start-Process $exe } else { Write-Error "未找到 $exe" }
}
