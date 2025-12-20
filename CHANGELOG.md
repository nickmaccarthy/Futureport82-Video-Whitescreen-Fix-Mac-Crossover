# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.5] - 2025-12-20

### Fixed
- Fixed error dialog when app runs from App Translocation (read-only location)
- Silently handle read-only file system when making script executable
- Bash can execute scripts even without executable bit, so no error needed

### Changed
- Updated README with instructions to move app to Applications folder

## [1.0.4] - 2025-12-20

### Added
- Version tracking with CHANGELOG.md and VERSION.md
- Version display in window title, UI, and status bar
- Version information visible to users when running the app

## [1.0.3] - 2025-12-20

### Fixed
- Fixed crash when clicking "Apply Media Foundation Fix" button
- Added comprehensive exception handling to prevent PyQt from aborting on unhandled exceptions
- Display error messages in dialog boxes instead of crashing the app

## [1.0.2] - 2025-12-20

### Fixed
- Fixed app crash when applying fix - improved resource path handling in bundled app
- Added verification for required resources before running script
- Improved error handling with traceback logging
- Set working directory correctly for script execution

## [1.0.1] - 2025-12-20

### Added
- Ad-hoc code signing to build process
- User instructions for bypassing macOS security warning
- Signing step in GitHub Actions workflow

### Changed
- Updated documentation with security warning instructions
- Improved troubleshooting section

## [1.0.0] - 2025-12-20

### Added
- Initial release
- GUI application for fixing CrossOver bottles
- Media Foundation fixes for Futureport82 video playback
- Bottle management (list, create, remove)
- One-click fix application
- Real-time output display
- Command-line interface option

[1.0.5]: https://github.com/nickmaccarthy/Futureport82-Video-Whitescreen-Fix-Mac-Crossover/releases/tag/v1.0.5
[1.0.4]: https://github.com/nickmaccarthy/Futureport82-Video-Whitescreen-Fix-Mac-Crossover/releases/tag/v1.0.4
[1.0.3]: https://github.com/nickmaccarthy/Futureport82-Video-Whitescreen-Fix-Mac-Crossover/releases/tag/v1.0.3
[1.0.2]: https://github.com/nickmaccarthy/Futureport82-Video-Whitescreen-Fix-Mac-Crossover/releases/tag/v1.0.2
[1.0.1]: https://github.com/nickmaccarthy/Futureport82-Video-Whitescreen-Fix-Mac-Crossover/releases/tag/v1.0.1
[1.0.0]: https://github.com/nickmaccarthy/Futureport82-Video-Whitescreen-Fix-Mac-Crossover/releases/tag/v1.0.0

