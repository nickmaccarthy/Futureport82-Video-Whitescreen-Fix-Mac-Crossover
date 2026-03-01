# FP82Fixer — Development Guide

## What This App Does

FP82Fixer is a native macOS SwiftUI app that fixes CrossOver bottles for Futureport82 video playback. It wraps the proven `mf-fix-cx.sh` bash script with a native UI for bottle management, executable selection, and real-time output streaming.

## Tech Stack

- **Language**: Swift 5.10+
- **UI**: SwiftUI (macOS 14+ / Sonoma)
- **Architecture**: MVVM with `@Observable` macro
- **Build**: Swift Package Manager (no Xcode project)
- **Dependencies**: Zero third-party — Foundation + AppKit + SwiftUI only

## Project Structure

```shell
FP82Fixer/                          # SPM executable target
├── FP82FixerApp.swift              # @main app entry point
├── FixResources/                   # Bundled fix resources (.copy() in Package.swift)
│   ├── mf-fix-cx.sh               # The proven bash fix script
│   ├── system32/                   # 64-bit Media Foundation DLLs
│   ├── syswow64/                   # 32-bit Media Foundation DLLs
│   ├── mf.reg                      # Media Foundation registry entries
│   ├── wmf.reg                     # Windows Media Foundation registry entries
│   └── mfplat.dll                  # Platform DLL copied to game directory
├── Models/
│   └── Bottle.swift                # Bottle data model (struct)
├── Services/
│   ├── ShellService.swift          # Process execution + Wine dialog dismissal
│   ├── CrossOverService.swift      # CrossOver detection, bottle CRUD, error types
│   ├── MediaFoundationService.swift # Calls mf-fix-cx.sh + wineserver cleanup
│   └── BottleApplicationService.swift # Adds game to bottle with shortcuts
├── ViewModels/
│   └── FP82FixerViewModel.swift    # All app state and logic (@Observable @MainActor)
└── Views/
    ├── Styles.swift                # Glassmorphism UI styles
    ├── ContentView.swift           # Main layout
    ├── BottleListView.swift        # Bottle list + create/remove controls
    ├── ExecutablePickerView.swift  # File picker + "add to bottle" toggle
    └── OutputLogView.swift         # Real-time scrolling log

Resources/
└── Info.plist                      # App bundle metadata

Package.swift                       # SPM manifest
Makefile                            # Build / release / version targets
.github/workflows/release.yml      # CI: build + GitHub Release on tag push
```

## Architecture

### Fix Strategy

The app delegates the actual fix to `mf-fix-cx.sh` — the same battle-tested bash script used by the original Python GUI. This avoids subtle translation bugs from reimplementing Wine registry commands, DLL copy logic, and dialog dismissal in Swift.

`MediaFoundationService.applyFix()` calls the script via `Foundation.Process`:
```
/bin/bash mf-fix-cx.sh -e <exe_path> <bottle_path>
```

### Single ViewModel

All UI state lives in `FP82FixerViewModel`. Views are thin — they read state and call methods.

### Stateless Services

Services are structs with static methods. No shared state.

### Resource Bundling

Fix resources (DLLs, .reg files, bash script) are bundled via SPM's `.copy("FixResources")` directive and accessed at runtime via `Bundle.module`.

## Build & Run

```bash
make build          # Debug build
make run            # Debug build + launch
make release        # Optimized release build
make bundle         # Create .app bundle (ad-hoc signed)
make dist           # Bundle → zip
make version        # Print current version
make bump-patch     # Bump patch version
make tag            # Git tag + push (triggers CI release)
```

## Coding Conventions

- Structs for data models, classes only for ViewModels
- `@Observable` + `@MainActor` on ViewModels
- SF Symbols for all icons
- Semantic colors (`.primary`, `.secondary`) — never hardcode
- `async/await` for all async work
- Non-critical errors: log and continue, don't crash
