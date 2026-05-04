import { mkdir, readdir, readFile, stat, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { homedir } from "node:os";

const petId = process.env.CODEX_PET_ID;
const codexHome = process.env.CODEX_HOME ?? join(homedir(), ".codex");
const sessionsDir = join(codexHome, "sessions");
const overlayDirFromEnv = process.env.USAGE_BUBBLE_OVERLAY_DIR;
if (!overlayDirFromEnv && !petId) {
  console.error("Set CODEX_PET_ID to your installed Codex pet folder name.");
  process.exit(1);
}

const installedUsageDir = overlayDirFromEnv ?? join(codexHome, "pets", petId, "usage-overlay");
const installedUsagePath = join(installedUsageDir, "usage.json");
const pollMs = Number(process.env.USAGE_BUBBLE_POLL_MS ?? 15000);
const once = process.argv.includes("--once");

async function walkJsonlFiles(dir) {
  const entries = await readdir(dir, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    const fullPath = join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...await walkJsonlFiles(fullPath));
    } else if (entry.isFile() && entry.name.endsWith(".jsonl")) {
      const info = await stat(fullPath);
      files.push({ path: fullPath, mtimeMs: info.mtimeMs, size: info.size });
    }
  }

  return files;
}

function parseRateLimitLine(line) {
  if (!line.includes('"rate_limits"')) return null;

  try {
    const event = JSON.parse(line);
    const rateLimits = event?.payload?.rate_limits;
    const primary = rateLimits?.primary;
    const used = Number(primary?.used_percent);
    if (!Number.isFinite(used)) return null;

    return {
      usedPercent: clamp(used),
      percent: clamp(100 - used),
      windowMinutes: primary.window_minutes ?? null,
      resetsAt: primary.resets_at ?? null,
      secondaryUsedPercent: Number.isFinite(Number(rateLimits?.secondary?.used_percent))
        ? clamp(Number(rateLimits.secondary.used_percent))
        : null,
      sourceTimestamp: event.timestamp ?? null,
    };
  } catch {
    return null;
  }
}

async function latestRateLimit() {
  const files = (await walkJsonlFiles(sessionsDir))
    .sort((a, b) => b.mtimeMs - a.mtimeMs)
    .slice(0, 12);

  for (const file of files) {
    const text = await readFile(file.path, "utf8");
    const lines = text.trimEnd().split("\n");

    for (let i = lines.length - 1; i >= 0; i -= 1) {
      const rateLimit = parseRateLimitLine(lines[i]);
      if (rateLimit) {
        return { ...rateLimit, sourceFile: file.path };
      }
    }
  }

  return null;
}

async function syncOnce() {
  const rateLimit = await latestRateLimit();
  if (!rateLimit) {
    console.warn("No Codex rate limit record found yet.");
    return false;
  }

  const payload = {
    percent: Math.round(rateLimit.percent),
    usedPercent: Math.round(rateLimit.usedPercent),
    source: "codex-session-rate-limits",
    updatedAt: new Date().toISOString(),
    sourceTimestamp: rateLimit.sourceTimestamp,
    windowMinutes: rateLimit.windowMinutes,
    resetsAt: rateLimit.resetsAt,
    secondaryUsedPercent: rateLimit.secondaryUsedPercent,
  };

  const json = `${JSON.stringify(payload, null, 2)}\n`;
  await mkdir(installedUsageDir, { recursive: true });
  await writeFile(installedUsagePath, json);

  console.log(
    `Usage synced: ${payload.percent}% remaining (${payload.usedPercent}% used)`,
  );
  return true;
}

function clamp(value) {
  return Math.max(0, Math.min(100, value));
}

if (once) {
  await syncOnce();
} else {
  await syncOnce();
  setInterval(() => {
    syncOnce().catch((error) => {
      console.error(`Failed to sync usage: ${error.message}`);
    });
  }, pollMs);
}
