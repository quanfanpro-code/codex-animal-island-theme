param(
  [switch]$SelfTest,
  [switch]$安静等待
)

$OutputEncoding = [Console]::OutputEncoding = [Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$运行目录 = Split-Path -Parent $PSScriptRoot
$日志目录 = Join-Path $env:LOCALAPPDATA "CodexAnimalIslandSkin\logs"
[IO.Directory]::CreateDirectory($日志目录) | Out-Null
$日志文件 = Join-Path $日志目录 "runtime.log"

function 写日志 {
  param([string]$内容)
  $行 = "{0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $内容
  [IO.File]::AppendAllText($日志文件, $行 + [Environment]::NewLine, (New-Object Text.UTF8Encoding($true)))
}

function 显示提示 {
  param([string]$内容, [string]$标题 = "Codex 狸克手机")
  Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
  [System.Windows.MessageBox]::Show($内容, $标题) | Out-Null
}

function 查找原版Codex {
  $候选 = @()
  try {
    $候选 = @(Get-AppxPackage -Name "OpenAI.Codex" -ErrorAction SilentlyContinue | Sort-Object Version -Descending)
  } catch {
    写日志 "通过应用包信息查找失败：$($_.Exception.Message)"
  }

  foreach ($应用包 in $候选) {
    $程序 = Join-Path ([string]$应用包.InstallLocation) "app\ChatGPT.exe"
    if (Test-Path -LiteralPath $程序 -PathType Leaf) {
      return $程序
    }
  }

  # ponytail: 只在应用包查询不可用时扫描标准商店目录，避免固定版本与固定架构。
  $商店目录 = Join-Path $env:ProgramFiles "WindowsApps"
  try {
    $目录候选 = @(Get-ChildItem -LiteralPath $商店目录 -Directory -Filter "OpenAI.Codex_*__2p2nqsd0c76g0" -ErrorAction SilentlyContinue | Sort-Object Name -Descending)
    foreach ($目录 in $目录候选) {
      $程序 = Join-Path $目录.FullName "app\ChatGPT.exe"
      if (Test-Path -LiteralPath $程序 -PathType Leaf) {
        return $程序
      }
    }
  } catch {
    写日志 "通过标准商店目录查找失败：$($_.Exception.Message)"
  }

  throw "没有找到微软商店安装的原版 Codex。请先安装或更新原版 Codex。"
}

function 准备应用激活器 {
  # 新版 Codex 需要商店应用身份；直接运行安装目录的 EXE 会导致启动失败。
  if ($null -eq ("CodexAnimalIsland.ApplicationLauncher" -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
namespace CodexAnimalIsland {
  [ComImport, Guid("2E941141-7F97-4756-BA1D-9DECDE894A3D"),
   InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IApplicationActivationManager {
    void ActivateApplication(
      [MarshalAs(UnmanagedType.LPWStr)] string appId,
      [MarshalAs(UnmanagedType.LPWStr)] string arguments,
      uint options, out uint processId);
    void ActivateForFile(
      [MarshalAs(UnmanagedType.LPWStr)] string appId, IntPtr items,
      [MarshalAs(UnmanagedType.LPWStr)] string verb, out uint processId);
    void ActivateForProtocol(
      [MarshalAs(UnmanagedType.LPWStr)] string appId, IntPtr items, out uint processId);
  }
  public static class ApplicationLauncher {
    public static uint Launch(string appId, string arguments) {
      object manager = Activator.CreateInstance(Type.GetTypeFromCLSID(
        new Guid("45BA127D-10A8-46EA-8AB7-56EA9078943C")));
      try {
        uint processId;
        ((IApplicationActivationManager)manager).ActivateApplication(
          appId, arguments, 0, out processId);
        return processId;
      } finally { Marshal.ReleaseComObject(manager); }
    }
  }
}
"@
  }
}

function 取得应用标识 {
  param([string]$程序路径)
  foreach ($应用包 in @(Get-AppxPackage -Name "OpenAI.Codex" -ErrorAction Stop)) {
    $清单 = Get-AppxPackageManifest -Package $应用包.PackageFullName -ErrorAction Stop
    foreach ($应用 in $清单.Package.Applications.Application) {
      if ((Join-Path $应用包.InstallLocation ([string]$应用.Executable)) -eq $程序路径) {
        return "{0}!{1}" -f $应用包.PackageFamilyName, $应用.Id
      }
    }
  }
  throw "没有找到 Codex 的 Windows 应用注册信息。请先从开始菜单打开原版 Codex。"
}

function 查找皮肤样式 {
  $候选 = @(
    (Join-Path $运行目录 "theme\runtime-skin.css"),
    (Join-Path $运行目录 "dist\runtime-skin.css")
  )
  foreach ($文件 in $候选) {
    if (Test-Path -LiteralPath $文件 -PathType Leaf) {
      return $文件
    }
  }
  throw "没有找到狸克手机皮肤文件。请重新安装主题包。"
}

function 取得空闲端口 {
  $监听 = New-Object Net.Sockets.TcpListener -ArgumentList @([Net.IPAddress]::Loopback, 0)
  try {
    $监听.Start()
    return ([Net.IPEndPoint]$监听.LocalEndpoint).Port
  } finally {
    $监听.Stop()
  }
}

function 发送网页套接字文本 {
  param(
    [Net.WebSockets.ClientWebSocket]$套接字,
    [string]$文本
  )
  $字节 = [Text.Encoding]::UTF8.GetBytes($文本)
  $片段 = New-Object "System.ArraySegment[byte]" -ArgumentList @(,$字节)
  $套接字.SendAsync($片段, [Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).GetAwaiter().GetResult() | Out-Null
}

function 接收网页套接字文本 {
  param([Net.WebSockets.ClientWebSocket]$套接字)

  $缓冲 = New-Object byte[] 65536
  $片段 = New-Object "System.ArraySegment[byte]" -ArgumentList @(,$缓冲)
  $内存 = New-Object IO.MemoryStream
  try {
    do {
      $结果 = $套接字.ReceiveAsync($片段, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
      if ($结果.MessageType -eq [Net.WebSockets.WebSocketMessageType]::Close) {
        throw "调试连接已关闭"
      }
      $内存.Write($缓冲, 0, $结果.Count)
    } while (-not $结果.EndOfMessage)
    return [Text.Encoding]::UTF8.GetString($内存.ToArray())
  } finally {
    $内存.Dispose()
  }
}

function 调用页面指令 {
  param(
    [Net.WebSockets.ClientWebSocket]$套接字,
    [ref]$编号,
    [string]$方法,
    [hashtable]$参数
  )

  $编号.Value++
  $当前编号 = $编号.Value
  $消息 = @{ id = $当前编号; method = $方法; params = $参数 } | ConvertTo-Json -Compress -Depth 20
  发送网页套接字文本 -套接字 $套接字 -文本 $消息

  while ($true) {
    $响应文本 = 接收网页套接字文本 -套接字 $套接字
    $响应 = $响应文本 | ConvertFrom-Json
    if ($响应.id -ne $当前编号) {
      continue
    }
    if ($null -ne $响应.error) {
      throw "页面指令失败：$方法；$($响应.error.message)"
    }
    return $响应.result
  }
}

function 生成注入脚本 {
  param([string]$样式文本)

  $样式字节 = [Text.Encoding]::UTF8.GetBytes($样式文本.TrimStart([char]0xFEFF))
  $样式Base64 = [Convert]::ToBase64String($样式字节)
  return @"
(() => {
  const marker = 'animal-island-runtime-skin';
  const bytes = Uint8Array.from(atob('$样式Base64'), c => c.charCodeAt(0));
  const css = new TextDecoder('utf-8').decode(bytes);
  const install = () => {
    if (!document.documentElement) return;
    let style = document.getElementById(marker);
    if (!style) {
      style = document.createElement('style');
      style.id = marker;
      document.head.appendChild(style);
    }
    if (style.textContent !== css) style.textContent = css;
    document.documentElement.dataset.animalIslandRuntimeSkin = 'on';
  };
  if (window.__animalIslandRuntimeSkin) {
    window.__animalIslandRuntimeSkin.install();
    return;
  }
  install();
  const observer = new MutationObserver(install);
  if (document.documentElement) observer.observe(document.documentElement, { childList: true, subtree: true });
  setInterval(install, 1500);
  window.__animalIslandRuntimeSkin = { install, observer };
})();
"@
}

function 注入页面皮肤 {
  param(
    [string]$连接地址,
    [string]$注入脚本
  )

  $套接字 = New-Object Net.WebSockets.ClientWebSocket
  $套接字.Options.SetRequestHeader("Origin", "http://localhost")
  $超时 = New-Object Threading.CancellationTokenSource -ArgumentList 7000
  try {
    $套接字.ConnectAsync([Uri]$连接地址, $超时.Token).GetAwaiter().GetResult() | Out-Null
    $编号 = 0
    调用页面指令 -套接字 $套接字 -编号 ([ref]$编号) -方法 "Page.enable" -参数 @{} | Out-Null
    调用页面指令 -套接字 $套接字 -编号 ([ref]$编号) -方法 "Runtime.enable" -参数 @{} | Out-Null
    调用页面指令 -套接字 $套接字 -编号 ([ref]$编号) -方法 "Page.addScriptToEvaluateOnNewDocument" -参数 @{ source = $注入脚本 } | Out-Null
    调用页面指令 -套接字 $套接字 -编号 ([ref]$编号) -方法 "Runtime.evaluate" -参数 @{ expression = $注入脚本; awaitPromise = $false; returnByValue = $true } | Out-Null
  } finally {
    $超时.Dispose()
    if ($套接字.State -eq [Net.WebSockets.WebSocketState]::Open) {
      $套接字.Abort()
    }
    $套接字.Dispose()
  }
}

try {
  $原版程序 = 查找原版Codex
  $应用标识 = 取得应用标识 -程序路径 $原版程序
  准备应用激活器
  $样式文件 = 查找皮肤样式
  $样式内容 = [IO.File]::ReadAllText($样式文件, [Text.Encoding]::UTF8)
  if ($样式内容 -notmatch "animal-island-runtime-skin" -or $样式内容 -notmatch "data:image/") {
    throw "皮肤文件不完整，请重新安装主题包。"
  }

  if ($SelfTest) {
    Write-Output "SELF_TEST_OK"
    Write-Output "CODEX=$原版程序"
    Write-Output "APP_ID=$应用标识"
    Write-Output "SKIN=$样式文件"
    exit 0
  }

  if (@(Get-Process -Name "ChatGPT" -ErrorAction SilentlyContinue).Count -gt 0) {
    if (-not $安静等待) {
      显示提示 -内容 "狸克手机皮肤已经准备好。请正常关闭当前 Codex；关闭后会自动以原版 Codex 加皮肤的方式重新打开。"
    }
    while (@(Get-Process -Name "ChatGPT" -ErrorAction SilentlyContinue).Count -gt 0) {
      Start-Sleep -Milliseconds 700
    }
  }

  $端口 = 取得空闲端口
  $参数 = @(
    "--remote-debugging-port=$端口",
    "--remote-debugging-address=127.0.0.1",
    "--remote-allow-origins=http://localhost"
  )
  $原版进程编号 = [CodexAnimalIsland.ApplicationLauncher]::Launch($应用标识, ($参数 -join " "))
  写日志 "已通过 Windows 应用入口启动原版 Codex，进程=$原版进程编号，皮肤端口=$端口，等待界面加载。"

  $接口 = "http://127.0.0.1:$端口/json/list"
  $启动截止 = (Get-Date).AddSeconds(60)
  $页面列表 = $null
  while ((Get-Date) -lt $启动截止) {
    try {
      $页面列表 = @(Invoke-RestMethod -Uri $接口 -Method Get -TimeoutSec 2)
      if ($页面列表.Count -gt 0) { break }
    } catch {
      Start-Sleep -Milliseconds 500
    }
  }
  if ($null -eq $页面列表 -or $页面列表.Count -eq 0) {
    throw "原版 Codex 已启动，但皮肤连接没有建立。请关闭 Codex 后从'Codex 狸克手机'入口重试。"
  }

  $注入脚本 = 生成注入脚本 -样式文本 $样式内容
  $已处理页面 = @{}
  while (@(Get-Process -Name "ChatGPT" -ErrorAction SilentlyContinue).Count -gt 0) {
    try {
      $页面列表 = @(Invoke-RestMethod -Uri $接口 -Method Get -TimeoutSec 2)
      foreach ($页面 in $页面列表) {
        if ($页面.type -ne "page" -or [string]::IsNullOrWhiteSpace([string]$页面.webSocketDebuggerUrl)) {
          continue
        }
        $页面键 = "{0}|{1}" -f $页面.id, $页面.webSocketDebuggerUrl
        if ($已处理页面.ContainsKey($页面键)) {
          continue
        }
        try {
          注入页面皮肤 -连接地址 ([string]$页面.webSocketDebuggerUrl) -注入脚本 $注入脚本
          $已处理页面[$页面键] = $true
          写日志 "皮肤已覆盖页面：$($页面.title)"
        } catch {
          写日志 "页面暂未注入，稍后重试：$($_.Exception.Message)"
        }
      }
    } catch {
      写日志 "界面列表暂不可用：$($_.Exception.Message)"
    }
    Start-Sleep -Milliseconds 900
  }
} catch {
  写日志 "启动失败：$($_.Exception.Message)"
  if ($SelfTest) {
    Write-Error $_.Exception.Message
    exit 1
  }
  显示提示 -内容 $_.Exception.Message -标题 "Codex 狸克手机启动失败"
  exit 1
}
