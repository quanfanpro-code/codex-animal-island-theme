import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { test } from "node:test";
import { resolve } from "node:path";

const 项目目录 = resolve(import.meta.dirname, "..");

test("公开仓库包含许可证、可编辑源码和六项锁定素材", () => {
  for (const 相对路径 of [
    "LICENSE",
    "NOTICE.md",
    "skin/skin-template.css",
    "tools/build-runtime-mod.ps1",
  ]) {
    assert.ok(existsSync(resolve(项目目录, 相对路径)), `缺少 ${相对路径}`);
  }

  const 来源锁 = JSON.parse(readFileSync(resolve(项目目录, "sources.lock.json"), "utf8"));
  assert.equal(来源锁.files.length, 6);
  assert.ok(来源锁.files.every((条目) => existsSync(resolve(项目目录, 条目.local))));
});

test("构建结果嵌入网站原素材并保留真实动森界面规则", () => {
  execFileSync("pwsh.exe", [
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    resolve(项目目录, "tools/build-runtime-mod.ps1"),
  ], {
    cwd: 项目目录,
    stdio: "pipe",
  });

  const 样式 = readFileSync(resolve(项目目录, "dist/runtime-skin.css"), "utf8");
  assert.match(样式, /data:image\/jpeg;base64,/);
  assert.match(样式, /data:image\/svg\+xml;base64,/);
  assert.match(样式, /data:image\/png;base64,/);
  assert.doesNotMatch(样式, /url\(["']?\.\//);
  assert.match(样式, /\.app-shell-left-panel/);
  assert.match(样式, /\.composer-surface-chrome/);
  assert.match(样式, /\.sidebar-item/);
  assert.match(样式, /animal-island-runtime-skin/);
});

test("外挂始终连接商店原版并复用原用户数据", () => {
  const 启动器 = readFileSync(resolve(项目目录, "runtime/启动狸克手机Codex.ps1"), "utf8");
  assert.match(启动器, /Get-AppxPackage/);
  assert.match(启动器, /OpenAI\.Codex_/);
  assert.match(启动器, /ChatGPT\.exe/);
  assert.match(启动器, /--remote-debugging-address=127\.0\.0\.1/);
  assert.doesNotMatch(启动器, /--user-data-dir/);
  assert.doesNotMatch(启动器, /WindowsApps[^\r\n]*(Set-Content|WriteAllText|Copy-Item)/i);
});

test("页面刷新或新开窗口后会自动补回皮肤", () => {
  const 启动器 = readFileSync(resolve(项目目录, "runtime/启动狸克手机Codex.ps1"), "utf8");
  assert.match(启动器, /Page\.addScriptToEvaluateOnNewDocument/);
  assert.match(启动器, /MutationObserver/);
  assert.match(启动器, /setInterval/);
});

test("安装包不依赖 Node 或本机固定用户名", () => {
  const 安装器 = readFileSync(resolve(项目目录, "installer/安装狸克手机主题.ps1"), "utf8");
  const 启动器 = readFileSync(resolve(项目目录, "runtime/启动狸克手机Codex.ps1"), "utf8");
  const 静默入口 = readFileSync(resolve(项目目录, "启动狸克手机Codex.vbs"), "utf8");
  const 安装入口 = readFileSync(resolve(项目目录, "安装狸克手机主题.cmd"), "utf8");
  assert.match(安装器, /LOCALAPPDATA/);
  assert.match(安装器, /Codex 狸克手机\.lnk/);
  assert.doesNotMatch(`${安装器}\n${启动器}`, /C:\\Users\\[^\\]+|Program Files\\WindowsApps\\OpenAI\.Codex/);
  assert.doesNotMatch(`${安装器}\n${启动器}`, /node(?:\.exe)?/i);
  assert.match(静默入口, /pwsh\.exe/i);
  assert.match(静默入口, /runtime\\launch\.ps1/i);
  assert.match(安装入口, /pwsh\.exe/i);
  assert.doesNotMatch(`${静默入口}\n${安装入口}`, /powershell\.exe/i);
  assert.notDeepEqual([...readFileSync(resolve(项目目录, "启动狸克手机Codex.vbs"))].slice(0, 3), [0xef, 0xbb, 0xbf]);
  assert.ok([...readFileSync(resolve(项目目录, "启动狸克手机Codex.vbs"))].every((字节) => 字节 <= 0x7f));
  assert.ok(existsSync(resolve(项目目录, "runtime/launch.ps1")));
});

test("绿色是主界面底色且装饰不会覆盖侧栏标题", () => {
  const 模板 = readFileSync(resolve(项目目录, "skin/skin-template.css"), "utf8");
  assert.match(模板, /--nook-main-green:\s*#72c99a/);
  assert.match(模板, /background-image:\s*url\("__MENU_BG_SVG__"\)/);
  assert.match(模板, /--nook-sidebar-cream:\s*#f8f4e8/);
  assert.match(模板, /margin:\s*3px 30px 3px 12px/);
  assert.match(模板, /width:\s*auto/);
  assert.match(模板, /background:\s*var\(--nook-sidebar-cream\)/);
  assert.match(模板, /background-position:\s*left 10px center/);
  assert.match(模板, /sidebar-item \.sidebar-item/);
  assert.match(模板, /bg-token-dropdown-background/);
  assert.match(模板, /div\.sidebar-item\.group:not\(\[aria-current="page"\]\)/);
  assert.match(模板, /background:\s*transparent/);
  assert.match(模板, /sidebar-item:has\(> \.sidebar-item\)/);
  assert.match(模板, /margin:\s*0 8px 0 0/);
  assert.match(模板, /border-radius:\s*14px/);
  assert.match(模板, /border-radius:\s*14px 14px 0 0/);
  assert.match(模板, /\[data-app-shell-main-surface="default"\][\s\S]*background-color:\s*var\(--nook-main-green\)/);
  assert.doesNotMatch(模板, /app-shell-left-panel::before/);
  assert.doesNotMatch(模板, /h1::before|h2::before/);
  assert.doesNotMatch(模板, /button\[class\*="primary"\]/);
  assert.match(模板, /composer-surface-chrome button span/);
});

test("便携运行自检能够找到原版 Codex 且不启动新窗口", () => {
  const 输出 = execFileSync("pwsh.exe", [
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    resolve(项目目录, "runtime/启动狸克手机Codex.ps1"),
    "-SelfTest",
  ], { cwd: 项目目录, encoding: "utf8" });
  assert.match(输出, /SELF_TEST_OK/);
});
