// 把 index.html 逐格截圖，再用 ffmpeg 輸出影片（片頭會用 sfx.py 合成音效）
// 用法：node render.mjs            （輸出 jobs.json 裡全部）
//       node render.mjs intro      （只輸出名稱含 intro 的）
//       node render.mjs --frames 0,1.2,2.5   （只截幾張靜態圖檢查用）
//       node render.mjs --check   （只檢查瀏覽器和字型）
import { chromium } from 'playwright-core';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const dir = path.dirname(fileURLToPath(import.meta.url));
const FPS = 60;
// Windows 上的 Python 指令通常叫 python，其他系統叫 python3；也可以用環境變數 PYTHON 指定
const PY = process.env.PYTHON || (process.platform === 'win32' ? 'python' : 'python3');

// 在 Playwright 下載過的瀏覽器資料夾裡找 Chromium（新版號優先）
function findCachedChromium() {
  const home = os.homedir();
  const roots = [
    process.env.PLAYWRIGHT_BROWSERS_PATH,
    path.join(home, 'Library/Caches/ms-playwright'),
    path.join(home, '.cache/ms-playwright'),
    process.env.LOCALAPPDATA && path.join(process.env.LOCALAPPDATA, 'ms-playwright'),
  ].filter(Boolean);
  const app = 'Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing';
  const rel = [`chrome-mac-arm64/${app}`, `chrome-mac-x64/${app}`, `chrome-mac/${app}`,
    'chrome-mac/Chromium.app/Contents/MacOS/Chromium',
    'chrome-win64/chrome.exe', 'chrome-win/chrome.exe', 'chrome-linux64/chrome', 'chrome-linux/chrome'];
  const found = [];
  for (const root of roots) {
    if (!fs.existsSync(root)) continue;
    const dirs = fs.readdirSync(root).filter(d => /^chromium-\d+$/.test(d))
      .sort((a, b) => +b.split('-')[1] - +a.split('-')[1]);
    for (const d of dirs) for (const r of rel) {
      const p = path.join(root, d, r);
      if (fs.existsSync(p)) found.push(p);
    }
  }
  return found;
}

// 依序嘗試：環境變數 CHROME 指定的 → 下載過的最新版 → Playwright 內建 → 電腦上的 Google Chrome
async function launchBrowser() {
  const tries = [];
  if (process.env.CHROME) tries.push(['環境變數 CHROME', { executablePath: process.env.CHROME }]);
  // 先用下載過的最新版（舊版在複雜畫面上可能非常慢），再試內建版和 Google Chrome
  for (const p of findCachedChromium()) tries.push([p, { executablePath: p }]);
  tries.push(['Playwright 內建 Chromium', {}]);
  tries.push(['Google Chrome', { channel: 'chrome' }]);
  for (const [label, opts] of tries) {
    try {
      const b = await chromium.launch(opts);
      console.log(`使用瀏覽器：${label}`);
      return b;
    } catch { /* 換下一個 */ }
  }
  console.error('找不到可以用的瀏覽器。請安裝 Google Chrome，或在這個資料夾執行：\n  npx playwright-core install chromium');
  process.exit(1);
}

const args = process.argv.slice(2);
const fi = args.indexOf('--frames');
const stills = fi >= 0 ? args[fi + 1].split(',').map(Number) : null;
const filter = args.find((a, i) => !a.startsWith('--') && (fi < 0 || i !== fi + 1));

const jobs = JSON.parse(fs.readFileSync(path.join(dir, 'jobs.json'), 'utf8'))
  .filter(j => !filter || j.name.includes(filter));
const outDir = path.join(dir, 'output');
fs.mkdirSync(outDir, { recursive: true });

const browser = await launchBrowser();
const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });

// --check：只確認瀏覽器能開、字型讀得到，不輸出任何東西（一鍵安裝腳本會用到）
if (args.includes('--check')) {
  await page.setContent('<p>測試</p>');
  // 用畫布量字寬：有裝這個字型時，寬度會跟備用字型不一樣
  const fontOk = await page.evaluate(name => {
    const c = document.createElement('canvas').getContext('2d');
    const w = f => { c.font = f; return c.measureText('學園好食 ABC').width; };
    return w(`900 100px "${name}", monospace`) !== w('900 100px monospace');
  }, process.env.CHECK_FONT || 'Noto Sans TC');
  await browser.close();
  console.log(fontOk ? '字型：Noto Sans TC 正常' : '字型：找不到 Noto Sans TC');
  process.exit(fontOk ? 0 : 2);
}

