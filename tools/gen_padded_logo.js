/*
  Generate a padded square logo for Android 12 splash compatibility.
  Usage:
    1) npm i sharp
    2) node tools/gen_padded_logo.js assets/images/square_logo.png assets/images/square_logo_padded.png --bg #EFE0FF --scale 0.72

  - --bg: background color (hex), default #EFE0FF
  - --scale: content scale (0.60 - 0.85 typical). 0.72 = 72% of canvas size
*/

const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

function getArg(name, fallback) {
  const idx = process.argv.indexOf(name);
  if (idx >= 0 && process.argv[idx + 1]) return process.argv[idx + 1];
  return fallback;
}

async function main() {
  const input = process.argv[2];
  const output = process.argv[3];
  if (!input || !output) {
    console.error('Usage: node tools/gen_padded_logo.js <input_png> <output_png> [--bg #EFE0FF] [--scale 0.72]');
    process.exit(1);
  }
  const bg = getArg('--bg', '#EFE0FF');
  const scale = parseFloat(getArg('--scale', '0.72'));

  const size = 432; // Android 12 recommended square icon area
  const content = Math.round(size * scale);

  // Read input, resize to content, composite center on square canvas
  const buf = await sharp(input)
    .resize({ width: content, height: content, fit: 'contain' })
    .png()
    .toBuffer();

  await sharp({ create: { width: size, height: size, channels: 4, background: bg } })
    .composite([{ input: buf, left: Math.round((size - content) / 2), top: Math.round((size - content) / 2) }])
    .png()
    .toFile(output);

  console.log(`✅ Generated padded logo at ${output} (bg=${bg}, scale=${scale})`);
}

main().catch((e) => { console.error(e); process.exit(1); });

