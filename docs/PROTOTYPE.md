# Prototype — what exists, and what is still a claim

**Toolchain:** Xcode 27.0 · Swift 6.4 · iOS 27 SDK · deployment target iOS 26.0
**Zero third-party dependencies. No backend. No audio assets — every sound is
synthesised at runtime.**

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

### The cast
Four original characters — **Moppet** (steady), **Pip** (excitable), **Bramble**
(deadpan), **Thistle** (trouble). One rig builds all of them from a
`CharacterDescriptor`; nothing is per-character except numbers. Choice persists across
launches. See [CHARACTERS.md](CHARACTERS.md).

Personality is part of the character: breath period, blink interval and sway feed the
idle layer, so Pip breathes at 2.1s and Bramble at 5.6s. Bramble's `lidRest` means its
eyes never fully open. **The timing does more than the shapes do.**

### The puppet
- ~25 nodes with real pivots: separate jaw, independently tracking eyes with lids,
  brows, two arms, a crest that lags behind head movement, a shadow that shrinks as the
  puppet leaves the ground.
- **Idle life, always on** — breathing, irregular blinking with occasional doubles,
  weight shift and gaze wander, on non-harmonic periods so it never visibly loops.
- **7 expressions** — Neutral, Happy, Whoa, Silly, Sad, Grumpy, Sleepy.
- **12 actions** — Wave, Laugh, Jump, Spin, Yes, No, Topple, Dance, Cheer, Sneeze,
  Peek, Yawn. Hand-tuned keyframe curves with overshoot and effect cues.
- **4 effects** — dust, sparkle, confetti (one emitter per colour), music notes.
- **Layered, not switched.** A character can be happy, mid-wave, talking and breathing
  in the same frame.

### Stage and control
- 4 backdrops (Sunset, Meadow, Midnight with a star field, Showtime), independent of
  the character. Choice persists.
- Expression pad, action grid, drag-on-stage aiming, and a separate aim pad for modes
  where the performer cannot reach the stage.
- Controls emit `PuppetIntent` values and never touch puppet state. Haptics on actions.
- The control panel's middle section scrolls, so nothing is clipped on a half-height
  surface.

### Feel
- **Sound**, synthesised by `Synth`/`SoundBank` at the requested pitch, so each
  character has its own voice out of one bank (Pip 1.42×, Bramble 0.66×). Eleven
  sounds; no files to license or ship.
- **Screen shake** on landings, scaled by how hard the landing was.
- **Haptics on the animation beat** — you feel a landing when it lands, not when you
  pressed the button.
- **Poke the puppet.** A quick tap on the stage startles it: flinch, squeak, and it
  looks straight at your finger. Nothing advertises this.
- **Boredom.** Left alone it yawns after 14s, hides and peeks 11s later, then dances
  for itself. Resets the instant you touch anything. This is the app's whole engagement
  design and it is deliberately the only one — see [FEEL.md](FEEL.md).

### Voice
- Press-and-hold Talk. Microphone amplitude (RMS → dB → asymmetric smoothing) drives
  the jaw. No speech recognition, nothing written to disk, nothing leaves the device.
- **Silly Voice** fallback when there is no usable microphone: procedural babble with
  randomised syllables. Not an error state — the label and icon simply change.

### Multi-surface — the Duo groundwork
- `PuppetEngine` pushes each frame to *every* attached renderer, so surfaces are
  frame-accurately in step by construction.
- **Duo Rehearsal** renders the stage and the controls as two independent surfaces with
  a seam, running the same `StageView` and `ControlsView` a real two-screen device
  would use. **This works today and is the honest answer to "Duo support".**
- **Big Screen** is wired for real through the `externalDisplayNonInteractive` scene
  role; the phone keeps the controls and a confidence monitor.
- **Duo itself** is one protocol (`DuoCapability`) with one honest implementation that
  reports unavailable and says why. No guessed API, anywhere.

---

## Bugs found and fixed

Each of these was a real defect in shipped-looking code, found by testing rather than
by reading:

1. **Idle breathing was silently dead.** The expression layer overrode the *union* of
   every expression's channels, so "Whoa" declaring `bodyOffsetY` meant all seven
   expressions pinned it to zero. Caught by a unit test. Expressions now *displace*
   posture instead of taking it over.
2. **Pressing Talk crashed the app.** Reading `AVAudioEngine.inputNode` aborts the
   process from inside AudioToolbox when there is no real input — SIGABRT, not a
   catchable Swift error, so the `do`/`catch` around it was useless. Input availability
   is now checked before the engine is touched.
3. **Releasing Talk during the permission prompt left the puppet talking forever.**
   `beginTalking()` suspends on the prompt; a release during that suspension hit an
   early-return guard and was lost. Intent is now tracked separately from state.
4. **Sparkle and confetti erupted from the puppet's feet.** `fire()` overwrote the
   per-effect spawn point set in `makeEmitter`, and the rig root is always the origin.
