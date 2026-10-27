# Test Plan

## M0 automated checks

- Workflow can install the pinned engine.
- Headless editor import completes without parser errors.
- Project main scene exists and is importable.
- Android export produces a non-empty APK artifact.
- Workflow logs clearly identify failing setup/export steps.

## M0 manual device smoke test

On the Redmi 14C:
1. Download the APK artifact from the completed GitHub Actions run.
2. Allow installation from the chosen source if Android requests it.
3. Install and launch the app.
4. Confirm the arena, floor, placeholder hero, and title are visible.
5. Rotate/resize if applicable and confirm the app does not immediately crash.
6. Record Android version, install/launch result, visible issues, and approximate FPS only if measured with a reliable method.

## Later gameplay tests

- Movement respects arena bounds.
- Projectiles hit the intended target once.
- Health never falls below zero.
- Dash cooldown prevents unintended repeated activation.
- Enemy defeat and player defeat produce deterministic states.
- Pause/restart does not leave duplicate enemies or projectiles.
- UI buttons are reachable and usable on the target screen.

## Reporting rule

Separate automated CI results from manual device results. A workflow artifact existing is not evidence that the APK installs or performs well on a real phone.
