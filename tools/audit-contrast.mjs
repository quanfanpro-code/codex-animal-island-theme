const port = Number(process.argv[2]);
const pages = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
const targets = pages.filter((page) => page.type === "page" && page.url.startsWith("app://-/index.html"));

function evaluate(page, expression) {
  return new Promise((resolve, reject) => {
    const socket = new WebSocket(page.webSocketDebuggerUrl);
    socket.addEventListener("error", reject, { once: true });
    socket.addEventListener("open", () => {
      const listener = (event) => {
        const message = JSON.parse(event.data);
        if (message.id !== 1) return;
        socket.close();
        if (message.error) reject(new Error(message.error.message));
        else resolve(message.result.result.value);
      };
      socket.addEventListener("message", listener);
      socket.send(JSON.stringify({ id: 1, method: "Runtime.evaluate", params: { expression, returnByValue: true } }));
    }, { once: true });
  });
}

const expression = `(() => {
  const parse = (value) => {
    const match = value.match(/rgba?\\(([^)]+)\\)/);
    if (match) {
      const parts = match[1].split(/[ ,/]+/).map(Number);
      return [parts[0], parts[1], parts[2], Number.isFinite(parts[3]) ? parts[3] : 1];
    }
    const srgb = value.match(/color\\(srgb\\s+([\\d.]+)\\s+([\\d.]+)\\s+([\\d.]+)(?:\\s*\\/\\s*([\\d.]+))?\\)/);
    if (srgb) return [Number(srgb[1]) * 255, Number(srgb[2]) * 255, Number(srgb[3]) * 255, srgb[4] ? Number(srgb[4]) : 1];
    return [0, 0, 0, 0];
  };
  const blend = (top, bottom) => {
    const alpha = top[3] + bottom[3] * (1 - top[3]);
    if (alpha === 0) return [0, 0, 0, 0];
    return [0, 1, 2].map((i) => (top[i] * top[3] + bottom[i] * bottom[3] * (1 - top[3])) / alpha).concat(alpha);
  };
  const luminance = (color) => {
    const channels = color.slice(0, 3).map((value) => {
      const channel = value / 255;
      return channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4;
    });
    return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722;
  };
  const ratio = (a, b) => {
    const first = luminance(a);
    const second = luminance(b);
    return (Math.max(first, second) + 0.05) / (Math.min(first, second) + 0.05);
  };
  const background = (element) => {
    const chain = [];
    for (let node = element; node; node = node.parentElement) chain.push(node);
    let result = [255, 255, 255, 1];
    for (const node of chain.reverse()) result = blend(parse(getComputedStyle(node).backgroundColor), result);
    return result;
  };
  const opacity = (element) => {
    let result = 1;
    for (let node = element; node; node = node.parentElement) result *= Number(getComputedStyle(node).opacity || 1);
    return result;
  };
  const directText = (element) => [...element.childNodes]
    .filter((node) => node.nodeType === Node.TEXT_NODE)
    .map((node) => node.textContent.trim())
    .filter(Boolean)
    .join(' ');

  return [...document.querySelectorAll('body *')].map((element) => {
    const text = directText(element);
    if (!text) return null;
    const rect = element.getBoundingClientRect();
    const style = getComputedStyle(element);
    const effectiveOpacity = opacity(element);
    if (rect.width < 1 || rect.height < 1 || rect.bottom < 0 || rect.top > innerHeight ||
        rect.right < 0 || rect.left > innerWidth || style.visibility === 'hidden' || style.display === 'none' || effectiveOpacity < 0.1) return null;
    const bg = background(element);
    const fill = parse(style.webkitTextFillColor);
    const rawFg = fill[3] > 0 ? fill : parse(style.color);
    rawFg[3] *= effectiveOpacity;
    const fg = blend(rawFg, bg);
    const contrast = ratio(fg, bg);
    const size = Number.parseFloat(style.fontSize);
    const weight = Number.parseInt(style.fontWeight, 10) || 400;
    const threshold = size >= 24 || (size >= 18.66 && weight >= 700) ? 3 : 4.5;
    if (contrast >= threshold) return null;
    return {
      contrast: Number(contrast.toFixed(2)), threshold, text: text.slice(0, 100),
      tag: element.tagName, className: typeof element.className === 'string' ? element.className.slice(0, 240) : '',
      parentClass: typeof element.parentElement?.className === 'string' ? element.parentElement.className.slice(0, 240) : '',
      color: style.color, background: style.backgroundColor, effectiveBackground: bg.map((value) => Number(value.toFixed(1))),
      fontSize: style.fontSize, opacity: effectiveOpacity, rect: { x: rect.x, y: rect.y, width: rect.width, height: rect.height }
    };
  }).filter(Boolean).sort((a, b) => a.contrast - b.contrast);
})()`;

const result = [];
for (const page of targets) result.push({ url: page.url, failures: await evaluate(page, expression) });
console.log(JSON.stringify(result, null, 2));
