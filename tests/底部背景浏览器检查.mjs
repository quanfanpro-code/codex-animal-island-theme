import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

// 在已通过皮肤入口启动的 Codex 中，用隔离的空白框架检查真实渲染结果。
// 用法：node tests/底部背景浏览器检查.mjs <本机调试端口>
const 端口 = Number(process.argv[2]);
assert.ok(Number.isInteger(端口) && 端口 > 0 && 端口 <= 65535, "请提供有效的本机调试端口");
const 页面列表 = await (await fetch(`http://127.0.0.1:${端口}/json/list`)).json();
const 页面 = 页面列表.find((项) => 项.type === "page" && 项.url === "app://-/index.html");
assert.ok(页面, "没有找到 Codex 主窗口");
const 样式 = readFileSync(new URL("../dist/runtime-skin.css", import.meta.url), "utf8");
const 套接字 = new WebSocket(页面.webSocketDebuggerUrl);
const 超时 = setTimeout(() => { console.error("浏览器检查超时"); process.exit(1); }, 10000);
try {
  const 响应 = await new Promise((resolve, reject) => {
    套接字.onerror = () => reject(new Error("连接 Codex 调试窗口失败"));
    套接字.onopen = () => 套接字.send(JSON.stringify({
      id: 1,
      method: "Runtime.evaluate",
      params: {
        returnByValue: true,
        expression: `(() => {
          const 框架 = document.createElement('iframe');
          框架.style.cssText = 'position:fixed;left:-10000px;width:800px;height:600px;pointer-events:none';
          框架.setAttribute('aria-hidden', 'true');
          document.body.appendChild(框架);
          try {
            const 文档 = 框架.contentDocument;
            文档.body.innerHTML = '<main data-app-shell-main-surface="default">' +
              '<div aria-hidden="true"><div id="新版渐变" aria-hidden="true" class="bg-gradient-to-t from-surface" style="height:32px;background-image:linear-gradient(to top,white,transparent)"></div></div>' +
              '<div data-thread-scroll-footer="true" style="position:relative;height:100px">' +
              '<div id="新版" aria-hidden="true" class="bg-surface" style="position:absolute;top:-32px;bottom:0;margin-top:32px;background:white"></div>' +
              '<div data-composer-surface-variant="default">输入框</div></div>' +
              '<div id="旧版" aria-hidden="true" class="bg-gradient-to-t from-surface via-surface" style="background:white"></div>' +
              '<div id="其他遮罩" aria-hidden="true" style="background:rgb(1,2,3)"></div></main>' +
              '<div data-thread-scroll-footer="true"><div id="主区外" aria-hidden="true" style="background:rgb(4,5,6)"></div></div>';
            const 样式节点 = 文档.createElement('style');
            样式节点.textContent = ${JSON.stringify(样式)};
            文档.head.appendChild(样式节点);
            const 读取 = (选择器) => {
              const 值 = 框架.contentWindow.getComputedStyle(文档.querySelector(选择器));
              return Object.fromEntries(['backgroundColor','backgroundImage','backgroundSize','backgroundPosition','backgroundAttachment','maskImage','marginTop','pointerEvents'].map(键 => [键, 值[键]]));
            };
            return { 主区:读取('main'), 新版渐变:读取('#新版渐变'), 新版:读取('#新版'), 旧版:读取('#旧版'), 输入框:读取('[data-composer-surface-variant]'), 其他遮罩:读取('#其他遮罩'), 主区外:读取('#主区外') };
          } finally { 框架.remove(); }
        })()`,
      },
    }));
    套接字.onmessage = ({ data }) => {
      const 消息 = JSON.parse(data);
      if (消息.id !== 1) return;
      if (消息.error || 消息.result.exceptionDetails) reject(new Error(JSON.stringify(消息)));
      else resolve(消息.result.result.value);
    };
  });
  for (const 名称 of ["新版渐变", "新版", "旧版"]) {
    const 结果 = 响应[名称];
    assert.equal(结果.backgroundColor, "rgb(114, 201, 154)", `${名称}遮罩不能露出白底`);
    assert.match(结果.backgroundImage, /^url\("data:image\/jpeg;base64,/);
    for (const 属性 of ["backgroundImage", "backgroundSize", "backgroundPosition", "backgroundAttachment"]) {
      assert.equal(结果[属性], 响应.主区[属性], `${名称}花纹须与主区对齐：${属性}`);
    }
    if (名称 !== "新版") assert.match(结果.maskImage, /linear-gradient.*32px/, `${名称}须保留正文淡出`);
  }
  assert.equal(响应.新版.maskImage, "none", "新版纯色层须完整覆盖输入框外围正文");
  assert.equal(响应.新版.marginTop, "32px", "新版须保留原有遮罩位置，由上方独立渐变层负责淡出");
  assert.equal(响应.输入框.backgroundColor, "rgb(248, 248, 240)");
  assert.equal(响应.其他遮罩.backgroundColor, "rgb(1, 2, 3)");
  assert.equal(响应.主区外.backgroundColor, "rgb(4, 5, 6)");
  console.log("BROWSER_CHECK_OK 新旧遮罩、花纹对齐、正文淡出、输入框及主区外边界均通过");
} finally {
  clearTimeout(超时);
  套接字.close();
}
