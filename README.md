# Codex Pet Usage Bubble

A tiny macOS companion overlay for custom Codex pets.

It keeps the native Codex pet visible and shows a pixel-art speech bubble above it on hover. The bubble contains:

- a 5-hour Codex usage meter
- a weekly usage meter
- a small usage-state character sprite
- click-through transparent overlay behavior
- drag-follow behavior while the native pet is being moved

The overlay does not patch Codex. It reads the native pet position from:

```text
~/.codex/.codex-global-state.json
```

Usage is synced from the latest Codex session JSONL `rate_limits.primary.used_percent` and `rate_limits.secondary.used_percent`.

## Requirements

- macOS
- Codex desktop app
- Swift toolchain / Xcode command line tools
- Node.js
- A custom pet installed at `~/.codex/pets/<pet-id>`

## Install

Choose the pet id/name of your installed Codex custom pet. In the examples below, replace `your-pet-name` with your pet's folder name under `~/.codex/pets/`.

```sh
CODEX_PET_ID=your-pet-name ./scripts/install.sh
```

For example, if your pet folder is `my-pet`:

```sh
CODEX_PET_ID=my-pet ./scripts/install.sh
```

This installs files under:

```text
~/.codex/pets/<pet-id>/usage-overlay
```

and creates LaunchAgents for:

- the hover bubble host
- the usage sync provider

## Preview

```sh
CODEX_PET_ID=your-pet-name ./scripts/run-preview.sh
```

Preview mode runs the bubble with `--always-show` so you can style or inspect it without hovering.

## Usage Data

The host reads:

```text
~/.codex/pets/<pet-id>/usage-overlay/usage.json
```

Expected shape:

```json
{
  "percent": 22,
  "usedPercent": 78,
  "secondaryUsedPercent": 42
}
```

`percent` is remaining 5-hour usage. `secondaryUsedPercent` is weekly used percentage; the host displays weekly remaining percentage.

Manual test:

```sh
node scripts/set-percent.mjs 83
```

One-shot sync from Codex logs:

```sh
node scripts/sync-codex-usage.mjs --once
```

## Custom Sprites

Replace the PNG files in `assets/` with your own transparent-background sprites:

```text
assets/state1.png  # 100%-75% remaining
assets/state2.png  # 74%-50% remaining
assets/state3.png  # 49%-25% remaining
assets/state4.png  # 24%-1% remaining
assets/state5.png  # 0% remaining
```

Keep the filenames the same, then reinstall:

```sh
CODEX_PET_ID=your-pet-name ./scripts/install.sh
```

## Uninstall

```sh
CODEX_PET_ID=your-pet-name ./scripts/uninstall.sh
```

## Notes

- The overlay uses global mouse events for drag-follow. If macOS prompts for accessibility/input monitoring permissions, allow it for the host process.
- The bubble window is transparent, floating, and click-through.
- Assets are included as PNGs in `assets/`.
