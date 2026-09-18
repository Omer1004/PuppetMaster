# Prototype — what exists, and what is still a claim

**Built:** 2026-09-18 · Xcode 27.0 · Swift 6.4 · iOS 27 SDK · deployment target iOS 26.0
**Zero third-party dependencies. No backend.**

This is Phase 0 from [ROADMAP.md](../ROADMAP.md): a working app whose job is to answer
*is this fun?* — not to be shippable. Read the "not verified" section before trusting
anything here.

---

## Run it

```bash
open PuppetMaster.xcodeproj
```

Or from the command line:

```bash
xcodebuild -project PuppetMaster.xcodeproj -scheme PuppetMaster -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' test
```

---

## What works

### The puppet
- **Moppet** — a cut-out rig of ~25 nodes with real pivots: separate jaw, independent
  eyes with tracking pupils and lids, brows, two arms, a lagging hair tuft, and a
  shadow that shrinks as he leaves the ground.
- **Idle life, always on.** Breathing, irregular blinking (with occasional double
  blinks), weight shift and gaze wander, on non-harmonic periods so it never visibly
  loops.
- **4 expressions** — Neutral, Happy, Whoa, Silly.
- **7 actions** — Wave, Laugh, Jump, Spin, Yes, No, Topple. Hand-tuned keyframe curves
  with overshoot, effect cues (dust on landing), and a deliberately uninterruptible
  Topple.
- **Layered, not switched.** Moppet can be happy, mid-wave, talking and breathing in
  the same frame.

### Control
- Expression pad, action grid, drag-on-stage aiming, and a separate aim pad for modes
  where the performer cannot reach the stage.
- Controls emit `PuppetIntent` values and never touch puppet state.
- Haptics on every action.

### Voice
- Press-and-hold Talk. Microphone amplitude (RMS → dB → asymmetric smoothing) drives
  the jaw. No speech recognition, nothing written to disk, nothing leaves the device.
- **Silly Voice** fallback when there is no usable microphone: a procedural babble with
  randomised syllables. Not an error state — the label and icon simply change.

### Multi-surface — the Duo groundwork
- `PuppetEngine` pushes each frame to *every* attached renderer, so surfaces are
  frame-accurately in step by construction.
- **Duo Rehearsal** renders the stage and the controls as two independent surfaces with
  a seam, running the same `StageView` and `ControlsView` a real two-screen device
  would use. **This works today and is the honest answer to "Duo support".**
- **Big Screen** is wired for real: `Info.plist` declares the
  `externalDisplayNonInteractive` scene role and `ExternalDisplaySceneDelegate` puts a
  chrome-free stage on a connected display while the phone keeps the controls and a
  confidence monitor.
- **Duo itself** is a single protocol (`DuoCapability`) with one honest implementation
  that reports unavailable and says why. No guessed API, anywhere.

### Tests
23 tests, all passing, none needing a screen. They cover pose layering, every action
returning to rest, keyframe sampling, cue firing, smoothing being frame-rate
independent, renderer attach/detach, and display routing.

`scripts/check-core-purity.sh` fails the build if anything in `Core/` imports a UI or
platform framework — the rule the whole architecture rests on, enforced rather than
remembered.

---

## Verified on the simulator

- Launch → living puppet, first-run coach card, dismissal
- All 4 expressions driving the rig
- Action buttons firing and settling
- Mode sheet, with Big Screen and Duo correctly disabled *and explained*
- Duo Rehearsal: two surfaces, one engine
- Talk → Silly Voice fallback: label switch, live level meter, jaw opening and closing
- 23/23 unit tests

## NOT verified — do not assume these work

| Thing | Why not | What it needs |
|---|---|---|
| **Microphone → jaw, end to end** | The Simulator has no usable audio input. Touching `AVAudioEngine.inputNode` there **aborts the process** (SIGABRT inside AudioToolbox — not a catchable Swift error), so the mic path is now gated off on Simulator entirely. Only the fallback has been exercised. | A real device. This is the single most important thing to test next. |
| **Big Screen / external display** | No display was available. The scene role and delegate are wired, but the code path has never run. | An AirPlay receiver or a cable. This was the ⚠️ spike in ARCHITECTURE §6.3 — still open. |
| **Duo** | No hardware, no SDK. | Both. |
| **Haptics** | Simulator does not produce them. | A real device. |
| **Landscape, and Duo Rehearsal side-by-side** | Only portrait was exercised. | Five minutes on a device or a rotated simulator. |
| **CI** | The workflow has never run; the hosted runner image may not have Xcode 26+. | One push. Expect to fix it. |
| **Performance** | Never profiled. | Instruments, on the oldest device we decide to support. |

---

## Known gaps

- **The art is placeholder and drawn in code.** It is deliberately a rig rather than a
  picture: every pivot, channel binding and action track is real, so commissioned art
  replaces shape nodes with sprites and nothing else changes. Do not ship this art.
- **Actions live in `ActionLibrary.swift`, not in per-character JSON.** The types are
  already shaped for the move (`ActionTrack` is plain data); it has not been done.
- **One character.** `CharacterDescriptor`/`CharacterCatalog` from the architecture
  doc are not built yet — Moppet is hardcoded.
- **No sound effects.** Haptics only. The sound bank is unbuilt.
- **No voice FX** (pitch shift / robot). Designed, not implemented.
- **No IAP, no settings screen, no localisation, no persistence** beyond the coach-card
  flag.
- **VoiceOver labels exist but have not been tested with VoiceOver actually on.**
- **The SpriteKit-vs-SwiftUI bake-off did not happen.** ROADMAP Phase 0 called for
  building both renderers and choosing with evidence. SpriteKit was chosen on the
  reasoning in ARCHITECTURE §7 and it works, but the comparison is still owed — the
  `PuppetRenderer` protocol keeps that door open.

---

## Next three things

1. **Put it on a real device** and test the microphone. Everything about the product
   rests on the jaw following your voice, and that is exactly the part the Simulator
   cannot show.
2. **Put it in front of children.** Phase 0's actual exit gate is whether they laugh,
   not whether it compiles.
3. **Run the external-display spike** for real, and decide whether Big Screen is a
   must-have or an option.
