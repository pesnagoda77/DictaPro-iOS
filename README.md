# DictaPro iOS

iOS platform configuration for DictaPro — voice recorder with AI transcription.

## Contents

- `Podfile` — CocoaPods configuration (iOS 13.0+)
- `Runner/Info.plist` — App permissions (microphone, photo library)
- `Runner/AppDelegate.swift` — Native Swift code with `dictapro/convert` MethodChannel (MP3→WAV via AVAssetReader)
- `Runner/Base.lproj/LaunchScreen.storyboard` — Dark-themed launch screen
- `Runner.xcodeproj/` — Xcode project
- `Runner.xcworkspace/` — Xcode workspace

## Requirements

- iOS 13.0+, Xcode 14+, CocoaPods

## Setup (on Mac)

```bash
cd ios
pod install
```

Then open `Runner.xcworkspace` in Xcode.

## Note

This is a partial Flutter project. Merge this `ios/` folder into the main DictaPro Flutter project to build.
