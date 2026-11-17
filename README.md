# DoorSound 🚪

A macOS menu bar app that synthesizes sounds when a supported MacBook lid moves. Choose one of seven sounds, adjust the volume, or enable launch at login from the menu. The lid sensor is an undocumented Apple HID device and may not be available on every MacBook.

## Build and run

Requirements: macOS 13 or later and Apple Command Line Tools (`xcode-select --install`). The Xcode application and third-party build tools are not required.

```sh
make build   # produces build/DoorSound.app
make run     # builds and opens the app
make clean   # removes build artifacts
```

The build uses an ad-hoc signature for local development. Distribution to other Macs requires your own Apple Developer signing and notarization setup.

## Implementation

The app polls the lid sensor at 10 Hz, increasing to 30 Hz after movement. It maps angular velocity to parameters of procedural AVAudioEngine synthesizers. An unsupported or inaccessible sensor is indicated in the menu.
