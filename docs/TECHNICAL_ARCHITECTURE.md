# Technical Architecture

## Baseline

- Engine: Godot 4.7.2 stable, standard build.
- Language: GDScript.
- Renderer: Compatibility (OpenGL-based) for a conservative mobile baseline.
- Target: Android arm64 debug APK first.
- Repository: GitHub; CI: GitHub Actions.

## Architecture principles

- Prefer small, testable scenes and components.
- Keep gameplay values in data resources where appropriate.
- Keep UI separate from combat logic.
- Use signals for cross-system events rather than tightly coupled node paths.
- Add persistence only when a meaningful checkpoint/progression loop exists.
- Profile on the target phone before increasing effects, geometry, or shadow cost.

## Planned systems

- Player controller and touch input.
- Health component and damage interface.
- Ability controller and projectile scenes.
- Enemy controller and simple state machine.
- Encounter/game manager.
- HUD and pause/restart.
- Save manager in a later milestone.

## Milestone 0 scene

The current boot arena is intentionally a diagnostic scene: a floor, placeholder sphere, light, camera, and visible label. It validates project structure and startup, not gameplay quality or device performance.

## Build pipeline

The Android workflow should:
1. Check out source.
2. Install the pinned Godot version and export templates.
3. Install/configure Java and Android SDK components.
4. Run a headless editor import/parse check.
5. Export a debug APK using the Android preset.
6. Upload the APK as a workflow artifact.

CI success proves only that the workflow completed. A human still needs to install and launch the APK on the target device.
