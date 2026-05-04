import { mkdir, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { homedir } from "node:os";

const here = dirname(fileURLToPath(import.meta.url));
const petId = process.env.CODEX_PET_ID;
const codexHome = process.env.CODEX_HOME ?? join(homedir(), ".codex");
const value = Number(process.argv[2]);
const overlayDirFromEnv = process.env.USAGE_BUBBLE_OVERLAY_DIR;

if (!Number.isFinite(value)) {
  console.error("Usage: node set-percent.mjs <percentRemaining>");
  process.exit(1);
}

if (!overlayDirFromEnv && !petId) {
  console.error("Set CODEX_PET_ID to your installed Codex pet folder name.");
  process.exit(1);
}

const percent = Math.max(0, Math.min(100, Math.round(value)));
const payload = `${JSON.stringify({ percent }, null, 2)}\n`;

const localUsagePath = join(here, "usage.json");
const installedUsageDir = overlayDirFromEnv ?? join(codexHome, "pets", petId, "usage-overlay");
const installedUsagePath = join(installedUsageDir, "usage.json");

await writeFile(localUsagePath, payload);

try {
  await mkdir(installedUsageDir, { recursive: true });
  await writeFile(installedUsagePath, payload);
} catch (error) {
  console.warn(`Could not update installed usage.json: ${error.message}`);
}

console.log(`Updated usage.json: ${percent}% remaining`);
