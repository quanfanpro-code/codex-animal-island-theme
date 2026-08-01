param(
  [switch]$不自动启动
)

$OutputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$主题包目录 = Split-Path -Parent $PSScriptRoot
$安装目录 = Join-Path $env:LOCALAPPDATA "CodexAnimalIslandSkin"
$带BOM的UTF8 = New-Object Text.UTF8Encoding($true)

function 取得SHA256 {
  param([string]$文件)
  $算法 = [Security.Cryptography.SHA256]::Create()
  $流 = [IO.File]::OpenRead($文件)
  try {
    return ([BitConverter]::ToString($算法.ComputeHash($流))).Replace("-", "")
  } finally {
    $流.Dispose()
    $算法.Dispose()
  }
}

function 备份旧版安装 {
  if (-not (Test-Path -LiteralPath $安装目录 -PathType Container)) {
    return
  }
  $旧文件 = @(Get-ChildItem -LiteralPath $安装目录 -File -Recurse -ErrorAction SilentlyContinue)
  if ($旧文件.Count -eq 0) {
    return
  }

  $时间 = Get-Date -Format "yyyyMMdd_HHmmss"
  $备份目录 = Join-Path $env:USERPROFILE "BackUp\Codex狸克手机主题_$时间"
  [IO.Directory]::CreateDirectory($备份目录) | Out-Null
  foreach ($文件 in $旧文件) {
    $相对路径 = $文件.FullName.Substring($安装目录.Length).TrimStart("\")
    $目标文件 = Join-Path $备份目录 $相对路径
    [IO.Directory]::CreateDirectory((Split-Path -Parent $目标文件)) | Out-Null
    Copy-Item -LiteralPath $文件.FullName -Destination $目标文件
    if ((取得SHA256 -文件 $文件.FullName) -ne (取得SHA256 -文件 $目标文件)) {
      throw "旧版备份校验失败：$($文件.FullName)"
    }
  }
}

function 复制目录内容 {
  param([string]$源目录, [string]$目标目录)
  [IO.Directory]::CreateDirectory($目标目录) | Out-Null
  foreach ($文件 in @(Get-ChildItem -LiteralPath $源目录 -File -Recurse)) {
    $相对路径 = $文件.FullName.Substring($源目录.Length).TrimStart("\")
    $目标文件 = Join-Path $目标目录 $相对路径
    [IO.Directory]::CreateDirectory((Split-Path -Parent $目标文件)) | Out-Null
    Copy-Item -LiteralPath $文件.FullName -Destination $目标文件 -Force
  }
}

function 查找快捷方式图标 {
  try {
    $应用包 = Get-AppxPackage -Name "OpenAI.Codex" -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
    if ($null -ne $应用包) {
      $程序 = Join-Path ([string]$应用包.InstallLocation) "app\ChatGPT.exe"
      if (Test-Path -LiteralPath $程序 -PathType Leaf) {
        return $程序
      }
    }
  } catch {}
  return "$env:SystemRoot\System32\shell32.dll,14"
}

function 创建快捷方式 {
  param([string]$位置)
  $外壳 = New-Object -ComObject WScript.Shell
  $快捷方式 = $外壳.CreateShortcut($位置)
  $快捷方式.TargetPath = "$env:SystemRoot\System32\wscript.exe"
  $快捷方式.Arguments = '"' + (Join-Path $安装目录 "启动狸克手机Codex.vbs") + '"'
  $快捷方式.WorkingDirectory = $安装目录
  $快捷方式.Description = "启动原版 Codex，并只在界面上覆盖狸克手机皮肤"
  $快捷方式.IconLocation = 查找快捷方式图标
  $快捷方式.Save()
}

try {
  $必需文件 = @(
    (Join-Path $主题包目录 "runtime\启动狸克手机Codex.ps1"),
    (Join-Path $主题包目录 "runtime\launch.ps1"),
    (Join-Path $主题包目录 "theme\runtime-skin.css"),
    (Join-Path $主题包目录 "启动狸克手机Codex.vbs")
  )
  foreach ($文件 in $必需文件) {
    if (-not (Test-Path -LiteralPath $文件 -PathType Leaf)) {
      throw "主题包不完整，缺少：$文件"
    }
  }

  备份旧版安装
  [IO.Directory]::CreateDirectory($安装目录) | Out-Null
  复制目录内容 -源目录 (Join-Path $主题包目录 "runtime") -目标目录 (Join-Path $安装目录 "runtime")
  复制目录内容 -源目录 (Join-Path $主题包目录 "theme") -目标目录 (Join-Path $安装目录 "theme")
  if (Test-Path -LiteralPath (Join-Path $主题包目录 "assets") -PathType Container) {
    复制目录内容 -源目录 (Join-Path $主题包目录 "assets") -目标目录 (Join-Path $安装目录 "assets")
  }
  Copy-Item -LiteralPath (Join-Path $主题包目录 "启动狸克手机Codex.vbs") -Destination (Join-Path $安装目录 "启动狸克手机Codex.vbs") -Force
  foreach ($说明文件 in @("README.md", "sources.lock.json", "素材许可说明.md")) {
    $来源 = Join-Path $主题包目录 $说明文件
    if (Test-Path -LiteralPath $来源 -PathType Leaf) {
      Copy-Item -LiteralPath $来源 -Destination (Join-Path $安装目录 $说明文件) -Force
    }
  }

  $桌面 = [Environment]::GetFolderPath("Desktop")
  创建快捷方式 -位置 (Join-Path $桌面 "Codex 狸克手机.lnk")
  $开始菜单 = Join-Path ([Environment]::GetFolderPath("StartMenu")) "Programs"
  [IO.Directory]::CreateDirectory($开始菜单) | Out-Null
  创建快捷方式 -位置 (Join-Path $开始菜单 "Codex 狸克手机.lnk")

  Write-Output "INSTALL_OK $安装目录"
  if (-not $不自动启动) {
    Start-Process -FilePath "$env:SystemRoot\System32\wscript.exe" -ArgumentList ('"' + (Join-Path $安装目录 "启动狸克手机Codex.vbs") + '"') | Out-Null
  }
} catch {
  Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
  [System.Windows.MessageBox]::Show($_.Exception.Message, "Codex 狸克手机安装失败") | Out-Null
  throw
}
