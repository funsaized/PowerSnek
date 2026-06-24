# Repository Guidelines

## Project Structure & Module Organization

PowerSnek is a native macOS SwiftUI menu-bar app. App/UI and system integration code lives in `Sources/PowerSnek`, with settings under `Settings/`, overlay animation under `Overlay/`, and app resources in `Resources/`. Testable framework logic lives in `Sources/PowerSnekKit`; keep pure geometry, color, power-state, and settings behavior there when possible. XCTest coverage lives in `Tests/PowerSnekKitTests`. Release automation is under `scripts/release`, CI workflows are in `.github/workflows`, and design/planning notes are in `docs/superpowers`.

`project.yml` is the XcodeGen source of truth. Regenerate `PowerSnek.xcodeproj` instead of hand-editing project files.

## Build, Test, and Development Commands

- `brew install xcodegen`: install the project generator.
- `xcodegen generate`: regenerate `PowerSnek.xcodeproj` from `project.yml`.
- `open PowerSnek.xcodeproj`: open the app in Xcode for local running/debugging.
- `xcodebuild build -project PowerSnek.xcodeproj -scheme PowerSnek -configuration Debug -derivedDataPath build CODE_SIGNING_ALLOWED=NO`: CI-style unsigned debug build.
- `xcodebuild test -project PowerSnek.xcodeproj -scheme PowerSnek -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`: run the `PowerSnekKitTests` suite.
- `scripts/release/build-and-sign.sh`: produce `dist/PowerSnek.app` for release packaging.

## Coding Style & Naming Conventions

Use Swift 6 and the existing style: 4-space indentation, concise `final class`/`struct` declarations, explicit access control for framework APIs, and small focused types. Use `UpperCamelCase` for types, `lowerCamelCase` for properties and methods, and descriptive filenames matching their primary type. Tests currently use `test_behavior_condition` names; follow that pattern for new XCTest methods.

## Testing Guidelines

Add or update XCTest coverage in `Tests/PowerSnekKitTests` for changes to `PowerSnekKit`. Prefer moving deterministic logic into `PowerSnekKit` so it can be tested without UI, power-source, or display dependencies. Run the CI-style `xcodebuild test` command before opening a PR.

## Commit & Pull Request Guidelines

Recent history uses short Conventional Commit-style subjects such as `fix(release): code-sign the DMG so Gatekeeper accepts it`, `docs: add project README`, and `fmt`. Keep subjects imperative and scoped when useful. PRs should include the purpose, key implementation notes, test results, and screenshots or screen recordings for visible UI/animation changes.

## Security & Configuration Tips

Do not commit Developer ID certificates, notarization keys, exported keychains, `dist/`, or build artifacts. Release signing and notarization are secret-gated in GitHub Actions; see `scripts/release/README.md` for required secret names and local release notes.
