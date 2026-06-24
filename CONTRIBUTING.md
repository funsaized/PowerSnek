# Contributing to PowerSnek

Thanks for helping make PowerSnek better. Small fixes, docs improvements, and
new feature ideas are welcome.

## Before You Start

- For small fixes, documentation updates, and obvious bugs, opening a pull
  request directly is fine.
- For larger behavior changes or new settings, open an issue first so the
  approach can be discussed before implementation.
- If you want a feature and can build it, send a contribution. Keep changes
  focused and easy to review.

## Development Setup

PowerSnek is a native macOS SwiftUI menu-bar app. The Xcode project is generated
from `project.yml`.

```bash
brew install xcodegen
xcodegen generate
open PowerSnek.xcodeproj
```

For CI-style local verification:

```bash
xcodebuild build -project PowerSnek.xcodeproj -scheme PowerSnek \
  -configuration Debug -derivedDataPath build CODE_SIGNING_ALLOWED=NO

xcodebuild test -project PowerSnek.xcodeproj -scheme PowerSnek \
  -destination 'platform=macOS' -derivedDataPath build CODE_SIGNING_ALLOWED=NO
```

The website lives in `site/`:

```bash
cd site
npm install
npm run check
npm run build
```

`npm run build` may need network access because the site uses `next/font` with
Google Fonts.

## Project Conventions

- Keep deterministic logic in `Sources/PowerSnekKit` when possible.
- Keep UI, AppKit, IOKit, and animation integration in `Sources/PowerSnek`.
- Add or update XCTest coverage in `Tests/PowerSnekKitTests` for framework logic.
- Regenerate `PowerSnek.xcodeproj` with `xcodegen generate`; do not hand-edit it.
- Follow the existing Swift style: 4-space indentation, small focused types, and
  descriptive filenames matching their primary type.
- Use `test_behavior_condition` naming for new XCTest methods.

## Pull Requests

Please include:

- The purpose of the change.
- Key implementation notes and tradeoffs.
- Test results, including commands run.
- Screenshots or screen recordings for visible UI or animation changes.

Before submitting, make sure you have not committed certificates, notarization
keys, exported keychains, `dist/`, or build artifacts.

## License

By contributing to PowerSnek, you agree that your contribution will be licensed
under the Apache License 2.0.