for (const job of jobs) {
  const url = pathToFileURL(path.join(dir, job.page || 'index.html'));
  // jobs.json 裡除了 name／page／note 以外的欄位，全部當成網址參數傳給頁面
  const params = Object.entries(job).filter(([k]) => !['name', 'page', 'note'].includes(k)).map(([k, v]) => [k, String(v)]);
  url.search = new URLSearchParams([['render', '1'], ...params]);
  await page.goto(url.href);
  await page.waitForFunction(() => window.READY === true);
  const dur = await page.evaluate(() => window.DUR);

  if (stills) {
    for (const t of stills) {
      await page.evaluate(t => window.renderAt(t), t);
      await page.screenshot({ path: path.join(outDir, `${job.name}_t${t}.png`), omitBackground: true });
    }
    console.log(`${job.name}: 截了 ${stills.length} 張`);
    continue;
  }

  const fdir = path.join(outDir, 'frames', job.name);
  fs.rmSync(fdir, { recursive: true, force: true });
  fs.mkdirSync(fdir, { recursive: true });
  const n = Math.ceil(dur * FPS);
  for (let i = 0; i <= n; i++) {
    const shot = async ms => {
      await page.evaluate(t => window.renderAt(t), Math.min(i / FPS, dur));
      await page.screenshot({ path: path.join(fdir, `${String(i).padStart(4, '0')}.png`), omitBackground: true, timeout: ms });
    };
    // 瀏覽器偶爾會卡在某一格截不到圖：重新載入頁面再試，最多 3 次
    for (let tries = 1; ; tries++) {
      try { await shot(tries < 3 ? 30000 : 120000); break; } catch (e) {
        if (tries >= 3 || e.name !== 'TimeoutError') throw e;
        console.log(`${job.name}: 第 ${i} 格卡住，重新載入再試`);
        await page.goto(url.href);
        await page.waitForFunction(() => window.READY === true);
      }
    }
  }
  const input = path.join(fdir, '%04d.png');
  // 有音效清單的畫面（片頭）就合成一條音軌一起封裝
  const sfx = await page.evaluate(() => window.SFX || []);
  const hasSfx = Array.isArray(sfx) ? sfx.length > 0 : (sfx.events || []).length > 0;
  const audio = [];
  if (hasSfx) {
    const ev = path.join(fdir, 'sfx.json'), wav = path.join(outDir, `${job.name}.wav`);
    fs.writeFileSync(ev, JSON.stringify(sfx));
    execFileSync(PY, [path.join(dir, 'sfx.py'), ev, wav, String(dur)]);
    audio.push('-i', wav);
  }
  // 全版背景（頁面設定 window.OPAQUE）不需要透明檔：只輸出高畫質 MP4，音效直接封進去
  const opaque = await page.evaluate(() => window.OPAQUE === true);
  const aMov = audio.length ? ['-map', '0:v', '-map', '1:a', '-c:a', 'pcm_s16le', '-shortest'] : [];
  const aMp4 = audio.length ? ['-map', '[v]', '-map', '1:a', '-c:a', 'aac', '-b:a', opaque ? '256k' : '192k', '-shortest'] : ['-map', '[v]'];
  if (!opaque) {
    // 帶透明通道的 ProRes 4444，放在 DaVinci 影片軌上方用
    execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-framerate', String(FPS), '-i', input, ...audio,
      '-c:v', 'prores_ks', '-profile:v', '4444', '-pix_fmt', 'yuva444p10le', '-vendor', 'apl0', ...aMov,
      path.join(outDir, `${job.name}.mov`)]);
  }
  // MP4（透明處補黑）；全版的用更高的畫質設定
  const quality = opaque ? ['-crf', '12', '-preset', 'slow', '-profile:v', 'high', '-tune', 'animation'] : ['-crf', '16'];
  execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-framerate', String(FPS), '-i', input, ...audio,
    '-filter_complex', `color=black:s=1920x1080:r=${FPS}[bg];[bg][0:v]overlay=shortest=1,format=yuv420p[v]`,
    '-c:v', 'libx264', ...quality, '-movflags', '+faststart', ...aMp4, path.join(outDir, `${job.name}.mp4`)]);
  if (opaque) for (const ext of ['mov', 'wav']) fs.rmSync(path.join(outDir, `${job.name}.${ext}`), { force: true });
  fs.rmSync(fdir, { recursive: true, force: true });
  console.log(`${job.name}: ${n + 1} 格，${dur}s → output/${job.name}${opaque ? '.mp4（全版，只留 MP4）' : '.mov / .mp4'}`);
}

await browser.close();
