# Milestones

## M0 — Technical foundation (current)

- [x] Establish repository and default branch.
- [x] Add Godot project and boot scene.
- [x] Add source-control hygiene and project documentation.
- [x] Add automated project validation workflow.
- [x] Add Android debug-build workflow.
- [ ] Verify a successful CI run and downloadable APK.
- [ ] Install and launch APK on Redmi 14C; record results.

**Exit gate:** no critical project import/parse errors, successful APK export, and a recorded on-device launch result. Do not claim device verification before it happens.

## M1 — Playable combat prototype

- Move a placeholder hero in a compact 3D arena.
- Add one enemy with a simple approach/attack loop.
- Add Arcane Bolt, health/damage, and defeat feedback.
- Add Blink Step and basic touch controls.
- Add restart and a minimal HUD.
- Test responsiveness and performance on the target phone.

## M2 — Combat feel and presentation

- Improve animation, impact feedback, spell VFX, audio, enemy telegraphing, and camera framing.
- Tune controls and performance using real device measurements.

## M3 — Game structure and story

- Add encounter progression, checkpoints, a small narrative sequence, and a second enemy variation.
- Add save data only after progression rules are stable.

## M4 — Release readiness

- Accessibility/readability pass, device QA, crash fixes, performance review, release signing, privacy review, store assets, and release documentation.

Milestones are gates, not promises of completion dates. Do not start later-stage scope while a blocker remains in an earlier gate.
