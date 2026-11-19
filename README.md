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

The opening and closing clips are two excerpts of [“Squeaky door hinge” by MKFI](https://commons.wikimedia.org/wiki/File:Squeaky_door_hinge.ogg), released under [CC0](https://creativecommons.org/publicdomain/zero/1.0/). The excerpts were trimmed, filtered, and faded, then converted to mono WAV at 44.1 kHz.

## Implementation

The app polls the lid at 10 Hz when idle and 30 Hz during movement. Each movement starts a recorded creak for its direction. Angular velocity adjusts playback rate and volume. The recording plays once and fades when the lid stops or changes direction. An unsupported or inaccessible sensor is indicated in the menu.

## Project structure

- `Crack/App/` contains the application entry point and state.
- `Crack/MenuBar/` contains the menu bar interface.
- `Crack/Sensor/` contains lid angle hardware access.
- `Crack/Audio/` contains the recorded door audio engine.
- `Crack/Assets.xcassets/`, `Crack/Info.plist`, and `Crack/Crack.entitlements` contain application resources and configuration.
- `scripts/build.sh` builds the application bundle in `build/`.
