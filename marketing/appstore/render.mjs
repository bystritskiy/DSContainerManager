import { readFile, mkdir } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { chromium } from "playwright";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "../..");
const templateUrl = pathToFileURL(path.join(__dirname, "template.html")).href;
const shotsPath = path.join(__dirname, "shots.json");
const outputDir = path.join(repoRoot, "screenshots/appstore");
const iconUrl = pathToFileURL(path.join(repoRoot, "docs/assets/appicon-180.png")).href;

const defaultCallouts = new Map([
  ["dashboard", ["Live NAS metrics", "Container health at a glance"]],
  ["containers", ["Tap to inspect", "Popular self-hosted apps"]],
  ["details", ["Runtime details", "Ports, volumes and env"]],
  ["logs", ["Searchable logs", "stdout and stderr in context"]],
  ["resources", ["Per-container charts", "Catch spikes early"]],
  ["projects", ["Compose aware", "Whole stack visibility"]],
  ["monitor", ["Rolling history", "System load over time"]],
]);

const shots = JSON.parse(await readFile(shotsPath, "utf8"));
await mkdir(outputDir, { recursive: true });

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({
  viewport: { width: 1320, height: 2868 },
  deviceScaleFactor: 1,
});

try {
  for (const shot of shots) {
    const sourcePath = path.resolve(__dirname, shot.source);
    const outputPath = path.join(outputDir, `${shot.id}.png`);
    const payload = {
      ...shot,
      source: pathToFileURL(sourcePath).href,
      icon: iconUrl,
      callouts: shot.callouts ?? defaultCallouts.get(shot.id),
    };

    await page.goto(templateUrl);
    await page.evaluate((data) => window.renderShot(data), payload);
    await page.waitForFunction(() => {
      const images = [...document.images];
      return images.length > 0 && images.every((image) => image.complete && image.naturalWidth > 0);
    });
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: outputPath, fullPage: false });
    console.log(`rendered ${path.relative(repoRoot, outputPath)}`);
  }
} finally {
  await browser.close();
}
