/*
  Center and pad a square logo for launcher icons.
  - Trims transparent edges, then places the content centered on 1024x1024 canvas.
  - Use --scale to control content size ratio (0.60..0.90). Default: 0.80

  Usage:
    npm i sharp
    node tools/center_icon.js assets/images/app_logo2.png assets/images/app_logo2_centered.png --bg #00000000 --scale 0.80
*/

const sharp = require('sharp');

function getArg(name, fallback) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? (process.argv[i + 1] || true) : fallback;
}

async function main() {
  const input = process.argv[2];
  const output = process.argv[3];
  if (!input || !output) {
    console.error('Usage: node tools/center_icon.js <input> <output> [--bg #00000000] [--scale 0.80]');
    process.exit(1);
  }
  let bg = getArg('--bg', null);
  if (!bg || bg === true || (typeof bg === 'string' && bg.startsWith('--'))) {
    bg = 'transparent'; // PowerShell strips #...; fallback to transparent
  }
  let scaleArg = getArg('--scale', '0.80');
  if (scaleArg === true || (typeof scaleArg === 'string' && scaleArg.startsWith('--'))) {
    scaleArg = '0.80';
  }
  const scale = Math.min(0.9, Math.max(0.6, parseFloat(scaleArg)));
  // Vertical offset in percent of canvas height (positive moves image DOWN)
  let yArg = getArg('--y', '0');
  if (yArg === true || (typeof yArg === 'string' && yArg.startsWith('--'))) {
    yArg = '0';
  }
  const yOffsetPct = parseFloat(yArg); // e.g. 0.04 = move 4% down

  const canvas = 1024;
  const content = Math.round(canvas * scale);

  // Trim transparent borders then resize
  const trimmed = await sharp(input).trim().png().toBuffer();
  const resized = await sharp(trimmed).resize({ width: content, height: content, fit: 'inside' }).png().toBuffer();

  const baseLeft = Math.round((canvas - content) / 2);
  const baseTop  = Math.round((canvas - content) / 2 + (yOffsetPct * canvas));
  await sharp({ create: { width: canvas, height: canvas, channels: 4, background: bg } })
    .composite([{ input: resized, left: baseLeft, top: baseTop }])
    .png()
    .toFile(output);

  console.log(`✅ Centered icon generated at ${output} (bg=${bg}, scale=${scale}, yOffset=${yOffsetPct})`);
}

main().catch((e) => { console.error(e); process.exit(1); });
