param()

$OutputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$项目目录 = Split-Path -Parent $PSScriptRoot
$锁定文件 = Join-Path $项目目录 "sources.lock.json"
$模板文件 = Join-Path $项目目录 "skin\skin-template.css"
$输出目录 = Join-Path $项目目录 "dist"
$输出文件 = Join-Path $输出目录 "runtime-skin.css"
$带BOM的UTF8 = New-Object Text.UTF8Encoding($true)

function 取得SHA256 {
  param([string]$文件)
  $算法 = [Security.Cryptography.SHA256]::Create()
  $流 = [IO.File]::OpenRead($文件)
  try {
    return ([BitConverter]::ToString($算法.ComputeHash($流))).Replace("-", "").ToLowerInvariant()
  } finally {
    $流.Dispose()
    $算法.Dispose()
  }
}

function 备份已有输出 {
  param([string]$文件)

  if (-not (Test-Path -LiteralPath $文件 -PathType Leaf)) {
    return
  }

  $时间 = Get-Date -Format "yyyyMMdd_HHmmss"
  $备份目录 = Join-Path $env:USERPROFILE "BackUp\Codex狸克手机皮肤补丁_$时间"
  [IO.Directory]::CreateDirectory($备份目录) | Out-Null
  $备份文件 = Join-Path $备份目录 ([IO.Path]::GetFileName($文件))
  Copy-Item -LiteralPath $文件 -Destination $备份文件

  $原哈希 = 取得SHA256 -文件 $文件
  $备份哈希 = 取得SHA256 -文件 $备份文件
  if ($原哈希 -ne $备份哈希) {
    throw "构建输出备份校验失败：$文件"
  }
}

$锁定信息 = Get-Content -LiteralPath $锁定文件 -Raw -Encoding UTF8 | ConvertFrom-Json
$样式 = Get-Content -LiteralPath $模板文件 -Raw -Encoding UTF8

$占位符 = @{
  "content_bg_pc.jpg" = "__CONTENT_BG_PC__"
  "menu_bg.svg" = "__MENU_BG_SVG__"
  "animal_icon.png" = "__ANIMAL_ICON__"
  "icon-leaf.png" = "__ICON_LEAF__"
  "divider-line-white.png" = "__DIVIDER_WHITE__"
}

foreach ($文件信息 in $锁定信息.files) {
  $素材文件 = Join-Path $项目目录 ([string]$文件信息.local)
  if (-not (Test-Path -LiteralPath $素材文件 -PathType Leaf)) {
    throw "缺少网站原素材：$素材文件"
  }

  $实际哈希 = 取得SHA256 -文件 $素材文件
  if ($实际哈希 -ne ([string]$文件信息.sha256).ToLowerInvariant()) {
    throw "网站原素材哈希不一致：$素材文件"
  }

  $文件名 = [IO.Path]::GetFileName($素材文件)
  $标记 = $占位符[$文件名]
  if ([string]::IsNullOrWhiteSpace($标记)) {
    continue
  }

  $扩展名 = [IO.Path]::GetExtension($素材文件).ToLowerInvariant()
  $类型 = if ($扩展名 -eq ".jpg" -or $扩展名 -eq ".jpeg") { "image/jpeg" } elseif ($扩展名 -eq ".svg") { "image/svg+xml" } else { "image/png" }
  $数据 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($素材文件))
  $样式 = $样式.Replace($标记, "data:$类型;base64,$数据")
}

if ($样式 -match "__[A-Z0-9_]+__") {
  throw "样式中仍有未替换的素材占位符：$($Matches[0])"
}

[IO.Directory]::CreateDirectory($输出目录) | Out-Null
$新字节 = $带BOM的UTF8.GetBytes($样式)
$需要写入 = $true
if (Test-Path -LiteralPath $输出文件 -PathType Leaf) {
  $旧字节 = [IO.File]::ReadAllBytes($输出文件)
  $需要写入 = -not [Linq.Enumerable]::SequenceEqual([byte[]]$旧字节, [byte[]]$新字节)
}

if ($需要写入) {
  备份已有输出 -文件 $输出文件
  [IO.File]::WriteAllBytes($输出文件, $新字节)
}

$输出哈希 = 取得SHA256 -文件 $输出文件
Write-Output "BUILD_OK $输出哈希"
