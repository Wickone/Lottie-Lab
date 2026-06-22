# Development setup

## Requirements

- Xcode 16.4 or newer
- iOS 17.5 deployment target
- A matching iOS Simulator runtime installed in Xcode

## First run

1. Open `LottieLab.xcodeproj`.
2. Wait for Swift Package Manager to resolve Lottie.
3. Select an installed iOS simulator.
4. Run the shared `LottieLab` scheme.

## Command-line verification

```bash
xcodebuild test \
  -project LottieLab.xcodeproj \
  -scheme LottieLab \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO
```

If Xcode reports a CoreSimulator version mismatch, finish Xcode's first-launch
setup and restart macOS. The installed Xcode, platform components, and
CoreSimulator service must come from the same Xcode release.

## Source layout

`ContentView`, `BundledAnimationsView`, `EditPropertiesSheet`, and
`MainExportView` form the active application flow. `AnimationPlayerView` and
`AnimationEditorView` are retained as legacy reference code and are excluded
from the application target.
