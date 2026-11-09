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
    // Wider than Apple's 1646×661 template: the iPhone product page shows roughly the
    // middle 70% of the width (checked in App Store Connect's device preview), and a
    // larger line reads better there. Height stays within the template's band.
    safe: { w: 2500, h: 661, x: (3840 - 2500) / 2, y: (1646 - 661) / 2 },
    // The header is small on iPhone and its top corners sit under the Back and
    // Share buttons, so it carries only the brand and one large line — no phones.
    scale: 190,
    sub: null,
    phones: [],
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
    await page.evaluate((data) => window.renderCreative(data), { title, sub, icon, ...asset });
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
