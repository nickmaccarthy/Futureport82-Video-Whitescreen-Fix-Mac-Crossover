# Futureport82 Video Fix for macOS (CrossOver)

A native macOS app that fixes the white-screen video issue in Futureport82 when running through CrossOver. It automates applying Windows Media Foundation patches to CrossOver Wine bottles.

Based on [HoodedDeath's MF Fix](https://github.com/HoodedDeath/mf-fix).

<p align="center">
  <img src="screenshots/setup-video-fast.gif" alt="FP82Fixer demo" width="600">
</p>

## Features

- **Native SwiftUI interface** — built for macOS 14 (Sonoma) and later
- **Bottle management** — list, create, and remove CrossOver bottles
- **One-click fix** — copies DLLs, sets Wine overrides, imports registry entries, registers DLLs
- **Add to bottle** — optionally registers the game as a bottle application
- **Real-time output** — streams fix progress to an in-app log
- **No dependencies** — zero third-party libraries, pure Swift + system frameworks

## Requirements

- macOS 14 (Sonoma) or later
- [CrossOver](https://www.codeweavers.com/crossover) installed at `/Applications/CrossOver.app`
- Futureport82 game files accessible on disk

## Quick Start

1. Download `FP82Fixer.zip` from the [latest release](https://github.com/nickmaccarthy/Futureport82-Video-Whitescreen-Fix-Mac-Crossover/releases/latest)
2. Unzip and move `FP82Fixer.app` to `/Applications`
3. Double-click to launch (use Right-click → Open only if Gatekeeper prompts)
4. Select or create a CrossOver bottle
5. Browse to your Futureport82 executable
6. Click **Apply Fix**

During the fix, CrossOver may show dialogs in the dock — click the CrossOver icon to dismiss them.

## Build from Source

Requires Swift 5.10+ (included with Xcode 15.3+).

```bash
# Debug build + run
make run

# Release build
make release

# Create .app bundle (ad-hoc signed)
make bundle

# Create distributable zip
make dist
```

## Signed and Notarized Release

To distribute `FP82Fixer.app` publicly on GitHub, use a Developer ID signed + notarized build.

### One-time Apple setup

1. Create a `Developer ID Application` certificate in Apple Developer.
2. Install it in your login keychain.
3. Verify it exists:

```bash
security find-identity -v -p codesigning
```

You should see an identity like:
`Developer ID Application: Your Name (TEAMID)`.

### Local signed release

Create an Apple ID app-specific password at [appleid.apple.com](https://appleid.apple.com), then run:

```bash
export SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export APPLE_ID="you@example.com"
export TEAM_ID="TEAMID"
export APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"

make release-signed
make verify-signature
```

Output artifact: `build/FP82Fixer.zip`.

### GitHub Actions signed release

This repository includes a release workflow at `.github/workflows/release.yml` that signs, notarizes, and uploads `FP82Fixer.zip` to GitHub Releases.

Set these repository secrets:

- `APPLE_CERTIFICATE_BASE64`: base64-encoded `.p12` export of your Developer ID Application cert
- `APPLE_CERTIFICATE_PASSWORD`: password used when exporting the `.p12`
- `SIGNING_IDENTITY`: full identity string from `security find-identity`
- `APPLE_ID`: your Apple ID email
- `APPLE_TEAM_ID`: your Apple Developer Team ID
- `APP_SPECIFIC_PASSWORD`: Apple ID app-specific password

Generate `APPLE_CERTIFICATE_BASE64` with:

```bash
base64 -i /path/to/certificate.p12 | pbcopy
```

After secrets are set, push Conventional Commits to `main` (for example `fix:` or `feat:`). The workflow will create a versioned release and attach `FP82Fixer.zip`.

## How It Works

The app wraps the proven `mf-fix-cx.sh` bash script with a native UI. The fix process:

1. **Copies Media Foundation DLLs** to the bottle's `system32` and `syswow64` directories
2. **Sets Wine DLL overrides** to prefer native versions for 9 MF-related DLLs
3. **Imports registry entries** (`mf.reg`, `wmf.reg`) via `regedit.exe`
4. **Registers DLLs** (`colorcnv.dll`, `msmpeg2adec.dll`, `msmpeg2vdec.dll`) via `regsvr32`
5. **Copies `mfplat.dll`** to the game directory
6. **Shuts down wineserver** to release locks before CrossOver opens the bottle

## Troubleshooting

- **"App cannot be verified"** — Right-click the app and choose `Open`, or go to System Settings → Privacy & Security → Open Anyway
- **CrossOver not found** — Ensure CrossOver is installed at `/Applications/CrossOver.app`
- **CrossOver hangs after fix** — The app shuts down the wineserver automatically; if it still hangs, quit CrossOver and reopen
- **White screen persists** — Check the output log for warnings about failed DLL copies

## Versioning

This project uses [semantic-release](https://github.com/semantic-release/semantic-release) with [Conventional Commits](https://www.conventionalcommits.org/) for automated versioning and releases.

When commits are pushed to `main`, semantic-release analyzes commit messages to determine the next version:

| Prefix | Example | Bump |
|---|---|---|
| `fix:` | `fix: handle missing bottle path` | Patch (1.0.x) |
| `feat:` | `feat: add drag-and-drop bottle import` | Minor (1.x.0) |
| `feat!:` or `BREAKING CHANGE:` | `feat!: require macOS 15` | Major (x.0.0) |
| `chore:`, `docs:`, `refactor:` | `chore: update dependencies` | No release |

## License

[Add your license here]

## Acknowledgments

- [HoodedDeath's MF Fix](https://github.com/HoodedDeath/mf-fix) — the original Media Foundation fix scripts
- [CodeWeavers CrossOver](https://www.codeweavers.com/crossover) — Wine-based Windows compatibility layer for macOS
