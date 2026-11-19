# DoorSound 🚪

A macOS menu bar app that plays sounds when a supported MacBook lid moves. Adjust the volume or enable launch at login from the menu. The lid sensor is an undocumented Apple HID device and may not be available on every MacBook.

## Build and run

Requirements: macOS 13 or later and Apple Command Line Tools (`xcode-select --install`). The Xcode application and third-party build tools are not required.

```sh
make build   # produces build/DoorSound.app
make run     # builds and opens the app
make clean   # removes build artifacts
```

The build uses an ad-hoc signature for local development. Distribution to other Macs requires your own Apple Developer signing and notarization setup.

## Installation and distribution

Open the DMG and drag DoorSound into Applications. The DMG layout is created using Finder and may require Automation permission for the terminal running the build.

The default build is signed ad hoc for local testing only. Public distribution requires a Developer ID Application certificate, a hardened-runtime signature (including the app’s entitlements), submission to Apple’s notary service, and stapling the resulting ticket to the distribution artifact. The scripts do not perform those steps.

## Audio credits

The opening and closing clips are separate excerpts of [“Squeaky door” by LeonMire](https://commons.wikimedia.org/wiki/File:Squeaky_door.ogg), published through PDSounds and dedicated to the public domain. The excerpts were trimmed and filtered, then converted to mono WAV at 44.1 kHz.

## Implementation

The app polls the lid sensor at 10 Hz, increasing to 30 Hz during movement. The direction selects a recorded clip, the angle selects a position within it, and angular velocity controls the intensity. Short, overlapping excerpts preserve the recorded pitch and smooth direction changes. The sound fades when the lid stops moving. An unsupported or inaccessible sensor is indicated in the menu.

## Project structure

- `Crack/App/` contains the application entry point and state.
- `Crack/MenuBar/` contains the menu bar interface.
- `Crack/Sensor/` contains lid angle hardware access.
- `Crack/Audio/` contains the recorded door audio engine.
- `Crack/Assets.xcassets/`, `Crack/Info.plist`, and `Crack/Crack.entitlements` contain application resources and configuration.
- `scripts/build.sh` builds the application bundle in `build/`.
