# Ashen Covenant

A mobile-first, dark epic fantasy action RPG prototype built with **Godot 4.7.2** and GDScript.

> **Status:** Milestone 0 — technical foundation. This is an early project scaffold, not yet a playable game.

## Project goals

- Android-first, offline-first single-player game.
- Angled top-down 3D combat with stylised dark-fantasy art.
- Responsive touch controls designed for mid-range Android devices.
- Cloud builds through GitHub Actions; test APKs distributed as workflow artifacts.
- Compatibility renderer (OpenGL-based) as the initial mobile baseline.

## Current scope

Milestone 0 establishes a bootable Godot project, source structure, documentation, validation workflow, and an Android debug-build workflow. Gameplay systems will be added in later milestones.

## Requirements

- Godot **4.7.2 stable** (standard build; not .NET).
- Git for version control.
- Android test device for APK installation and smoke testing.
- Android export dependencies are installed by the CI workflow where supported.

## Open locally

1. Download Godot 4.7.2 stable from the [official archive](https://godotengine.org/download/archive/).
2. Import this repository folder in Godot.
3. Run the project (F6/F5 or the Run Project button).

## Cloud builds

Open **Actions** in GitHub and run **Android Debug Build**, or push a change to main. The workflow is intended to validate the project and upload a debug APK as a downloadable artifact. Check the workflow logs for the actual result; a green workflow is required before considering a build verified.

## Documentation

- [Game design](docs/GAME_DESIGN.md)
- [Technical architecture](docs/TECHNICAL_ARCHITECTURE.md)
- [Milestones](docs/MILESTONES.md)
- [Test plan](docs/TEST_PLAN.md)

## Safety and repository hygiene

Never commit API keys, passwords, signing keys, or other secrets. Local editor caches and generated exports should stay out of Git. The initial Android package identifier is a development placeholder and must be reviewed before release.

## License

The project source is currently marked as **All rights reserved** pending a deliberate license decision. Do not assume this repository grants permission to redistribute the game or its assets.