5. **Confetti was monochrome.** `particleColorSequence` varies a colour over one
   particle's *lifetime*; it cannot colour particles differently from each other. Now
   one emitter per colour.
6. **An open mouth had a bar through it.** The lower lip was a full-width rectangle
   sitting where the mouth ellipse had tapered to nothing. Removed — the interior's own
   stroke reads as a lip at every jaw angle.
7. **Plugging in a display discarded a mode the user had just chosen.** The router now
   only auto-switches when the user has not made an explicit choice.
8. **Character choice did not survive relaunch.** The cast picker sent the intent
   straight to the engine, bypassing the layer that persists it.

---

## Verified on the simulator

- Launch → living puppet, first-run coach card, dismissal
- All four characters rendering distinctly; switching and persisting across relaunch
- Expressions driving the rig; actions firing, settling, and layering
- Cheer end to end: arms, two bounces, shrinking shadow, sparkles, multicoloured confetti
- Mode sheet, with Big Screen and Duo correctly disabled *and explained*
- Duo Rehearsal: two surfaces, one engine
- Talk → Silly Voice fallback: label switch, live level meter, jaw opening and closing
- 31/31 unit tests, and the `Core/` purity check

## NOT verified — do not assume these work

| Thing | Why not | What it needs |
|---|---|---|
| **Microphone → jaw, end to end** | The Simulator has no usable audio input, and touching it aborts the process, so the mic path is gated off there entirely. Only the fallback has been exercised. | A real device. **The single most important thing to test next.** |
| **Big Screen / external display** | No display was available. The scene role and delegate are wired, but the code path has never run. | An AirPlay receiver or a cable. Still the open ⚠️ spike from ARCHITECTURE §6.3. |
| **Duo** | No hardware, no SDK. | Both. |
| **Haptics** | Simulator does not produce them. | A real device. |
| **Landscape, and Duo Rehearsal side by side** | Only portrait was exercised. | Five minutes on a device. |
| **CI** | The workflow has never run; the hosted runner image may not have Xcode 26+. | One push. Expect to fix it. |
| **Performance** | Never profiled. Four backdrops and five confetti emitters are new since the last look. | Instruments, on the oldest device we decide to support. |
| **VoiceOver** | Labels exist; VoiceOver has never actually been switched on. | An hour with the screen reader. |

---

## Known gaps

- **The art is placeholder and drawn in code.** It is deliberately a rig rather than a
  picture: every pivot, channel binding and action track is real, so commissioned art
  replaces shape nodes with sprites and nothing else changes. Do not ship this art.
- **Characters are Swift values, not bundled JSON.** They are `Codable` and a test
  asserts the round trip, so the move is a loading change — but it has not been made,
  and there is no pack manifest or loader.
- **No sound effects.** Haptics only.
- **No voice FX** (pitch shift / robot). Designed, not implemented.
- **No IAP, no settings screen, no localisation.**
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

---

## Update — duet, the new rig, and the device microphone

### Works, and seen working in the Simulator

- **Two puppets side by side.** One `PuppetEngine` each, one shared stage. The puppet
  you are driving stands downstage — slightly larger and brighter — and the other
  blinks and breathes on its own clock. Verified: both puppets on screen, independent
  idle, the choice surviving a relaunch, and the swap button in the header.
- **Tap either puppet to take it over.** A touch picks the puppet in that half of the
  stage and drives it from then on, even if the drag wanders across the middle.
- **The redrawn cast.** Baked gradients, a fibre texture, rim and bounce light, muzzle,
  cheeks that flush, lashes, a set eyeball with two catchlights. All generated at load;
  `apply(pose:)` is still a pure transform binding with no per-frame path or texture
  work — more strictly so than the version it replaced, which rebuilt the smile path
  every frame.
- **Tip jar**, with a local StoreKit configuration attached to the shared scheme.

### Fixed but NOT verified on hardware

- **The microphone crash.** Root-caused from code and documented in `docs/MIC-CRASH.md`,
  but the phone that crashed has not been tested again, and no device crash report was
  available to confirm the diagnosis. This is the single most important thing to retest.

### Still NOT verified

Unchanged from before, plus two new entries:

- Microphone end to end on a real device — including the new recovery paths (a phone
  call mid-sentence, headphones connected while talking, media services restarting).
  None of these can be triggered in the Simulator.
- **60fps with two puppets on a real device.** Two full rigs now draw at once and each
  is a baked sprite tree rather than a handful of shape nodes. This has not been
  profiled anywhere, and the graphics work came with an explicit note that the eye masks
  want profiling with both puppets visible.
- The tip jar against **real** App Store Connect products. Locally it runs against
  `Config/PuppetMaster.storekit`; the three product IDs do not exist in App Store
  Connect yet, so in production the sheet will currently show "not available".
- External display, haptics, landscape, CI, VoiceOver actually switched on.
