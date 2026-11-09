// 使い方: node record.js <出力フォルダ> <秒数の JSON または "dry">
// 台本の各場面を、ナレーションの長さに合わせてアプリを操作しながら録画する。
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const out = process.argv[2];
const mode = process.argv[3] || 'dry';
const here = __dirname;
const script = JSON.parse(fs.readFileSync(path.join(here, 'script.json'), 'utf8'));
const durations = mode === 'dry' ? {} : JSON.parse(fs.readFileSync(mode, 'utf8'));
const dry = mode === 'dry';

// アプリ内の座標（390x844）→ ステージ上の座標
const P = (x, y) => [110 + x * 0.8, 18 + y * 0.8];

(async () => {
  const browser = await chromium.launch();
  const context = await browser.newContext({
    viewport: { width: 1280, height: 720 },
    deviceScaleFactor: 1,
    ...(dry ? {} : { recordVideo: { dir: out, size: { width: 1280, height: 720 } } }),
  });
  // 録画用のブラウザに、加速度センサーの使用を許可しておく（実機では iPhone の許可ダイアログにあたる）
  await context.grantPermissions(['accelerometer', 'gyroscope'], { origin: 'http://localhost:8780' });
  const page = await context.newPage();
  const t0 = Date.now();
  const errs = [];
  page.on('pageerror', (e) => errs.push(e.message));
  await page.goto('http://localhost:8780/stage.html', { waitUntil: 'networkidle' });
  await page.waitForTimeout(6000); // アプリの読み込み
  const app = page.frames().find((f) => f !== page.mainFrame());

  const click = async (x, y) => { const [px, py] = P(x, y); await page.mouse.click(px, py); };
  const wheel = async (x, y, dy) => { const [px, py] = P(x, y); await page.mouse.move(px, py); await page.mouse.wheel(0, dy); };
  const shot = async (name) => { if (dry) await page.screenshot({ path: path.join(out, name + '.png') }); };
  // 加速度センサーの値を送る（スマホを振ったときと同じイベント）
  const shake = async (times) => {
    for (let i = 0; i < times; i++) {
      await app.evaluate(() => window.dispatchEvent(new DeviceMotionEvent('devicemotion', {
        accelerationIncludingGravity: { x: 28, y: 6, z: 9.8 },
      })));
      await page.waitForTimeout(190);
    }
  };

  const actions = {
    opening: async () => {},
    home: async () => { await click(195, 755); },
    shake: async (d) => {
      await click(195, 515);
      await page.waitForTimeout(Math.max(1500, d - 2600));
      await shake(12);
    },
    cheers: async () => {},
    calendar: async () => {
      await page.mouse.click(...P(195, 90)); // シートの外をタップして閉じる
      await page.waitForTimeout(700);
      await click(146, 805);
      await page.waitForTimeout(1500);
      await click(331, 275); // 11/7（乾杯した日）
    },
    friends: async () => { await click(244, 805); },
    profile: async (d) => {
      await click(341, 805);
      await page.waitForTimeout(1500);
      await click(54, 95);
      await page.waitForTimeout(900);
      await shot('profile-sheet');
      const [chooser] = await Promise.all([page.waitForEvent('filechooser'), click(195, 733)]);
      await chooser.setFiles(path.join(here, 'avatar.png'));
      await page.waitForTimeout(Math.max(1500, d * 0.3));
      await wheel(195, 500, 640);
      await page.waitForTimeout(900);
      await shot('profile-scrolled');
      await click(195, SCAN_Y);
      await page.waitForTimeout(2200);
      await click(195, SCAN_Y);
    },
    badges: async () => { await wheel(195, 400, -380); },
    ideas: async () => { await click(49, 805); },
    tech: async () => {},
    closing: async () => {},
  };

  const timeline = [];
  for (const seg of script) {
    const d = (durations[seg.id] || 4) * 1000 + 600; // 場面の後に少し間をあける
    const start = Date.now();
    timeline.push({ id: seg.id, start: (start - t0) / 1000 });
    await page.evaluate((s) => window.showSegment(s), seg);
    await actions[seg.id](d);
    const left = d - (Date.now() - start);
    if (left > 0) await page.waitForTimeout(left);
    await shot(seg.id);
  }
  timeline.push({ id: 'end', start: (Date.now() - t0) / 1000 });

  const video = dry ? null : await page.video().path();
  await context.close();
  await browser.close();
  fs.writeFileSync(path.join(out, 'timeline.json'), JSON.stringify({ timeline, video }, null, 2));
  console.log('ERRORS', JSON.stringify(errs));
})().catch((e) => { console.error(e); process.exit(1); });

// プロフィールを 640px 下へ動かしたときの「袋の写真から登録する」の高さ（下見の画像で確認）
var SCAN_Y = 481;
