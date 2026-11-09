// Renders App Store "Creative Assets": the product page header (21:9) and the
// search results asset (3:2). Specs: https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications
// Safe areas follow Apple's templates — only what is inside them is guaranteed
// to be visible on every device, so copy lives there and phones are decoration.
import { mkdir } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { chromium } from "playwright";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "../..");
const templateUrl = pathToFileURL(path.join(__dirname, "creative.html")).href;
const outputDir = path.join(repoRoot, "screenshots/appstore/creative");
const shot = (name) => pathToFileURL(path.join(repoRoot, `screenshots/demo-${name}.png`)).href;
const icon = pathToFileURL(path.join(repoRoot, "docs/assets/appicon-512.png")).href;

const title = "Your Synology Docker,<br><em>in your pocket</em>";
const sub = "Containers, Compose stacks and live NAS metrics.";

const assets = [
  {
    id: "header-3840x1646",
    width: 3840,
    height: 1646,
    safe: { w: 1646, h: 661, x: (3840 - 1646) / 2, y: (1646 - 661) / 2 },
    scale: 108,
    phones: [
      { src: shot("containers"), x: 520, y: 330, h: 1500, rotate: -10, opacity: 0.85 },
      { src: shot("dashboard"), x: 940, y: 180, h: 1600, rotate: -4 },
      { src: shot("monitor"), x: 2900, y: 180, h: 1600, rotate: 4 },
      { src: shot("projects"), x: 3320, y: 330, h: 1500, rotate: 10, opacity: 0.85 },
    ],
  },
  {
    id: "search-3840x2560",
    width: 3840,
    height: 2560,
    safe: { w: 2168, h: 1030, x: (3840 - 2168) / 2, y: (2560 - 1030) / 2 },
    scale: 128,
    phones: [
      { src: shot("containers"), x: 80, y: 900, h: 2000, rotate: -10, opacity: 0.85 },
      { src: shot("dashboard"), x: 470, y: 700, h: 2150, rotate: -5 },
      { src: shot("monitor"), x: 3370, y: 700, h: 2150, rotate: 5 },
      { src: shot("projects"), x: 3760, y: 900, h: 2000, rotate: 10, opacity: 0.85 },
    ],
  },
];

await mkdir(outputDir, { recursive: true });
// Use the installed Chrome when Playwright's own browser has not been downloaded.
const browser = await chromium.launch({ headless: true }).catch(() => chromium.launch({ headless: true, channel: "chrome" }));

try {
  for (const asset of assets) {
    const page = await browser.newPage({ viewport: { width: asset.width, height: asset.height }, deviceScaleFactor: 1 });
    await page.goto(templateUrl);
    await page.evaluate((data) => window.renderCreative(data), { ...asset, title, sub, icon });
    await page.waitForFunction(() => [...document.images].every((i) => i.complete && i.naturalWidth > 0));
    await page.evaluate(() => document.fonts.ready);
    // App Store Connect rejects .jpg here despite the spec, and images must not carry
    // an alpha channel; an opaque page screenshot is written as RGB PNG.
    const outputPath = path.join(outputDir, `${asset.id}.png`);
    await page.screenshot({ path: outputPath, type: "png", omitBackground: false });
    console.log(`rendered ${path.relative(repoRoot, outputPath)}`);
    await page.close();
  }
} finally {
  await browser.close();
}
